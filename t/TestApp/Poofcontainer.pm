package TestApp::Poofcontainer;
use strict;
use warnings;
use Carp;
use Readonly;
use base qw( Object::POOF );

# other tables containing fields to be joined 
# to 'poofcontainer' table by 'id' field when fields are requested:
Readonly our @more_tables => qw( );
Readonly our %relatives => (
    # self to other relationships (one to one):
    s2o => {
        poofone => {
            class   => 'TestApp::Poofone',
        },
    },

    # self contains many - 
    # each foo has only one rel to each sCm entity
    # sCm entity must s2o back to this one if it should know.
    sCm => {
        poofthing => {
            class   => 'TestApp::Poofthing',
        },
    },

    # self to many - possibly more than one rel to each s2m entity,
    # uniquely enforced by a field of the interim relational table
    #s2m => {
    #},

    # many to many - possibly more than one rel to each m2m entity,
    # with no restrictions (reltable entry can be exactly duplicated)
    #m2m => {
    #},
);

# the following is only used by the test suite and should not
# be included in your application:

sub table_definitions {
    return (
        qq{
            CREATE TABLE poofcontainer (
                id                  SERIAL,
                poofone_id          BIGINT UNSIGNED NOT NULL UNIQUE,  -- 1:1

                FOREIGN KEY (poofone_id) REFERENCES poofone (id)
                    ON DELETE CASCADE
                    ON UPDATE CASCADE
            ) ENGINE=InnoDB
            -- no supplementary table needed for sCm container relationship
        },
    );
}


1;
__END__


