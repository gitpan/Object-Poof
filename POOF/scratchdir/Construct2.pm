package TT::Construct2;

use strict;

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = { @_ };
   bless $self,$class;
   return undef unless (defined $self->{test});
   return $self;
}

1;
