package TestApp::DB;
use strict;
use warnings;
use Carp;
use Readonly;

use base qw( Object::POOF::DB );

# config_filename is optional if you use /etc/poof/YourBaseClass/config
Readonly our $config_filename => q{./TestApp.config};

1;
