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

#use Class::Std;
#{ 
    #sub BUILD {
        #my ($self, $ident, $arg_ref) = @_;
        #$self->set_more_tables( \@more_tables  );
        #$self->set_relatives(   \%relatives    );
    #}
#}

# the following is only used by the test suite and should not
# be included in your application:

sub table_definitions {
    return (
        qq{
            CREATE TABLE poofthing (
                id                  SERIAL,
                poofcontainer_id    BIGINT UNSIGNED,
        
                FOREIGN KEY (poofcontainer_id) REFERENCES poofcontainer (id)
                    ON UPDATE CASCADE
                    -- but don't do ON DELETE CASCADE or you'll hate yourself
            ) ENGINE=InnoDB
        },
    );
}

1;
__END__


