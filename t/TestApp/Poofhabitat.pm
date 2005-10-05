package TestApp::Poofhabitat;
use strict;
use warnings;
use Carp;
use Object::POOF::Constants;
use Readonly;
use base qw( Object::POOF );

#if (defined %relatives) {
    #use YAML; croak Dump(%relatives);
#}
# other tables containing fields to be joined 
# to 'poofcontainer' table by 'id' field when fields are requested:
#Readonly our @more_tables => qw( );
Readonly our %relatives => (
    # self to other relationships (one to one):
#   s2o => {
#   },

    # now, there are no longer the various types of o2m entity relationships.
    # you should define such constraints with nested unique keys on pk's.
    # O:P will barf an O:P:X exception with the DBI errstr if finds a problem.

    # in this direction, each habitat contains many things, but not any
    # things that are in containers, and things can only be in either a
    # single habitat or in a container.  (???)
    s2m => {
        poofthing => {
            class => 'TestApp::Poofthing',
        },
    }

    # the 'N to Many' relationships are also self to many.
    # use SQL constraints on your tables to define these differences,
    # then watch for O:P:X exceptions.

);

# the following is only used by the test suite and should not
# be included in your application:

sub table_definitions {
    return (
        qq{
            CREATE TABLE poofhabitat (
                name                VARCHAR(32),
                natural_spirit      VARCHAR(32),

                PRIMARY KEY (name, natural_spirit)
        
            ) ENGINE=InnoDB
        },
    );
}

1;
__END__


