package POOF::App::Web::Menu;

use strict;
use Carp;
require POOF::DB;
require POOF::Funk;
require POOF::Data::Shepherd;


# this is supposed to call Funk's class method for finding Root Funks,
# assign a Shepherd to each Root Funk, and tell each Shepherd to procreate
# each herd.
# list of root funks to assign to shepherds is specified by hand
# in My::App::Web::Menu, which inits as this object.
# this makes development easier with a simple clone.
# then it just updates $menu->{this} when taking actions like printing
# out 

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = { @_ };
   bless $self,$class;
   ($self->init) or return undef;
   return $self;
}

sub init {
   my ($self,$p) = @_;
   return undef unless ($self->{db});
   return undef unless ref $self->{roots};
   foreach (@{$self->{roots}}) {
      my $root_funk = POOF::Funk->new( funk => lc($_), 
                                        db   => $self->{db} );
      my $shep = POOF::Data::Shepherd->new( herds => $root_funk, 
                                             db    => $self->{db} );
      $shep->breed;
      push @{$self->{sheps}}, $shep;
   }
   return 1;
}

1;
