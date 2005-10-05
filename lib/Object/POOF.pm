package Object::POOF;

use version; $VERSION = qv('0.0.6');

use warnings;
use strict;
use Carp qw( carp cluck confess croak );
use English '-no_match_vars';
use Switch 'Perl6';
use Data::Types qw( :is );
use Readonly;
use YAML;
use Want;
use Exception::Class;

use Object::POOF::X;            # import exception subclasses
use Object::POOF::Constants;    # Readonly constants
use Object::POOF::Tools qw( :data );

# Module implementation here

use Class::Std;
{ 
    my $table_of_field = { };

    # i think i may want to restrict access to %data_of somehow.
    my (
        %data_of,
        %tables_fetched_in,
        %last_select_ts_for,
        %last_insert_ts_for,
    ) :ATTRS;

    my %db_of       :ATTR(  :get<db>    :set<db>    :init_arg<db>   );
    my %save_to     :ATTR(  :get<save>                              );
    my %pk_of       :ATTR(  :get<pk>                                );
    my %pk_thru_db  :ATTR(  :get<pk_thru_db>    :set<pk_thru_db>    );

    sub BUILD {
        my ($self, $ident, $arg_href) = @_;

        # now can also pass create => 1 as part of $arg_href.
        # in that case, must also specify pk.

        my $class = ref $self;

        my $db = $arg_href->{db};
        # i have to assign here because Class::Std won't give access to
        # it until after returning, but init_arg is still nice enforcement.
        $db_of{ $ident } = $db;

        # hash 'save' is optional param to constructor
        my $save_href = $arg_href->{save};
        if ($save_href) {
            eval { $self->set_save( $save_href ); };
            if (my $e = Exception::Class->caught('Object::POOF::X')) {
                $e->rethrow();
            }
        }

        # if passed an primary key pk hash, make sure it checks out.
        # this requires generic call to type-checker function.
        # ( if this is an autoinc indexed pk, 
        #   will be { 'pk' => $bigint_unsigned } )
        # else exception, 
        # then assign fields into data_of{ident} and set_pk
        
        if (exists $arg_href->{primary_key}) {
            eval { $self->_init_primary_key( $arg_href ) };
            if (my $e = Exception::Class->caught('Object::POOF::X')) {
                #warn "caught, rethrowing:\n---\n$e\n---\n";
                $e->rethrow();
            }
            elsif ($EVAL_ERROR) {
                warn "crap - '$EVAL_ERROR'";
            }
            warn "got past eval.";
        }
    }

    sub is_pk_single_autoinc {
        my ($self) = @_;

        my @pk_fields = keys %{ $self->primary_key_fields };

        if  (   scalar @pk_fields == 1
            &&  $self->primary_key_fields->{ 
                    $pk_fields[0]
                }->{Extra} =~ m{auto_increment}
            ) {
            return scalar 1;
        }
        else {
            return scalar 0;
        }
    }

    sub is_primary_key {
        my ($self, $field) = @_;
        if (exists $self->primary_key_fields->{$field}) {
            return scalar 1;
        }
        else {
            return scalar 0;
        }
    }
        
    sub set_save {
        my ($self, $save_href) = @_;
        my $ident   = ident($self);
        my $db      = $db_of{$ident};

        if ($save_to{$ident}) {
            Object::POOF::X->throw(
                class   => ref $self,
                message =>  qq{Cannot set_save(): save exists and not saved:\n}
                        .    q{use $obj->add_save($field,$value) instead.},
            );
        }

        if (!ref $save_href eq 'HASH') {
            # let the caller know it screwed up
            Object::POOF::X->throw(
                class => ref $self,
                message => qq{Param 'save' to new() is not HASHREF.},
            );
        }
        
        # check each pair to make sure it is okay:
        map {
            eval { $db->check_save_pair( $self, $_, $save_href->{$_} ); };

            if (my $e = Exception::Class->caught('Object::POOF::X')) {
                # barf it on up:
                $e->rethrow();
            }

            else {
                my $save = $save_to{ ident($self) };
                $save->{$_} = $save_href->{$_};
            }
        } keys %{$save_href};

    }

    sub AUTOMETHOD {
        my ($self, $ident, $p) = @_;
        my $field = $_;

        warn "\ncalled AUTOMETHOD for field '$field'\n";

        return if !ref $self;

        my $db = $self->get_db;
        return if !ref $db;

        my $data = $data_of{$ident};

        #warn ref $self,": what is the current state of the key data?";
        #warn Dump($data);
        
        if (exists $data->{$field}) {
            # here is where i would check for timevalue expiration on 
            # objects that came from (had been branded on) a ranch.

            # here is also where i would branch off to auto-follow relations.

            # here is where the yodel builds up

            # return the cached value:
            return sub { return $data->{$field}; }
        }
        else {

            if  (   $self->is_primary_key( $field )
                &&  $self->is_pk_single_autoinc
                ) {
                $self->save();
                return $data->{$field};
            }
            else {

                # fetch value from database.

                eval { $self->fetch_field($field) };
                if (my $e = Exception::Class->caught('Object::POOF::X')) {
                    $e->rethrow();
                }
                elsif ($EVAL_ERROR) {
                    warn $EVAL_ERROR;
                }
                warn "beef: $field is '".$data->{$field}."'";
                return sub { return $data->{$field}; };
            }
        }
        return sub { return "horta"; };
    }

    sub fetch_field {
        my ($self, $field) = @_;
        my $ident   = ident($self);
        my $tables_fetched  = $tables_fetched_in{$ident};
        my $data            = $data_of{$ident};
        my $db              = $db_of{$ident};

        my $table_of_field = undef;

        eval { $table_of_field = $self->table_of_field($field) };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            if ($e =~ m{cannot lookup primary key}) {
                $table_of_field = $self->table();
            }
            else {
                $e->rethrow();
            }
        }
        elsif ($EVAL_ERROR) {
            Object::POOF::X->throw(
                message =>  ref $self
                        .   qq{ error looking for '$field':\n$EVAL_ERROR}
            );
        }
        elsif (!$table_of_field) {
            my $class = ref $self;
            Object::POOF::X->throw(
                message =>  qq{ looking for wrong field '$field'.},
                class   =>  $class,
            );
        }

        if (exists $tables_fetched->{$table_of_field} || $db->is_lazy()) {
            # if any data have been selected before, just get this field
        }
        elsif ($db->is_greedy()) {
            # do a whole select/join across all our tables and get all data
        }
        else {
            # default:
            # select * from just the table of the field.
            #map { $data->{$_} = $fetched->{$_} } keys %{$fetched};
            eval { $self->_fetch_table( $table_of_field ); };
            if (my $e = Exception::Class->caught('Object::POOF::X')) {
                $e->rethrow();
            }
        }
    }

    sub commit {
        # an alias for db->commit
        my ($self) = @_;
        return if !ref $self;
        my $db = $db_of{ ident($self) };
        eval { $db->commit(); };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            $e->rethrow();
        }
        elsif ($EVAL_ERROR) {
            warn "caught unhandled DB failure '$EVAL_ERROR'";
        }
        return;
    }

    sub _fetch_table : PRIVATE {
        my ($self, $table) = @_;
        my $ident = ident($self);

        if (!$table || ref $table) {
            Object::POOF::X->throw(
                message => q{fetch_table: no table.},
            );
        }

        my $pk = undef;
        eval { $self->get_pk(); };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            $e->rethrow();
        }
        elsif ($EVAL_ERROR) {
            Object::POOF::X->throw(
                message => qq{unhandled get_pk() eval_error:\n$EVAL_ERROR},
            );
        }
        elsif (!defined $pk) {
            # if there is no pk yet, 
        }
        else {
            warn "got a pk back: ", Dump($pk);
        }

        my $db      = $db_of{$ident};

        my $row = undef;
        eval {
            $row = $db->search_hash({
                table       => $table,
                max_rows    => 1,
                where_href  => $pk,
            });
        };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            $e->rethrow();
        }
        elsif ($EVAL_ERROR) {
            carp $EVAL_ERROR;
        }
        else {
            warn "got a row back:\n", Dump($row);
        }

        my $data = $data_of{$ident};

        map { $data->{$_} = $row->{$_}; } keys %{$row};
    }


    sub _init_primary_key : PRIVATE {
        my ($self, $arg_href) = @_;
        my $arg_pk_href = $arg_href->{primary_key};

        my $db = $self->get_db();

        my $pk_fields = undef;
        eval { $pk_fields = $self->primary_key_fields(); };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            $e->rethrow();
        }
        if (scalar keys %{$pk_fields} != scalar keys %{$arg_pk_href}) {
            Object::POOF::X->throw(
                message =>  ref $self   .qq{ _init_primary_key(): \n}
                        .   q{wrong count of pk fields.},
            );
        }
        else {
            #warn "primary_key_fields(): pk_fields are ",
                #Dump($pk_fields);
        }

        my $single_pk = undef;
        if (scalar keys %{$pk_fields} == 1) {
            ($single_pk) = keys %{$pk_fields};
        }
        #warn "single_pk is '$single_pk'";

        if  (   $arg_href->{create}
            &&  $single_pk
            &&  $pk_fields->{$single_pk}->{Extra} =~ m{auto_increment}
            ) {
            if ($arg_pk_href) {
                Object::POOF::X->throw(
                    message =>  ref $self 
                            .   qq{ could not create: pk fields specified,\n}
                            .   qq{but obj uses auto_increment},
                );
            }
            else {
                return;  # because it will be handled at save()
            }
        }

        # if creating or calling, must have some pk hash to work with:
        if (!$arg_pk_href) {
            Object::POOF::X->throw(
                message =>  ref $self 
                        .   qq{ could not find/create: no pk fields.},
            );
        }

        my $in_database = undef;
        eval { $in_database = $self->verify_pk($arg_pk_href); };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            $e->rethrow();
        }
        #warn "in_database: '$in_database'";
        
        if  (   !($in_database) 
            &&  !($arg_href->{create}) 
            ) {
            my $class = ref $self;
            Object::POOF::X->throw(
                message =>  qq{new() could not verify_pk:\n}
                        .   Dump($arg_pk_href)
                        .   qq{---},
                class   =>  $class,
            );
        }
        elsif ($arg_href->{create} && $in_database) {
            Object::POOF::X->throw(
                message => ref $self
                        .   qq{ new() could not create: primary key exists:\n}
                        .   Dump($arg_pk_href),
            );
        }
        warn "booga "x8;

        my $ident = ident($self);

        warn "assigning to pk: ", Dump($arg_pk_href);
        $pk_of{$ident} = $arg_pk_href;

        # and map its fields into data hash, because they are data too:
        map { $data_of{ $ident }->{$_} = $arg_pk_href->{$_} }
            keys %{$arg_pk_href};

        # and if creating a new object, map into save hash too:
        if ($arg_href->{create}) {
            map { $save_to{ $ident }->{$_} = $arg_pk_href->{$_} }
                keys %{$arg_pk_href};
        }
        
        return;
    }

    # wow, now pk attr can be hash of field/value pairs 
    # and they have to be the primary key of all the object's tables
    sub verify_pk {
        my ($self, $arg_pk_href, $db) = @_;

        if (ref $self) {
            if ($self->get_pk_thru_db) {
                return scalar 1;
            }
        }

        my $class = (ref $self) ? ref $self : $self;

        $db = (ref $self) ? $self->get_db() : $db;

        if  (   !$class 
            ||  !defined $db            ||  !$db->isa('Object::POOF::DB')
            ||  !defined $arg_pk_href   ||  !ref $arg_pk_href eq 'HASH' 
            ||  !scalar keys %{$arg_pk_href}
            ) {
            Object::POOF::X->throw( message => q{verify_pk(): bad params.} );
        }


        #warn "="x30;
        #warn "="x30;
        my @primary_key_fields = undef;
        eval { 
            @primary_key_fields 
                = sort keys %{ $self->primary_key_fields() }; 
        };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            $e->rethrow();
        }
        if (scalar @primary_key_fields != scalar keys %{$arg_pk_href}) {
            Object::POOF::X->throw(
                message => qq{$class verify_pk(): wrong count of pk fields.},
            );
        }
        #warn "primary_key_fields:       (@primary_key_fields)";

        my @arg_primary_key_fields = sort keys %{$arg_pk_href};

        #warn "arg_primary_key_fields:   (@arg_primary_key_fields)";

        my @fields_arent_pk = ( );
        foreach my $fld (@arg_primary_key_fields) {
            if (!grep { $_ eq $fld } @primary_key_fields) {
                push @fields_arent_pk, $fld;
            }
        }
        if (@fields_arent_pk) {
            Object::POOF::X->throw(
                message =>  qq{fields are not part of '$class' pk:\n(}
                        .   join(q{, }, @fields_arent_pk)
                        .   q{)},
            );
        }
        if (!arrays_eq( \@primary_key_fields, \@arg_primary_key_fields )) {
            Object::POOF::X->throw( 
                message =>  qq{$class verify_pk(): bad fields.} 
            );
        }

        my $sql 
            =   qq{
                    SELECT  }.join(q{, }, @primary_key_fields).qq{
                    FROM    ${$self->table_ref()} 
                    WHERE   
                } 
            .   join( qq{\nAND }, map { qq{$_ = ?} } @primary_key_fields ); 
            # where the same fields...
        my $sth = $db->prepare_cached($sql);
        my @pk_values = ( );
        eval { 
            @pk_values = $db->dbh->selectrow_array(
                $sth, {}, 
                map { $arg_pk_href->{$_} } @primary_key_fields 
            );
        };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            $e->rethrow();
        }
        elsif ($EVAL_ERROR) {
            Object::POOF::X->throw(
                message => qq{verify_pk caught DBI err: $EVAL_ERROR},
            );
        }

        if (@pk_values) {
            my $pk_thru_db = { };
            @{$pk_thru_db}{@primary_key_fields} = @pk_values;
            if (ref $self) {
                $self->set_pk_thru_db( $pk_thru_db );
            }
            return scalar 1;
        }
        else {
            return scalar 0;
        }

        # check all the tables?  warn/correct if object isn't full?
    }

    sub save {
        my ($self) = @_;
        my $ident = ident($self);
        my $save = $save_to{$ident};
            
        # first need to know what this obj's pk is.
        # if no pk, can one be generated:
        #   through autoinc if single pk auto_increment field? 
        #   through some other mysql mechanism/trigger/check?
        #   through a class method of ref $self?

        #warn "is_pk_single_autoinc responds ", $self->is_pk_single_autoinc;
        foreach my $field (keys %{$save}) {

            if  (   $self->is_pk_single_autoinc() 
                &&  $self->is_primary_key($field)
                ) {
                Object::POOF::X->throw(
                    message =>  qq{save(): field '$field' is }
                            .   qq{auto_increment primary key.},
                );
            }

            # if field is pk and pk was just or will shortly be generated, 
            # barf - caller should leave out so generation will be used.
            # otherwise let change value of pk since row won't change?
        }

        my $data = $data_of{$ident};

        my $statements = { };

        my $pk_field = my $pk_field_info = undef; # for autoinc pk field
        my @pk_fields = keys %{ $self->primary_key_fields };

        if  ($self->is_pk_single_autoinc()) {
            $pk_field = $pk_fields[0];
            $pk_field_info = $self->primary_key_fields->{ $pk_field };
            warn "pk_field is '$pk_field'";

            if ($data->{$pk_field}) {
                map {
                    $statements->{$_}->{sql_start}
                        = qq{ UPDATE $_ SET };
                    push @{ $statements->{$_}->{where_pairs} },
                        qq{ $pk_field = $data->{$pk_field} };
                } $self->all_tables;
            }
            else {
                map { 
                    push @{ $statements->{$_}->{set_pairs} },
                        qq{ $pk_field = ? };
                    $statements->{$_}->{sql_start}
                        = qq{ INSERT INTO $_ SET };
                } $self->all_tables;
            }
        }
        else {
            # make sure all pk fields are present ...
            
            # assemble components of statements

            # UNIMPLMENTED
        }

        # then map in the save fields:
        map { 
            my $table = $self->table_of_field($_);

            push @{ $statements->{ $table }->{set_pairs} },
                qq{ $_ = ? };
            push @{ $statements->{ $table }->{values} },
                $save->{$_};
        } keys %{$save};

        my $db = $db_of{$ident};

        my $main_table  = $self->table();
        my @more_tables = $self->more_tables();

        # in proper order of tables, main then others:
        my @tables = ( $main_table, @more_tables );

        my @sql_stack = ( );

        # build each sql and push on stack:
        TABLE:
        foreach my $table (@tables) {

            if (!exists $statements->{$table}) {
                if ($table eq $main_table) {
                    # i get it now - if there is no query for the main table,
                    # and this is single autoincrement,
                    # put a query on there that makes sense.
                }
                else {
                    next TABLE;
                }
            }

            my $sql = $statements->{$table}->{sql_start};

            $sql .= join(
                qq{,\n}, 
                @{ $statements->{$table}->{set_pairs} }
            );

            if (defined $statements->{$table}->{where_pairs}) {
                $sql .= qq{ WHERE \n };

                $sql .= join(
                    qq{,\nAND  }, 
                    @{ $statements->{$table}->{where_pairs} }
                );
            }

            warn "sql is \n---\n$sql\n---";
            push @sql_stack, [ $table, $sql ];
        }

        # if autoincrement id, handle this way:

        if  (   $self->is_pk_single_autoinc()
            &&  !$data->{$pk_field}
            ) {

            my $sql_first = undef;
            if ($sql_stack[0]->[0] eq $main_table) {
                # exec the first sql with '0' as the first value.
            }
            else {

            }

            my $sth = undef;
            eval {
                $sth = $db->prepare_cached( $sql_first );
            };
            if (my $e = Exception::Class->caught('Object::POOF::X')) {
                carp qq{LAME: $e};
                $e->rethrow();
            }
            elsif ($EVAL_ERROR) {
                warn qq{UNHANDLED DBI ERR: $EVAL_ERROR};
            }

            my $main_table = $self->table();

            my @values = (defined $statements->{$main_table}->{values})
                ?   @{ $statements->{$main_table}->{values} }
                :   ( );

            eval { $sth->execute( 0, @values ); };
            if (my $e = Exception::Class->caught('Object::POOF::X')) {
                $e->rethrow();
            }
            elsif ($EVAL_ERROR) {
                warn qq{UNHANDLED STH EXEC ERR: $EVAL_ERROR};
            }

            # then get the last insert id.

            my ($id) = $db->dbh->selectrow_array(qq{
                SELECT LAST_INSERT_ID()
            });

            warn "last_insert_id() is '$id'";

            # then use that as the first value for each further exec.

            foreach my $sql ($sql_stack[ 1 .. $#sql_stack ]) {
                my $sth = undef;
                eval { 
                    $sth = $db->prepare_cached( $sql ); 
                };
                if (my $e = Exception::Class->caught('Object::POOF::X')) {
                    #carp qq{LAME: $e};
                    $e->rethrow();
                }
                elsif ($EVAL_ERROR) {
                    warn qq{UNHANDLED DBI ERR: $EVAL_ERROR};
                }
    
                eval { $sth->execute( $id, @values ); };
                if (my $e = Exception::Class->caught('Object::POOF::X')) {
                    $e->rethrow();
                }
                elsif ($EVAL_ERROR) {
                    warn qq{UNHANDLED STH EXEC ERR: $EVAL_ERROR};
                }
            }


        }

        # else insert all the values including the primary key field values:
        else {
            foreach my $sql_aref (@sql_stack) {

                my $sth = undef;
                eval { 
                    $sth = $db->prepare_cached( $sql ); 
                };
                if (my $e = Exception::Class->caught('Object::POOF::X')) {
                    #carp qq{LAME: $e};
                    $e->rethrow();
                }
                elsif ($EVAL_ERROR) {
                    warn qq{UNHANDLED DBI ERR: $EVAL_ERROR};
                }
    
                my @values = (defined $statements->{$table}->{values})
                    ?   @{ $statements->{$table}->{values} }
                    :   ( );
    
                eval { $sth->execute(@values); };
                if (my $e = Exception::Class->caught('Object::POOF::X')) {
                    $e->rethrow();
                }
                elsif ($EVAL_ERROR) {
                    warn qq{UNHANDLED STH EXEC ERR: $EVAL_ERROR};
                }
            }
        }
        
    }

    sub add_save {
        my ($self, $field, $value) = @_;
        my $class = ref $self;

        my $db = $self->get_db();

        eval { $db->check_save_pair( $self, $field, $value ); };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            # barf it on up:
            $e->rethrow();
        }

        my $save = $save_to{ ident($self) };
        $save->{$field} = $value;

        return;
    }


    sub table_of_field {
        # $table = $object->table_of_field($fieldname);
        my ($self, $fieldname) = @_;

        if (!$fieldname) {
            Object::POOF::X->throw(
                message     => q{empty fieldname passed to table_of_field()},
                class       => ref $self,
            );
        }

        my @primary_key_fields = ( );
        #cluck "table_of_field: self is '$self'";
        eval { @primary_key_fields = $self->primary_key_fields();  };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            $e->rethrow();
        }

        #warn "pk fields are (@primary_key_fields)";
        # if is fieldname is part of the primary key, can't look it up,
        # because it would be in more than one table.
        if (scalar grep { $_ eq $fieldname } @primary_key_fields) {
            #cluck "table_of_field: self is '$self'";
            Object::POOF::X->throw(
                message     =>  qq{table_of_field() cannot lookup }
                            .   qq{primary key '$fieldname'.},
                class       =>  ref $self,
            );
        }

        # this can be only as instance method.
        if (!ref $self) {
            Object::POOF::X->throw(
                message     => q{table_of_field() called as class method.},
                class       => ref $self,
            );
        }

        my $class = ref $self;

        # if table of this field already cached, return it:
        if  (   (exists $table_of_field->{$class})            # don't autoviv
            and (exists $table_of_field->{$class}->{$fieldname}) 
            ) {
            return $table_of_field->{$class}->{$fieldname};
        }

        # it will be connected to database (because it was created ok)
        my $db = $self->get_db();

        # haven't found it, so try searching our tables:
        my @found_tables = ( );

        SEARCH_TABLES:  
        foreach my $table (@{ $self->all_tables_aref() }) {
            # if table doesn't exist, crap out, because class def is wrong:
            if (!$db->exists_table($table)) {
                Object::POOF::X->throw(
                    message     
                        => qq{table '$table' in class def does not exist.},
                    class => ref $self,
                );
            }

            eval {
                if (exists $db->$table->{info}->{$fieldname}) {
                    $table_of_field->{$class}->{$fieldname} = $table;
                    push @found_tables, $table;
                }
            };
            # check for errors connecting to db on automethod
            if (my $e = Exception::Class->caught('Object::POOF::X')) {
                $e->rethrow();
            }

            #warn Dump($db->$table->{info});
            # keep searching through all tables, for duplicates.
        }

        if (@found_tables == 0) {
            # it wasn't found: return false.
            return;
        }
        elsif (@found_tables == 1) {
            # it was found (and in only one table): return table name.
            return scalar pop @found_tables;
        }
        else {
            # the tables have been defined badly, with duplicate 
            # field names in multiple tables for the class.  barf.
            Object::POOF::X->throw(
                message 
                    =>  qq{class tables defined badly:\n}
                    .   qq{field '$fieldname' found in multiple tables:\n}
                    .   qq{\t(} . join(q{, }, @found_tables) . q{)},
                class => ref $self,
            );
        }
    }

    ##############################################
    #
    # some informational methods:
    # can be called as class or object method.
    # encapsulates some "cleverness" with package
    # vars in the inheriting class that should be hidden.  
    # if the package vars don't exist, they're created
    # readonly so they can't be changed again.
    # along that line, the functions should try to check if
    # the values are readonly and make them so if they are not,
    # but it doesn't do that (yet).
    #


    my $primary_key_fields_aref = undef;
    my $primary_key_fields_href = undef;
    sub primary_key_fields {
        my ($class, $db) = @_;

        if (defined $primary_key_fields_aref) {
#           cluck "primary_key_fields: cache aref found: ", 
#               Dump($primary_key_fields_aref);
#           warn "want REF is   '".want('REF')."'"; 
#           warn "want ARRAY is '".want('ARRAY')."'";
#           warn "want HASH is  '".want('HASH')."'";
#           warn "want LIST is  '".want('LIST')."'";
#           warn "want SCALAR is'".want('SCALAR')."'";
#           warn "wantarray is  '".wantarray."'";
#           warn "howmany is    '".want('COUNT')."'" if defined want('COUNT');
            if (want('ARRAY')) {
                return @{ $primary_key_fields_aref };
            }
            elsif (want('REF') eq 'ARRAY') {
                return $primary_key_fields_aref;
            }
        }
        elsif (defined $primary_key_fields_href) {
            #warn "primary_key_fields: cache href found: ", 
                #Dump($primary_key_fields_href);
            return $primary_key_fields_href;
        }

        if (ref $class) {
            # 'class' is a 'self', is obj, called as inst. method 
            $db = $class->get_db(); 
            if (!$db) {
                Object::POOF::X->throw(
                    message =>  q{->primary_key_fields(): no access }
                            .   q{to O:P::DB from obj},
                    class   => $class
                );
            }
            $class = ref $class;
        }
        else {
            if (!$db) {
                Object::POOF::X->throw(
                    message =>  q{->primary_key_fields(): }
                            .   q{called as class method without db param.},
                    class   => $class
                );
            }
        }

        eval { $db->tables_have_same_primary_key_fields_in_class($class) };
        if (my $e = Exception::Class->caught('Object::POOF::X')) {
            warn qq{$e};
            $e->rethrow();
        }
        else {
#           warn "returning?";
#           warn "crap:";
#           warn "want REF is   '".want('REF')."'"; 
#           warn "want ARRAY is '".want('ARRAY')."'";
#           warn "want HASH is  '".want('HASH')."'";
#           warn "want LIST is  '".want('LIST')."'";
#           warn "want SCALAR is'".want('SCALAR')."'";
#           warn "wantarray is  '".wantarray."'";
#           warn "howmany is    '".want('COUNT')."'" if defined want('COUNT');
                
            if (want('LIST')) {
                #carp "pkfields() fetching LIST";
                my @primary_key_fields 
                    =   (   $db->primary_key_fields_of_table( 
                                ${ $class->table_ref() } 
                            ) 
                        ); # cast array context
                $primary_key_fields_aref = \@primary_key_fields;
                #warn "primary_key_fields returning dereferenced aref";
                return @primary_key_fields;
            }
            elsif (want('REF') eq 'ARRAY') {
                # should work, but doesn't??
                my @primary_key_fields 
                    =   (   $db->primary_key_fields_of_table( 
                                ${ $class->table_ref() } 
                            ) 
                        ); # cast array context
                $primary_key_fields_aref = \@primary_key_fields;
                #warn "primary_key_fields returning aref";
                return $primary_key_fields_aref;
            }
            else {
                #cluck "pkfields() fetching HASH";
                eval {
                    $primary_key_fields_href
                        = $db->primary_key_fields_of_table(     
                            ${ $class->table_ref() } 
                        );
                };
                if ($EVAL_ERROR) {
                    warn qq{$EVAL_ERROR};
                }
                #warn Dump($primary_key_fields);
                #warn "primary_key_fields returning href";
                return $primary_key_fields_href;
            }
        }
    }

    sub table {
        my ($class_or_self) = @_;
        return scalar ${ $class_or_self->table_ref() };
    }

    sub table_ref {
        # so, you could override the main table by setting main_table,
        # or it is deduced from the class name... everything after the
        # child class, lc'd, and :: translated to __.
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';
        if (!defined ${"${class}::main_table"}) {
            my ($table) = $class =~ m{ \A \w+ :: (.*) \z }xms;
            ($table = lc($table) ) =~ s{:}{_}gxms;
            Readonly ${"${class}::main_table"} => $table;
        }
        return \${"${class}::main_table"};
    }

    sub more_tables {
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        return @{ $class->more_tables_aref() };
    }
    
    sub more_tables_aref {
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';
        if (!defined @{"${class}::more_tables"}) {
            Readonly @{"${class}::more_tables"} => ();
        }
        return \@{"${class}::more_tables"};
    }
    
    sub all_tables_aref {
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';
        if (!defined @{"${class}::_all_tables"}) {
            Readonly @{"${class}::_all_tables"} => ( 
                ${ $class->table_ref()   }, 
                @{ $class->more_tables_aref()  },
            );
        } 
        return \@{"${class}::_all_tables"};
    }
    
    sub all_tables {
        # it is better to call all_tables_aref and dereference it yourself
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';

        # if it is not yet defined, it will be generated:
        return @{ $class->all_tables_aref() };
    }

    sub relatives {
        # it is better to call relatives_href and dereference it yourself
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';
        return %{ $class->relatives_href() };
    }
    
    sub relatives_href {
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';
        if (!defined %{"${class}::relatives"}) {
            # cannot add relatives on the fly.
            Readonly %{"${class}::relatives"} => ();
        }
        return \%{"${class}::relatives"};
    }

    sub child_rootname {
        # child_rootname of object is like 'MyApp', everything before first ::
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';
        if (!defined ${"${class}::_child_rootname"}) {
            Readonly ${"${class}::_child_rootname"} 
                => $class =~ m{ \A (\w+) :: .* \z }xms;
        }
        return ${"${class}::_child_rootname"};
    }


}

1; # Magic true value required at end of module
__END__

=head1 NAME

Object::POOF - Persistent Object Oriented Framework (for mod_perl)


=head1 VERSION

This document describes Object::POOF PLANS for version 0.0.7.

=head1 SYNOPSIS

Object::POOF doesn't try to work with every database.  It's designed
for use with MySQL's InnoDB transactional storage engine.  Complex
and invisible magic gives you a simplified way of creating objects
that persist in the database.  Where information can be deduced easily
from looking at the database structure, POOF does not need you to tell it.



 package Myapp::DB;
 use base qw( Object::POOF::DB );
 # some config, see Object::POOF::DB manpage...

 package Myapp::Foo;            # table name is 'foo'
 use base qw( Object::POOF );
 use Readonly;
 Readonly our %relatives => (
    biz     => { class => 'Myapp::Biz' },
 );

 # ...some other class definitions for biz and its relationships...

 package main;

 my $db = Myapp::DB->new();
 my $foo = Myapp::Foo->new({ 
    db  => $db,                         # pass transact. thread
    pk  => { fooname => 'Mr. Foo' },    # where primary key = ...
 });

 print $foo->bar, "\n";         # table foo has column 'bar'

 # "s2o" == self-2-one
 # "s2m" == self-2-many
 # s2o / s2m ( 1:1 / 1:N ) relationships are determined by 
 # database schema, see 'Determining Relationships' below.
 # POOF doesn't need intermediary information to determine that.
 # Instead, it throws smart exceptions when something doesn't work.
 
 # but more than $foo->bar, stretch out through 
 # multiple relationship levels:

 # foo s2o biz s2m baz(id 42), column 'noz':

 print $foo->biz->baz({ pk => { id => 42 } })->noz, "\n";

 # all values are magically selected and populated 
 # with a single SELECT...LEFT JOIN query, and populated 
 # objects are cached in the Ranch.  Each s2m relation
 # called with parameters is answered by the Herd's Shepherd.
 # The Shepherd will be eventually offer up custom Herd 
 # data structures such as Tree::Simple (implementation goal).

 # so when you do this selection:
 
 my $jazz_master 
    = $foo
        ->biz
            ->baz({ pk => { id => 42 } })
                ->boz
                    ->diz({ 
                        pk => { 
                            first_name  => 'Dizzy', 
                            last_name   => 'Gillespe' 
                        } 
                    });
 
 # nothing in database is queried until 
 # following baz(id 42) s2o boz s2m diz at pk values.

 # if you had known you wanted a lot of objects 
 # pre-populated in advance:
 
 $foo->call({
    what => 'all',  # all property fields of a foo
    follow => {
        biz => {        # what not specified, defaults to 'all'
            follow => {
                baz => {    # again 'all' columns of baz
                    pk      => { id => 42 },
                    follow  => {
                        what    => [ 
                            qw( event_dt location_address ) 
                        ],
                        boz     => {
                            follow  => {
                                # get all diz's, incl. Dizzy:
                                diz     => { },  
                            },
                        },
                    },
                },
                food => {
                    pk      => { name => 'Corn Dog' },
                    what    => [ 'price' ],
                },
            },
        },
    },
 });   

But you have to be smart about how you use this kind of thing.
For example, in the above call() statement, what if table baz
has a big text column?  If there are a lot of diz's in the boz
of each baz, that text column of the intermediary relationship
will be duplicated in the output of the LEFT JOIN, which could
be a hit on the performance of the query and increase network
volume.  call() is a little bit greedy by default.  You might 
have wanted to specify a 'what' part of the 'baz' hash to 
eliminate that big text field from the LEFT JOIN statement.

Specifying an order => [ [ column1 => 'DESC' ], [ column2 => 'ASC' ] ] 
parameter to parts of call() will eventually do what you expect.
When referenced as an array, the herd will return with that order.

 # supposing 'location' is a column of table 'baz':

 foreach my $baz ( @{ $foo->biz->baz } ) {
    print $baz->location;  
 }

 # etc.

=head1 HUMOROUS DISCLAIMER 

It doesn't work yet. 

=head1 CURRENT WORK

Remove dependency on autoincrement primary key field named 'id.'
Instead, can use one or more arbitrary fields that comprise 
the primary key.  However, if the primary key consists of a single
auto_increment field, it will be used like you expect.  And if
your package contains a function 'generate_primary_key', it will
be used to generate a new one.  Triggers are not implemented.

Call statement is optional to formulate a joined query; instead
you can call out to a relationship and the Yodel will get all
the data for you in a single statement.

Relatives are simplified, so you do not have to distinguish
between one-to-many and one-to-one relationships.  The type
of relationship is a property of the database schema itself---
the way you define nested unique keys in the primary key fields.
So, there is no need to duplicate this information in your 
packages.  Instead, you just name a relationship to a class.
If the foreign key is neither in this object's tables or in
the remote object's tables, you have to specify the name of
the intermediary relational table that contains the foreign key.

=head1 IN DEPTH

=head2 Determining relationships

Nested unique keys, foreign keys, primary key combinations
and their positions in table structure determine 
1:1 and 1:n relationships between entities.  You should not have to
duplicate that information in the class definition, or in some
intermediary configuration file.  Object::POOF::DB can analyze
that information as it needs to.

So in the class definition, all it has to specify are the tables that
belong to a class, and a hash of relatives that contain the
class name and the table that contains the foreign key to the
remote object.

So, rel hash format becomes:

 my $rels = {
    nickname => {
        class => 'MyApp::Whatsis',
        table => 'self_to_many_other',
    },

    nickname => {
        class => 'MyApp::Someother::Whatsis',
        table => 'self_to_one_other',
    },
 };

...where the tables are the table that contains the foreign key to the
remote object.

So in a relationship from each Foo one-to-many Bar, tables would
look like this:

 CREATE TABLE foo (
    fooname         VARCHAR(16) NOT NULL PRIMARY KEY,
    phone           VARCHAR(24)                         -- or whatever
 ) TYPE=InnoDB;

 INSERT INTO foo (fooname) VALUES 
    ('bob'), ('sally'), ('sue'), ('reynolds');

 CREATE TABLE bar (
    barname         VARCHAR(16) NOT NULL PRIMARY KEY,
    phone           VARCHAR(24)
 ) TYPE=InnoDB;

 INSERT INTO bar (barname) VALUES
    ('pig n boar'),                 ('cock n axe'),
    ('screaming jehosephat''s'),    ('the anaesthetic tide');


 CREATE TABLE haunt (
    fooname         VARCHAR(16) NOT NULL,

    barname         VARCHAR(16) NOT NULL,

    FOREIGN KEY (fooname) REFERENCES foo (fooname)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (barname) REFERENCES bar (barname)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    PRIMARY KEY (fooname, barname)
 ) TYPE=InnoDB;

Haunts don't need to be a separate class in their own right unless
you need that relationship of Foos to Bars to have its own custom
methods in a package.  Otherwise, 'haunts' in this case can be
read like a verb in the logic of your system.  Each Foo haunts 
one or more Bar.  You'd still say:
    
    foreach my $bar ( @{ $foo->haunt } ) { # see Foo class def below
        # ...
    }

Even if Haunt did have its own package, which related
to Foos and to Bars, you still wouldn't need to change Foo's 
%relatives, unless a Foo needed access to the methods of your
Haunt package.  It is easiest to leave 'haunt' as simply a nickname
for Bars in this type of relationship from Foo to Bar.

Our intrepid ship of foos needs work to support their drinking habits.
So, they get jobs at the bars.  But each person only has time to
work at one bar, and each bar only needs to employ one person.

 CREATE TABLE barback (
    fooname         VARCHAR(16) NOT NULL UNIQUE,

    barname         VARCHAR(16) NOT NULL UNIQUE,

    FOREIGN KEY (fooname) REFERENCES foo (fooname)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (barname) REFERENCES bar (barname)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    PRIMARY KEY (fooname, barname)      
        -- nested unique keys enforce 1:1 rel
 ) Type=InnoDB;

Similarly, make only one of the primary keys have a nested unique key
in order to determine a 1:Many relationship.

You can also group other fields in the table as nested unique
keys to enforce other properties of your system.  For example,
the bars want to schedule attendance at events.  They have
arranged never to have events on the same day.

 CREATE TABLE foo_attending_bar_parties (
    party_dt        DATE NOT NULL UNIQUE,

    fooname         VARCHAR(16) NOT NULL,

    barname         VARCHAR(16) NOT NULL,

    FOREIGN KEY (fooname) REFERENCES foo (fooname)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (barname) REFERENCES bar (barname)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    PRIMARY KEY (event_dt, barname)     -- nested unique key enforces
                                        -- only one party per day
 ) Type=InnoDB;

Then I can see about getting the exceptions to feed through
a 'nice message' for display to the web browser through an
Exception::Class method.


 package Drunken::Foo;
 use strict;
 use warnings;
 use base qw( Object::POOF );
 use Readonly;
 Readonly our %relatives => (
    haunt => {                              # interpreted as a 
        class => 'Drunken::Bar',            # a self-to-many
        table => 'haunt',
    },

    employer => {                           # self-to-one
        class => 'Drunken::Bar',
        table => 'barback',
    },

    party => {                              # one (self) to many
        class => 'Drunken::Bar',
        table => 'foo_attending_bar_parties',

        # access party date as $foo->party->party_dt...
        # party_dt from intermediary table will be mapped
        # from a secondary hash of the bar in this relationship 
        # to this foo and spat back automatically
    },
 );

Or, you may need to make parties more complicated, and entities
in their own right, if you need methods in that frame of reference.
So the party table would be:

 CREATE TABLE party (
    party_dt            DATE NOT NULL UNIQUE PRIMARY KEY,
    barname             VARCHAR(16),

    FOREIGN KEY (barname) REFERENCES bar (barname)
        ON UPDATE CASCADE ON DELETE CASCADE

 ) Type=InnoDB;

And you'd need to change the party schedule table:

 CREATE TABLE foo_attending_bar_parties (
    party_dt            DATE NOT NULL,
    fooname             VARCHAR(16) NOT NULL,

    FOREIGN KEY (party_dt) REFERENCES party (party_dt)
        ON UPDATE CASCADE ON DELETE CASCADE,

    FOREIGN KEY (fooname)  REFERENCES foo (fooname)
        ON UPDATE CASCADE ON DELETE CASCADE,

    PRIMARY KEY (party_dt, fooname)
 ) Type=InnoDB;

Then a Foo would be related 1:M to each Party they planned to go to.


 package Foo;
 # ...
 Readonly our %relatives => (
    bars_frequented => {                    # interpreted as 
        class => 'Drunken::Bar',            # a one-to-many
        table => 'haunts',
    },

    employer => {                           # one-to-one
        class => 'Drunken::Bar',
        table => 'barback',
    },

    party => {                              # one (self) to many
        class => 'Drunken::Party',
        table => 'foo_attending_bar_parties',
    },
 );

 package Party;
 # ...
 Readonly our %relatives => (
    bar => {                      # no table means one of our own
        class => 'Drunken::Bar',  # tables; in this case 'party'
    },                            # contains barname foreign key

    guests => {
        class => 'Drunken::Foo',
        table => 'foo_attending_bar_parties',
    },
 );


And somewhere in your code dealing with the party schedule, for
a given foo and a given party, reference it like this to find the bar
for the party on Halloween of 2005, if bob is scheduled to attend.

 my $halloween = 20051031;  # hopefully can make it work with DateTime

 my $bob = Foo->new({ db => $db, pk => { fooname => 'bob' } });

 my $barname = undef;
 eval {
    $barname = $bob
        ->party({ pk => { party_dt => $halloween } })
            ->bar
                ->barname;
 };
 if (!defined $barname) {
    $bob->add_party({ pk => { party_dt => $halloween } });
 }

In this case, the AUTOMETHOD as inherited by Foo will detect
object wanted, so will push the call for 'party' to a Yodel.

What it pushes to the Yodel is more information than just a 
stack of strings.  A stack of hashrefs that also has the parameters
of any function called.  Those parameters are interpreted in the
case of pk => { party_dt => 20051031 } to infer that a foo relates
one-to-many party, and we are asking for the party where the primary
key is column party_dt with value 20051031.  If, for example, there
were no party on that date, or party_dt were not a primary key
field, or some other error, Yodel would return an exception.

So first Want will be OBJECT.  Is party already populated?  No.
Push { party => { pk => { party_dt => 20051031 } } } 
to call stack, return self.

Then Yodel will detect OBJECT wanted (bar). 

If Yodel detects objects of class Bar in the Ranch pool, 
it could try to reduce the fields of bar selected in the query 
to just the primary key fields if there were a further select level,
or just to the column barname instead of being greedy.  Then the
results of any fields obtained by the query will repopulate the
entries in the ranch.  

Because barname is a data field of this object, it's ready to yodel
out for the objects.  Assemble, execute, and parse the SELECT...JOIN 
call, passing values to Shepherds that populate Herds for each class and 
link member objects together.  

Then return the bar object.  When its AUTOMETHOD is called, it will 
find the field barname and return the contents, the string "screaming 
jehosephat's".

Assembling the primary key herd index for a multi-column primary key
is going to be interesting.  Maybe I should use a YAML dump of the
pk hash (with all the keys/values) as a hash key.  Hmmm.

Nicely, Yodel is the package that returns exceptions rethrown by the
Object::POOF AUTOMETHOD.  So they get spit back to the caller code,
which can access the simple field, or stringify to get full message.



=head1 OLD SYNOPSIS

some of this doc may be wrong.  this suite is still highly experimental
and subject to change but i am releasing this version 
because i have a contract starting
and i am always suspicious of corporations trying to lay claim to my work.
- Mark Hedges 2005-09-06

 package MyApp::Foo;
 # a table named 'foo' exists in db with autoinc 'pk' field
 use Readonly;
 use base qw(Object::POOF);

 # make sure to make @more_tables and %relatives Readonly in 'our' scope.
 # (outside of the private block used by Class::Std)
 # this makes them accessible through the class without making an object.
 # (but they cannot be changed by anything but you, with a text editor.)
  
 # other tables containing fields to be joined 
 # to 'foo' by 'pk' field when fields are requested:
 Readonly our @more_tables => qw( foo_text foo_info foo_html );

 # relationships to other classes:
 Readonly our %relatives => (
     # self to other relationships (one to one):
     s2o => {
         # a table named 'bar' exists in db, and foo.bar_pk = bar.pk
         bar     => {
             class   => 'MyApp::Bar',
         },
     },

     # self contains many - 
     # each foo has only one rel to each sCm entity
     sCm => {
         # table named 'biz'; foo.pk = biz.foo_pk
         biz     => {
             class   => 'MyApp::Biz',
         },
     },
 
     # self to many - possibly more than one rel to each s2m entity,
     # uniquely enforced by a field of the interim relational table
     s2m => {
         baz     => {
             class       => 'MyApp::Baz',
             reltable    => 'r_foo_baz',
             relkey      => 'boz_pk',    # a 'boz' will be made here
         },
     },
 
     # many to many - possibly more than one rel to each m2m entity,
     # with no restrictions (reltable entry can be exactly duplicated)
     m2m => {
         boz__noz    => {
             class       => 'MyApp::Boz::Noz',
             reltable    => 'r_foo_boz__noz',
         },
     },
 );

 1; # end of package definition, unless you add custom object methods.

 ########

 # later in program...

 # a MyApp::DB thread inheriting from Object::POOF::DB
 my $db = MyApp::DB->new();


 # note: the transparent use of the future Yodel package to trick 
 # the -> operator will be able to skip over some inefficient 
 # laziness of selects and cache seen objects in the Ranch,
 # but if you know in advance what you want, you might as well tell
 # it to get the whole shebang at once, like this:

 my $foo = MyApp::Foo->new( {
    db      => $db,  
    where   => {
        # where a field of foo = some value
        fooprop => 'value',
    },
    follow  => {
        sCm => {
            biz => { 
                what => 'all',
            },
        },
        s2m => {
            baz => {
                what => [ qw( baz_prop1 baz_prop2 baz_prop3 ) ],
                follow => {
                    m2m => {
                        # MyApp::Baz m2m MyApp::Schnoz, follow it
                        schnoz => { 
                            what => [qw( schnoz_prop1 schnoz_prop2 )],
                        }, 
                    },
                },
            },
        },
    },
 });
 print "$foo->bar->barprop\n"; # s2m's are constructed by default

 # call a herd in array context (similar in arrayref context):
 foreach my $biz ($foo->bar->biz) {   
    $biz->somemethod( $foo->fooprop );  # or something
 }

 # call a herd in hash context (similar in hashref context):
 while (my ($baz_pk, $baz) = each $foo->baz) {
    print "adding rel for $baz_pk\n";
    $baz->add_rel( {
        m2m => {
            schnoz => [ $schnoz1, $schnoz2, $schnoz3, ],
        },
    });
    $baz->delete_rel( {
        m2m => {
            schnoz => $schnoz4,
        },
    });
 }

=head1 DESCRIPTION

Object::POOF provides a Persistent Object Oriented Framework implemented
with some Perl Best Practices (as outlined in the O'Reilly book by that 
name.) It also provides a framework for applications running under 
mod_perl
custom handlers (or, yuck, CGI scripts) that will handle de-tainting
from easy form patterns, exporting of patterns to Javascript form            
validation, users and uri-based function permissions, and hopefully
an accounting suite eventually.  
    
For an OO application designer to get started, all they have to do
is define the relationships of entity packages to other entities.
Calls to various select and save routines are usually passed a hash
reference similar in structure to the hash used to define relationships.
Once you are into 'the zone' of writing with Object::POOF, you can 
stay in the mindset of the relationships between entities and (mostly)
forget about writing SQL.  For large group selects such as the one
above using the 'follow' hashref, Object::POOF internals will format
a huge join statement, parse it and populate all objects.  It does not
duplicate population of objects with the same pk, instead it keeps a
'Ranch' or pool of entities and then links them into the appropriate
'Herds' related to your point of view.  The Object::POOF::Ranch can
be used to do mass-selects of heavy data after following relations,
and is intended to be an 'entity pool' to improve performance of
mod_perl apps under Apache2 worker mpm.  (This will require
considerable thread-safe development.)

Then, you can call values of fields by identical accessor names and 
the next "herd" of related objects by accessors named the short names
in the rel hashes.  If you call an accessor that refers to valid 
fields or related entities that haven't been populated yet, they
will be followed, so you can do 'lazy population.'  But beware,
with large groups of entities (like for a tabular report, for example),
you'll have to use a follow call to get them all at once.  But this
can have its drawbacks too, since it uses a big left join that will
make some data redundant.  So, if there are big text fields or blobs
or something in an intermediary relation of your depth of selection,
and you think that will slow down the query, leave them out and then
call a mass-select method for them:

 # following the above example, populate the many schnoz herds
 # with heavy text fields left out of the original follow query:
 my $ranch = $foo->get_ranch();
 $ranch->load( {
    class => 'MyApp::Schnoz',
    fields => [ qw( text1 text2 ) ],
 });

The Schnoz's will remain linked in the original related locations
under your point of view from $foo->baz, but now for each Schnoz,
$schnoz->text1 will not have to do a lazy select.  The point is
if you have 10,000 Schnoz's linked through in $foo, and you want
to get the big text1 field from each of them, you don't want to slow
down the original follow join with the field, but you don't want to
have it do 10,000 queries either.  The general rule is you have to
think about what you're doing to make it most efficient.


=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.



=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

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
  
Object::POOF requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

Relies on use of transactional database.  Currently only uses
MySQL's InnoDB engine.

Object::POOF and its sub-modules require the following modules:

    Class::Std
    Class::Std::Utils
    Attribute::Types
    Contextual::Return
    Exception::Class
    Perl6::Export::Attrs
    Readonly
    List::MoreUtils
    Regexp::Common
    Data::Serializer
    YAML


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported. (Yeah right.)


=head1 BUGS AND LIMITATIONS

The LISP-ish excessive ending braces for call statements are annoying.

Because internals format a giant left join, it often decreases 
efficiency of SQL calls to select all information at once.  Sticking
to the pk fields and small data is a good idea, then call mass-select
population methods in the ranch (see Object::POOF::Ranch).

The major bug as of this writing is that nothing actually works.  :-D

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

Please report any bugs or feature requests to
C<bug-object-poof@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 PLANS

At some point the Shepherd should start constructing custom Herd
objects that implement more complex data structures based on key
name fields like 'up_pk', 'child_pk', etc. that self-refer to
objects of the same class/table. 


=head1 SEE ALSO

Object::POOF::App(3pm),
Object::POOF::DB(3pm),
Object::POOF::Ranch(3pm),
Object::POOF::Shepherd(3pm)


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
