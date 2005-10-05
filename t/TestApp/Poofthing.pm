package TestApp::Poofthing;
use strict;
use warnings;
use Carp;
use Object::POOF::Constants;
use Readonly;
use base qw( Object::POOF );

# other tables containing fields to be joined 
# to 'poofcontainer' table by 'id' field when fields are requested:
#Readonly our @more_tables => qw( );
Readonly our %relatives => (
    # self to other relationships (one to one):
    s2o => {
        poofcontainer => {
            class => 'TestApp::Poofcontainer',
        },
    },

    # now, there are no longer the various types of o2m entity relationships.
    # you should define such constraints with nested unique keys on pk's.
    # O:P will barf an O:P:X exception with the DBI errstr if finds a problem.

    #
    s2m => {
        poofhabitat => {
            class => 'TestApp::Poofhabitat',
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
            CREATE TABLE poofthing (
                name                VARCHAR(32) PRIMARY KEY,
                sound               VARCHAR(56) UNIQUE,  -- but not part of key

                -- a thing is either in its habitat or in a container, 
                -- or neither (orphaned), but never both:

                poofcontainer_id    BIGINT UNSIGNED
                    CHECK   (poofhabitat_name IS NULL),

                poofhabitat_name            VARCHAR(32)
                    CHECK   (poofcontainer_id IS NULL),

                FOREIGN KEY (poofcontainer_id) REFERENCES poofcontainer (id)
                    ON UPDATE CASCADE,  -- things not killed, only orphaned

                FOREIGN KEY (poofhabitat_name)
                    REFERENCES poofhabitat (name)
                    ON UPDATE CASCADE
                    ON DELETE CASCADE  -- destroying habitat kills all things

            ) ENGINE=InnoDB
        },
    );
}

1;
__END__


