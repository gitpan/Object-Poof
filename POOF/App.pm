=head1 NAME

Object::POOF::App - Perl Object-Oriented Framework - Application Object

=head1 SYNOPSIS

 Package MyApp::App;

 @ISA = qw(Object::POOF::App);
 
 sub init {
    my ($self,$p) = @_;
    
    $self->{sess_table}    = "MyApp_Sessions";
    $self->{sess_dbuname}  = "myapp";
    $self->{sess_dbpasswd} = "dbpassword_string";

    # this calls Object::POOF::App::Web->init()
    # or Object::POOF::App::Term->init() automagically
    # because Object::POOF::App->new calls the right new()
    #
    # well, that's the theory, but Term apps aren't implemented
   
    my $status = $self->SUPER::init;
    if (defined $status) {
       my $croak = __PACKAGE__
                 ."->init(): SUPER::init status: $status\n";
       croak $croak;
    } else {
       return 1;
    }
 }

 sub run {
    my ($self,$p) = @_;
    $self->SUPER::run;
 }

 # ... in main script, current example is just for www app:
 require MyApp::DB;
 require MyApp::App;
 my $db  = MyApp::DB->new;  # inherits from Object::POOF::DB
 my $app = MyApp::App->new( db => $db );
 $app->run;

=head1 DESCRIPTION

Object::POOF::App provides a framework for an object-oriented application.
Future plans include a terminal interface, but right now it only supports
an Apache mod_perl application.  Some libraries are required, like
Apache::Session.

To work, user must define at least one Funk (function) library, MyApp::Funk.
This is the default function.  See Object::POOF::Funk(3).  

=cut

package Object::POOF::App;

our @ISA = qw( Object::POOF ); 

use strict;
use warnings;
use Carp;
#use Object::POOF::Data;

# override general Object::POOF->new().
# that begs the question of why we inherit from Object::POOF at all,
# but in the future it may be nice to get the data routines, etc.
# if we store application default values in the database under an 'app'
# or 'app_info' table and create methods for the admin to change them.

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

	my $self = {};  # reset self hash

	if ($ENV{SERVER_NAME}) {
		# assume this is an Object::POOF::App::Web
		use Object::POOF::App::Web;
		# won't work unless @_ includes DB object,
		# i.e. my $app = MyApp::App->new( db => $db );
		push @ISA, "Object::POOF::App::Web";
		$self = Object::POOF::App::Web->new( @_ );
		return undef unless ($self);
	} else {
		# use a Object::POOF::App::Term interface... unimplemented
		# or Object::POOF::App:Ncurses... or My::App::Ncurses, or something
		return undef;  # just doesn't work at this point
	}

	my $temp;
	($self->{baseclass},$temp) = ($class =~ /^(.*)(::App)$/);
    $self->{class} = $class;
    bless $self,$class;

	my ($pack,$file,$line) = caller;
	#warn __PACKAGE__." caller package  = $pack\n";
	#warn __PACKAGE__." caller filename = $file\n";
	#warn __PACKAGE__." caller line     = $line\n";

    ($self->init) or return undef;  # this is the MyApp setup

	# this is ::Web->app_init etc.:
	# it works opposite, because in case of ::Web, returns apache error code
	($self->app_init) and return undef;	
	return $self;
}

1;

=head1 SEE ALSO

Object::POOF(3),
Object::POOF::Funk(3),
Object::POOF::App::Web(3),

=head1 AUTHOR

Copyright 2005 Mark Hedges E<lt>hedges@ucsd.eduE<gt>, CPAN: MARKLE

Released under the standard Perl license (GPL/Artistic).

=cut

