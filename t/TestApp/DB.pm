package TestApp::DB;
use strict;
use warnings;
use Carp;
use Readonly;

use base qw( Object::POOF::DB );

# config_filename is optional if you use /etc/poof/YourBaseClass/config
Readonly our $CONFIG_FILENAME => q{./TestApp.config};

#Readonly our $RELAXED_FIELD_CHECKING => 1;

1;
