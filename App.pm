package POOF::App;

use strict;
use warnings;
use Carp;

require POOF::DB;

# My::App constructor would be like:
#
# new {
#    my ($proto) = shift;
#    my $class = ref($proto) || $proto;

sub new {
   my ($proto) = shift;
   my $class = ref($proto) || $proto;
   my $self;

   if ($ENV{SERVER_NAME}) {
      # assume this is a POOF::App::Web
      use POOF::App::Web;
      # won't work unless @_ includes db => POOF::DB,
      # so main cgi script should init db with dsn,dbuname,dbpass
      $self = POOF::App::Web->new( @_ );
      return undef unless ($self);
   } else {
      # use a POOF::App::Term interface... unimplemented
      # or POOF::App:Ncurses... or My::App::Ncurses, or something
      return undef;  # just doesn't work at this point
   }
   bless $self,$class;
   return $self;
}

1;
