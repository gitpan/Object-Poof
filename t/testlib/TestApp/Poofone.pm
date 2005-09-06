package TestApp::Poofone;
use strict;
use warnings;
use Carp;
#use Object::POOF::Constants;
use Readonly;
use base qw( Object::POOF );

# other tables containing fields to be joined 
# to 'poofcontainer' table by 'id' field when fields are requested:
Readonly our @more_tables => qw( poofone_text poofone_other );
Readonly our %relatives => (
    # self to other relationships (one to one):
    #s2o => {
    #},

    # self contains many - 
    # each foo has only one rel to each sCm entity
    # sCm entity must s2o back to this one if it should know.
    #sCm => {
    #},

    # self to many - possibly more than one rel to each s2m entity,
    # uniquely enforced by a field of the interim relational table
    #s2m => {
    #},

    # many to many - possibly more than one rel to each m2m entity,
    # with no restrictions (reltable entry can be exactly duplicated)
    #m2m => {
    #},
);

use Class::Std;
{ 
    sub BUILD {
        my ($self, $ident, $arg_ref) = @_;
        #$self->set_more_tables( \@more_tables  );
        #$self->set_relatives(   \%relatives    );
    }
}

# the following is only used by the test suite and should not
# be included in your application:

sub table_definitions {
    return (
        q{
            CREATE TABLE poofone (
                id                  SERIAL
            ) ENGINE=InnoDB
        },

        q{
            CREATE TABLE poofone_text (
                id                  BIGINT UNSIGNED NOT NULL UNIQUE,
        
                char_one            CHAR(8)         CHARSET UTF8,
                char_two            CHAR(255)       CHARSET UTF8,
                vchar_one           VARCHAR(8)      CHARSET UTF8,
                vchar_two           VARCHAR(255)    CHARSET UTF8,
                text_one            TINYTEXT        CHARSET UTF8,
                text_two            TEXT            CHARSET UTF8,
                
                FOREIGN KEY (id) REFERENCES poofone (id)
                    ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB
        },

        q{
            CREATE TABLE poofone_other (
                id                  BIGINT UNSIGNED NOT NULL UNIQUE,
        
                enumerated          ENUM('one','two','three'),
                set_field           SET('uno','dos','tres'),
        
                byte                BINARY(8),
                vbin                VARBINARY(64),
        
                dt_tm               DATETIME,
                dt                  DATE,
                tstamp              TIMESTAMP,
                tm                  TIME,
                yr                  YEAR,

                flt                 FLOAT(30,8),
                dbl                 DOUBLE(35,12),
                dcml                DECIMAL(12,4),
                intgr               INT(8),

                zipcode             INT(5) ZEROFILL,
                
                FOREIGN KEY (id) REFERENCES poofone (id)
                    ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB
        },
    );
}

1;
__END__


