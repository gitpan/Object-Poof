package Object::POOF::DB;

use version; $VERSION = qv('0.0.6');

use warnings;
use strict;
use Carp;
use DBI;
use Readonly;
use Time::HiRes qw( usleep );
use English '-no_match_vars';
use YAML;
use Want;

use Object::POOF::X;
use Object::POOF::Constants;
use Config::Std;

use Class::Std;

# setting up exception classes has to be called from outside
# the internal scope for some bizarre reason.

# Module implementation here
{
    # some constants:

    # how many times to try connecting to database:
    Readonly my $MAX_CONNECT_TRIES => 3;

    # how many times to try reading the config file into package var:
    Readonly my $MAX_READ_CONFIG_TRIES => 3;

    # see DBI manpage under "prepare_cached".
    # want to use the default option '0', i think, because as sth's
    # are pushed to the array, if they are replaced with '3', 
    # then the old ones will still be referenced and it could get leaky.
    Readonly my $PREPARE_CACHED_IFACTIVE_OPT => 0; 

    Readonly my %pooftypes => (
        varchar     => 'str',   char        => 'str',   text       => 'str',
        tinytext    => 'str',   mediumtext  => 'str',   longtext   => 'str',
        enum        => 'str',   set         => 'str', 

        float       => 'num',   double      => 'num',   decimal    => 'num',
        tinyint     => 'num',   smallint    => 'num',   mediumint  => 'num',
        'int'       => 'num',   bigint      => 'num', 

        datetime    => 'dt',    timestamp    => 'dt',   date       => 'dt',
        'time'      => 'dt',    year         => 'dt',

        binary      => 'bin',   varbinary   => 'bin',   tinyblob   => 'bin',
        blob        => 'bin',   mediumblob  => 'bin',   bigblob    => 'bin',
    );

    # some package vars that will be set by various methods:
    my $config          = undef;
    my $config_filename = undef;
    my %table_info      = ( );
    my %table_names     = ( );

    # start setup processing

    my (
        %dbh_of,    %sths_of
    ) :ATTRS;

    sub DEMOLISH {
        my $self = shift;
        my $ident = ident($self);

        # if dbh isn't even here, we're already done:
        return 1 if !defined $dbh_of{$ident};

        # finish up any sth's before they get collected, else process dies
        $self->finish_all();

        # roll back any outstanding transactions
        $self->rollback();

        # unlock any table locks (as if this were implemented!)
        #$self->unlock;

        # now disconnect nicely from the database:
        #$self->_disconnect 
            #or carp q{DEMOLISH could not disconnect: '}.DBI::errstr.q{'};
        
        # might not really want to disconnect under mod_perl
    }

    sub exists_table {
        my ($self, $table_name) = @_;

        # be fascist about context:
        if (!want('BOOL')) {
            Object::POOF::X::DB->throw(
                message => __PACKAGE__
                    .   qq{: exists_table() not called in BOOL context.},
            );
        }

        # if no tables have been looked up, do so:
        if (! scalar keys %table_names) {
            $self->_fetch_table_names();
        }

        # return an answer:
        return (exists $table_names{ $table_name })
            ? scalar 1 
            : scalar 0;
    }

    sub AUTOMETHOD {
        # look up table names and get (possibly cached) info.

        # don't want to return an exception if table doesn't exist.
        # instead, returns false -- so you can use it as a truth test
        # to see if table exists.
 
        # it is possible that this could be called twice at the same
        # time for the same table under the same interpreter, and it 
        # would do the table lookup twice, but no big deal -- it's better
        # than doing this for every potential transaction thread.  
        # of course, a given interpreter will *probably* only have 
        # one transaction thread, right? ...
 
        my ($self,$ident,@args) = @_;
        my $table = $_;
 
        # this should never be called as a class method, only obj method:
        # this fixes something icky with overload (maybe just w/ Test::Builder)
        return if (!ref $self);  
 
        # if not actively connected, decline the call:
        if (! $self->dbh() ) {
            carp ref $self, qq{ not connected to get info on table '$table'.};
            return;     # or should it throw an exception?
        }

        # if table does not exist, return false:
        if (! $self->exists_table( $table )) {
            return sub { return; }
        }

        # if info not cached in package var, try to look it up:
        if (! exists $table_info{$table} ) {
            $self->_lookup_table_info($table);
        }

        # now return the table info:
        return sub {
            return $table_info{$table};
        }
 
    }

    sub _lookup_table_info : PRIVATE {
        my ($self,$table) = @_;

        $table_info{$table} = {};
        my $info = $table_info{$table};

        my $sth = $self->prepare(qq{DESCRIBE $table});
        $sth->execute();

        while (my $row = $sth->fetchrow_hashref) {
            my $fld = $row->{Field};

            # info has one key 'fields' that has an array of all fields
            push @{ $info->{fields} }, $fld;

            # the other key 'info' keyed on field name contains all this
            # row information plus some other stuff:
            
            $info->{info}->{$fld} = $row;

            my ($type, $lim, $unsigned, $zerofill) = $row->{Type} =~ m{
                \A
                    (\w+)           # type
                    \(?             # maybe a paren
                        (.*?)       # maybe a limit, disp/prec or enum vals
                    \)?             # maybe a closing paren
                    \s?             # maybe some whitespace
                    (unsigned)?     # maybe text 'unsigned', treated as bool
                    \s?             # maybe some whitespace
                    (zerofill)?     # maybe text 'zerofill', treated as bool
                                    # (zerofill fields are always unsigned)
                \z
            }xms;

            # save real data type as lowercase 'type', slice in other vals:
            @{ $info->{info}->{$fld} }
                {   'type', 'unsigned', 'zerofill'  }
                = ( $type,  $unsigned,  $zerofill   );

            # the "simple" datatype:
            my $pooftype
                = $info->{info}->{$fld}->{pooftype}
                = $pooftypes{$type};

            # CYA:
            if (!$pooftype) {
                warn __PACKAGE__
                    .   qq{->_lookup_table_info() - no valid pooftype.\n}
                    .   qq{New mysql type '$type'?  Please report a bug.\n};
            }
            
            # cut up $lim into whatever it might mean for this type:
            if  (   ( $type eq 'decimal' )
                and ( defined $lim ) 
                and ( $lim =~ m{ \A (\d+) , (\d+) \z }xms )
                ) {
                @{ $info->{info}->{$fld} }{'digits','decimals'} = ($1,$2);
            } 
            elsif    
                (   ( ($type eq 'float') or ($type eq 'double') ) 
                and ( defined $lim ) 
                and ( $lim =~ m{ \A (\d+) , (\d+) \z }xms )
                ) {
                @{ $info->{info}->{$fld} }{'width','decimals'} = ($1,$2);

            } 
            elsif 
                (   ( ($type eq 'enum') or ($type eq 'set') ) 
                and ( defined $lim ) 
                ) {
                $lim =~ s{'}{}g;
                #warn "lim after is '$lim'\n" if ($d);
                $info->{info}->{$fld}->{options} = [ split q{,}, $lim ];
            } 

            # and if $lim is just a number, it means it's the limit:
            if  (   ( defined $lim ) 
                and ( $lim =~ m{ \A \d+ \z }xms ) 
                ) {
                $info->{info}->{$fld}->{limit} = $lim;
            }
        }

        # best to explicitly finish:
        $sth->finish;
    }

    sub _fetch_table_names : PRIVATE {
        my ($self) = @_;

        map { $table_names{ $_->[0] } = 1; } 
            @{ $self->dbh->selectall_arrayref("show tables") };

        return;
    }

    sub dbh {
        # return the dbh handle
        my ($self) = @_;
        return if !ref $self; # cannot be called as class method.
        my $ident = ident($self);

        # if dbh isn't defined yet or not pinging...
        if ( !defined $dbh_of{$ident} || !$self->_ping() ) {
            eval {
                $self->_connect();
            };
            #warn "in dbh, trying to throw, eval error '$EVAL_ERROR'\n";
            #warn "which is type '", ref $EVAL_ERROR, "'\n";
            if (my $e = Exception::Class->caught('Object::POOF::X::DB')) {
                $e->rethrow();
            }
        }
        return $dbh_of{$ident};
    }

    sub do {
        # use this method to barf exceptions nicely.
        # if you're going to use \%attr or @bind_values params to DBI::do(),
        # use an Object::POOF::SQL object and put them in there.

        my ($self, $query) = @_;

        # if query is a ref, check the type
        if  (   (ref $query)
            && !(   (ref $query eq 'SCALAR') 
                ||  ($query->isa('Object::POOF::SQL'))
                )
            ) {
            Object::POOF::X::DB::Do->throw(
                message => q{'query' param to query() is ref of wrong type (} 
                    . ref $query . q{)},
            );
        }

        #carp "why am i not able to do query '$query'?";

        my $dbh = undef;
        eval { $dbh = $self->dbh };
        if (my $e = Exception::Class->caught('Object::POOF::X::DB')) {
            # barf it on up
            $e->rethrow();
        }
        
        my $rv = undef;
        eval {
            #warn "should be evalling something...";
            # if passed a scalar ref, derefence it:
            if  (   (ref $query)
                and (ref $query eq 'SCALAR') 
                ) {
                #warn "trying to dereference scalar ref query.";
                $rv = $dbh->do(${$query})
            }
            # if passed an Object::POOF::SQL object, 
            elsif
                (   (ref $query)
                and ($query->isa('Object::POOF::SQL') )
                ) {
                #warn "trying to stringify Object::POOF::SQL";
                $rv = $dbh->do( qq{$query} );  # stringify query:
                # "$query->sql(), $query->attrs(), @{ $query->bind_values() }"
            }
            else {
                #warn "doing scalar query '$query'";
                $rv = $dbh->do( $query );
            }
        };
        #if ($EVAL_ERROR) {
        if ($dbh->err()) {
            my $message = undef;
            if (ref $query eq 'SCALAR') {
                $message = $$query;
            }
            elsif (ref $query and $query->isa('Object::POOF::SQL')) {
                $message = qq{$query};
            }
            else {
                $message = $query;
            }

            Object::POOF::X::DB::Do->throw(
                errstr  => $dbh->errstr(),
                message => $message,
            );
        }

        return $rv; # return like you'd expect DBI::db->do() to
    }

    sub prepare_cached {
        # works the same way as DBI's "prepare_cached".
        my ($self, $statement, $attr_href) = @_;
        eval { 
            # extra arg to prepare() is a bool flag to use prepare_cached
            return $self->prepare( $statement, $attr_href, 1 ); 
        };
        if (my $e = Exception::Class->caught('Object::POOF::X::DB')) {
            $e->rethrow();
        }
    }

    sub prepare {
        # works the same way as DBI's "prepare", except it pushes the
        # sth to a stack that will be finished on unclean destruction.
        # last arg 'cache' is bool flag - use prepare_cached() instead.

        my ($self, $statement, $attr_href, $cache) = @_;

        if  (   (!$statement) 
            or  (   (ref $statement)
                and (   (ref $statement ne 'SCALAR')
                    or  (!$statement->isa('Object::POOF::SQL'))
                    )
                )
            ) {
            Object::POOF::X::DB::STH->throw(
                message => q{No valid sql statement supplied to prepare().},
            );
        }

        if ($attr_href and ref $attr_href ne 'HASH') {
            Object::POOF::X::DB::STH->throw(
                message => q{Supplied \%attr for prepare() not a hashref.},
            );
        }
        elsif (!$attr_href) {
            $attr_href = {};
        }

        # would be nice to find a syntax checker for the statement
        # and run it about here.

        my $dbh = undef;
        eval {
            $dbh = $self->dbh();
        };
        if (my $e = Exception::Class->caught('Object::POOF::X::DB')) {
            $e->rethrow();
        }

        my $sth = undef;
        my $dbifunc = ($cache) 
            ? sub {
                return $dbh->prepare_cached(
                    $statement,
                    $attr_href,
                    $PREPARE_CACHED_IFACTIVE_OPT,
                );
            }
            : sub {
                return $dbh->prepare_cached(
                    $statement,
                    $attr_href,
                );
            };

#       warn qq{
#           statement: '$statement',
#           attr_href: '$attr_href',
#           dbifunc:   '$dbifunc',
#           const:     '$PREPARE_CACHED_IFACTIVE_OPT',
#       };
        
        # prepare the statement and get the handle:
        eval { 
            $sth = $dbifunc->();
        };
        if ($EVAL_ERROR) {
            warn $EVAL_ERROR;
            Object::POOF::X::DB::STH->throw(
                message => qq{Could not get sth from DBI $dbifunc.},
                errstr  => $dbh->errstr(),
            );
        }

        # if a valid sth returned, put it in the cleanup stack:
        my $ident = ident($self);
        #warn "sth is a '$sth'\n";
        push @{ $sths_of{ ident($self) } }, $sth;

        # hmm, when used with prepare_cached, some of these sth
        # references pushed to the cleanup stack could be duplicates.
        # in fact, if it is used a lot, there could be many duplicates.
        # i wonder if it is worth caring, separating them, trying to
        # grep first, etc.  

        # and return it:
        return $sth;
    }

    sub finish_all {
        my ($self) = @_;
        my $ident = ident($self);

        map { $_->finish() } @{ $sths_of{$ident} };
        return;
    }

    sub rollback {
        my ($self) = @_;
        my $ident = ident($self);
        eval { $self->dbh->rollback };
        if ($EVAL_ERROR) {
            Object::POOF::X::DB->throw(
                message => q{Cannot do rollback.},
                errstr  => $self->dbh->errstr(),
            );
        }
        return;
    }

    sub commit {
        my ($self) = @_;
        my $ident = ident($self);
        eval { $self->dbh->commit };
        if ($EVAL_ERROR) {
            Object::POOF::X::DB->throw(
                message => q{Cannot do commit.},
                errstr  => $self->dbh->errstr(),
            );
        }
        return;
    }

    sub _ping : PRIVATE {
        my ($self) = @_;
        my $ident = ident($self);
        return if !defined $dbh_of{$ident};
        return $dbh_of{$ident}->ping();
    }

    # _connect()
    # try a few times to connect to the database.
    # returns the dbh handle if successful, 
    # otherwise throws Object::POOF::X::DB
    sub _connect : PRIVATE {
        my $self = shift;
        my $ident = ident($self);

        # if we can ping db, we're already connected:
        return $dbh_of{$ident} if ($self->_ping);

        CONNECT:
        for my $try (1..$MAX_CONNECT_TRIES) {

            # try to return immediately - _connect_attempt() returns dbh
            eval {
                $self->_connect_attempt();
                #carp "dbh_of{$ident} is a '", ref $dbh_of{$ident}, "'\n";
            };

            #warn "on connect try $try, eval error is type '", ref $EVAL_ERROR, "'";

            # throw up if error caught and it's the last try.
            if (my $e = Exception::Class->caught('Object::POOF::X::DB') ) {
                if ($try == $MAX_CONNECT_TRIES) {
                    #warn "rethrowing error of type '", ref $EVAL_ERROR, "'";
                    $e->rethrow();
                }
                else {
                    # else wait a blip before trying again...
                    #warn "calling _connect_attempt() again...";
                    usleep( 10 + int( rand(90) ) );
                    next CONNECT;
                }
            }
            elsif (exists $dbh_of{$ident}) {    # don't autoviv!
                return $dbh_of{$ident};
            }
            else {
                # probably can't happen, but just in case:
                Object::POOF::X::DB->throw(
                    message => q{no dbh but no connect exception thrown.},
                );
            }
        }
        croak __PACKAGE__.q{->_connect(): Impossible logic error.};
    }

    sub _connect_attempt : PRIVATE {
        my $self = shift;
        my $ident = ident($self);

        # oh, this is controlled just as well by the max num of connect tries
        # read in config package var if not already done:
        if (!defined $config) {

            eval { $self->_read_config(); };

            if (my $e = Exception::Class->caught('Object::POOF::X::DB') ) {
                # undef config again to make it know it didn't work:
                $config = undef;

                # and barf it on up:
                $e->rethrow();
            }
        }

        # try connecting, return if success
        eval { 
            $dbh_of{$ident} = DBI->connect(
                q{dbi:mysql:dbname=}
                    . $config->{database}->{dbname}
                    . q{;host=}
                    . $config->{database}->{host},
                $config->{database}->{username},
                $config->{database}->{password},
                {    
                    PrintError => 0,    # errors handled by exceptions
                    RaiseError => 1,    # but they should be "fatal" for evals
                    AutoCommit => 0,    # must explicitly commit in transacts
                }
            );
            return $dbh_of{$ident};
        };
        if ($EVAL_ERROR) {
            # obfuscate the database password before crapping out:
            $config->{database}->{password} =~ s/\p{IsPrint}/\*/xmsg;
            Object::POOF::X::DB->throw( 
                message     => q{_connect_attempt() failed},
                errstr      => DBI::errstr,
                config      => $config,
            );
        }
    }
    
    sub _read_config : PRIVATE {
        my ($self) = @_;
        my $class = ref $self;
        my $read_filename       = undef;
        my $pkg_config_filename = undef;

        my ($baseclass) = $class =~ m{ \A (\w+) :: .* \z }xms;

        {   # isolate clever unstrictness:
            no strict 'refs';
            $pkg_config_filename = ${"${baseclass}::DB::config_filename"};
        }

        # if filename defined in child package, use it:
        if (defined $pkg_config_filename) {
            $read_filename = $pkg_config_filename;
        }
        # else use default:
        else {
            $read_filename = qq{/etc/poof/$baseclass/config};
        }

        # try to read in config:
        eval { read_config $read_filename => %{$config}; };

        # if it bombed (like if the file was bad, not there, or bad perms),
        # Config::Std will tell us why:
        if ($EVAL_ERROR) {
            my $errstr = qq{$EVAL_ERROR};
            Object::POOF::X::DB->throw(
                message => qq{Config::Std exception for file '$read_filename'},
                errstr  => $errstr,
            );
        }
        else {
            return;
        }
    }


    # define exception objects used by this class:


}


1; # Magic true value required at end of module
__END__

=head1 NAME

Object::POOF::DB - Wrapper object around DBI.


=head1 VERSION

This document describes Object::POOF::DB version 0.0.6


=head1 SYNOPSIS

 package TestApp::DB;
 use Object::POOF::Constants;
 use base qw( Object::POOF::DB );
 use Class::Std;
 { 
    sub BUILD {
        my ($self, $ident, $arg_href) = @_;

        # set defaults if not set in constructor
        $self->get_dbname  or $self->set_dbval(name  => 'test');
        $self->get_dbhost  or $self->set_dbval(host  => 'localhost');
        $self->get_dbuname or $self->set_dbval(uname => $EMPTY_STR);
        $self->get_dbpass  or $self->set_dbval(pass  => $EMPTY_STR);
        return;
    }
 }

 package main;
 use English '-no-match-vars';
 use Carp;

 my $db = TestApp::DB->new();
 # or...
 # my $db 
 #     = TestApp::DB->new({ uname => 'mydbuser', pass => 'mydbpass' });

 my $dbh = undef;
 eval { $dbh = $db->dbh() };

 croak $EVAL_ERROR if ($EVAL_ERROR);  

 # it will stringify properly, or...
 # if (my $e = Exception::Class->caught('Object::POOF::X::DB') ) {
 #     $e->rethrow();
 # }

 # now use DBI methods on $dbh...
 eval { $db->commit() };
 # $EVAL_ERROR would be an Object::POOF::X::DB::Do exception
 
 # Mainly you use this to pass a transaction thread 
 # to Object::POOF objects:
 my $thing = TestApp::Thing->new({ db => $db });
 $thing->set_save({
    field1 => 'val1',
    field2 => 'val2',
 });

 eval { $thing->save() };  # Object::POOF::X::Update exception?
 if (my $e = Exception::Class->caught('Object::POOF::X::Save')) {
    $thing->rollback();
    carp $e;
 }
 else {
    eval { $thing->commit() };  # Object::POOF::X::DB::Do exception?
    # ....
 }

 
=head1 DESCRIPTION

This is the Object::POOF suite wrapper around DBI.  
Its main use is to create a connection object to a MySQL InnoDB
database that wraps the transaction thread in an object and
provides some nice exception classes.

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

Object::POOF::DB is used as a base parent class for your
DB object in your application's namespace, which you create
with a very simple construct as detailed above.  Then your
DB object gets a bunch of methods.

=head2 $db = TestApp::DB->new() - the only class method

Pass a hash reference of values if you want to override any of
the attributes listed in BUILD() above.  This is useful if you
are running test scripts on another database.  However, maybe
there ought to be a config file with this info... hmm.  I will
figure this out better as time goes on.

=head2 $rv = $db->do($sql_query);

Should work just like DBI::dbh::do(), except that it returns
Exception::Class exceptions with class names of 'Object::POOF::X::DB::Do',
or 'Object::POOF::X::DB'.

=head2 $sth = $db->prepare($query, \%attrs); # or prepare_cached

Intended to work just about the same way as the DBI versions,
but prepare_cached will always use 

=head2 $db->finish({ sth_name => 'name' });

Finishes a named cached sth.  Of course, if you still have a 
reference to it, you could call finish directly.  This is
used by DEMOLISH upon destruction to finish all sth's if
being destroyed uncleanly.

=head2 $db->commit;  $db->rollback;

Wrappers around dbh->commit and dbh->rollback that throw
Object::POOF::X::DB exceptions.

=head2 AUTOMETHOD: my $table_info = $db->table_name();

Returns a hash of information about a particular table,
or false if the table does not exist under this database.
This hash has two keys.  $table_info->{fields} is an array
ref containing the names of the fields in the order that a
'describe table_name' would return them.  $table_info->{info} 
is a hash indexed by field name containing information about 
the fields from the 'describe' and parsing of that information.
Mostly this is used internally, but it might be useful to you.
This information is cached in a package variable, so even if
your interpreter is running multiple transaction handles, 
it will cache the describe table results across all of them.

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

to do...

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Object::POOF::DB requires no configuration files or environment variables
at this point, but maybe I will move the database connect info into
a global Object::POOF config file at some point.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

Object::POOF and all its dependencies, Class::Std, DBI.

=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-object-poof-db@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Mark Hedges  C<< <hedges@ucsd.edu> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, Mark Hedges C<< <hedges@ucsd.edu> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
