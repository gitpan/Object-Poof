package TT::Construct1;

use strict;

sub new {
   my ($proto,$p) = @_;
   my $class = ref($proto) || $proto;
   my $self = {};
   bless $self,$class;
   return undef unless (defined $p->{test});
   $self->{test} = $p->{test};
   return $self;
}

1;
