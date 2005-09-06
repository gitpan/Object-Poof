package Object::POOF;

use version; $VERSION = qv('0.0.6');

use warnings;
use strict;
use Carp;
use English '-no_match_vars';
use Data::Types qw(:is);
use Switch 'Perl6';
use Readonly;

use Object::POOF::X;            # import exception subclasses
#use Object::POOF::Data;         # import data methods
use Object::POOF::Constants;    # Readonly constants
#use Object::POOF::Class;        # install class methods (?)

# Module implementation here

use Class::Std;
{ 

    my $table_of_field = { };

    # i think i may want to restrict access to %data_of somehow.
    my (
        %data_from,
        %last_select_ts_for,
        %last_insert_ts_for,
    ) :ATTRS;

    my %db_of   :ATTR(  :get<db>    :set<db>    :init_arg<db>   );
    my %save_to :ATTR(  :get<save>  :set<save>                  );

    sub BUILD {
        my ($self, $ident, $arg_href) = @_;

        my $class = ref $self;

        # hash 'save' is optional param to constructor
        my $save_href = $arg_href->{save};
        if ($save_href) {
            if (ref $save_href eq 'HASH') {
                $self->set_save( $save_href );
            }
            else {
                # let the caller know it screwed up
                Object::POOF::X->throw(
                    message 
                        => qq{Param 'save' to $class new() is not HASHREF.},
                );
            }
        }
    }

    sub add_save {
        my ($self, $field, $value) = @_;
        my $class = ref $self;

        #eval { $self->check_save_pair( $field, $value ); };
        #if (my $e = Exception::Class->caught('Object::POOF::X')) {
            ## barf it on up:
            #$e->rethrow();
        #}

        # all pairs will be checked upon calling save.
        my $save = $save_to{ ident($self) };
        $save->{$field} = $value;

        return;
    }

    sub check_save_pair {
        my ($self, $field, $value) = @_;
        my $class = ref $self;

        # should only pass non-empty scalars as params:
        if (ref $field || ref $value || !$field || !$value) {
            Object::POOF::X->throw(
                message
                    =>  qq{Non-scalar or empty field/value passed\n}
                    .   qq{to a save method for $class.\n},
            );
        }

        # can never set 'id' field with a save method:
        if ($field eq 'id') {
            Object::POOF::X->throw(
                message 
                    => qq{Save method cannot change field 'id' for $class.\n},
            );
        }

        # make sure field is in one of this class's tables:
        my $table = $self->table_of_field( $field );
        if (!$table) {
            Object::POOF::X->throw(
                message 
                    =>  qq{Save method for $class could not find\n}
                    .   qq{field $field in its tables:\n}
                    .   join(q{, }, $class->all_tables() ) .qq{\n},
            );
        }

        # could also add data type checking here.
        my $db      = $self->get_db();
        my $info    = $db->$table->{info};
        my $type    = $info->{type};

        given ($type) {
        }

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

        # every table has an 'id' field!
        if ($fieldname eq 'id') {
            Object::POOF::X->throw(
                message     => q{table_of_field() cannot lookup field 'id'},
                class       => ref $self,
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
        my $ident = ident($self);
        my $db = $db_of{$ident};

        # haven't found it, so try searching our tables:
        my @found_tables = ( );
        SEARCH_TABLES:
        foreach my $table (@{ $self->all_tables_ref() }) {

            # if table doesn't exist, crap out, because class def is wrong:
            if (!$db->exists_table($table)) {
                Object::POOF::X->throw(
                    message     
                        => qq{table '$table' in class def does not exist.},
                    class => ref $self,
                );
            }

            if (exists $db->$table->{info}->{$fieldname}) {
                $table_of_field->{$class}->{$fieldname} = $table;
                push @found_tables, $table;
            }
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
            # field names # in multiple tables for the class.  barf.
            Object::POOF::X->throw(
                message 
                    =>  qq{class tables defined badly:\n}
                    .   qq{field '$fieldname' found in multiple tables:\n}
                    .   qq{\t(} . join(q{, }, @found_tables) . q{)},
                class => ref $self,
            );
        }
    }

    # some informational methods:
    #
    sub table_ref {
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
    
    sub more_tables_ref {
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
    
    sub all_tables_ref {
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';
        if (!defined @{"${class}::_all_tables"}) {
            Readonly @{"${class}::_all_tables"} => ( 
                ${ $class->table_ref()   }, 
                @{ $class->more_tables_ref()  },
            );
        } 
        return \@{"${class}::_all_tables"};
    }
    
    sub all_tables {
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';
        if (!defined @{"${class}::_all_tables"}) {
            # just call the ref function to generate it
            return @{ $class->all_tables_ref() };
        }
        # then return-copy it directly to avoid extra sub call
        #return @{"${class}::_all_tables"};
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
        #return
            #LIST        {  %{"${class}::relatives"}     }
            #HASHREF     { \%{"${class}::relatives"}     }
            #SCALAR      { \%{"${class}::relatives"}     }
        #;
        return \%{"${class}::relatives"};
    }

    sub baseclass {
        my ($class) = @_;
        if (ref $class) {
            $class = ref $class;
        }
        no strict 'refs';
        if (!defined ${"${class}::_baseclass"}) {
            Readonly ${"${class}::_baseclass"} 
                => $class =~ m{ \A (\w+) :: .* \z }xms;
        }
        #carp __PACKAGE__, qq{->baseclass():\n},
            #qq{class = '$class', baseclass '$baseclass'};
        return ${"${class}::_baseclass"};
    }


}

1; # Magic true value required at end of module
__END__

=head1 NAME

Object::POOF - Persistent Object Oriented Framework (for mod_perl)


=head1 VERSION

This document describes Object::POOF version 0.0.6


=head1 SYNOPSIS

some of this doc may be wrong.  this suite is still highly experimental
and subject to change but i am releasing this version 
because i have a contract starting
and i am always suspicious of corporations trying to lay claim to my work.
- Mark Hedges 2005-09-06

 package MyApp::Foo;
 # a table named 'foo' exists in db with autoinc 'id' field
 use Readonly;
 use base qw(Object::POOF);

 # make sure to make @more_tables and %relatives Readonly in 'our' scope.
 # (outside of the private block used by Class::Std)
 # this makes them accessible through the class without making an object.
 # (but they cannot be changed by anything but you, with a text editor.)
  
 # other tables containing fields to be joined 
 # to 'foo' by 'id' field when fields are requested:
 Readonly our @more_tables => qw( foo_text foo_info foo_html );

 # relationships to other classes:
 Readonly our %relatives => (
     # self to other relationships (one to one):
     s2o => {
         # a table named 'bar' exists in db, and foo.bar_id = bar.id
         bar     => {
             class   => 'MyApp::Bar',
         },
     },

     # self contains many - 
     # each foo has only one rel to each sCm entity
     sCm => {
         # table named 'biz'; foo.id = biz.foo_id
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
             relkey      => 'boz_id',    # a 'boz' will be made here
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

 use Class::Std;
 {
    sub BUILD {
        my ($self, $ident, $arg_ref) = @_;
        $self->set_more_tables( \@more_tables  );
        $self->set_relatives(   \%relatives    );
    }
 }
 1; # end of package definition, unless you add custom object methods.

 ########

 # later in program...

 # a MyApp::DB thread inheriting from Object::POOF::DB
 my $db = MyApp::DB->new();

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
 while (my ($baz_id, $baz) = each $foo->baz) {
    print "adding rel for $baz_id\n";
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

Object::POOF provides a Persistent Object Oriented Framework using
Perl Best Practices (as outlined in the O'Reilly book by that name.)
It also provides a framework for applications running under mod_perl
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
duplicate population of objects with the same id, instead it keeps a
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
to the id fields and small data is a good idea, then call mass-select
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
name fields like 'up_id', 'child_id', etc. that self-refer to
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
