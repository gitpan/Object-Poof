package Object::POOF::Funk;

our @ISA = qw( Object::POOF );   # questionable whether this is necessary

use strict;
use Carp;
require Object::POOF::DB;
use Object::POOF::Data;


sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = { @_ };
	$self->{class} = $class;
	bless $self,$class;
	($self->init) or return undef;
	#warn __PACKAGE__."->new(): db is $self->{db}\n";
	return $self;
}



sub init {
	my ($self,$p) = @_;
	$self->{urlpath} = $ENV{SCRIPT_NAME};
	$self->{urlhost} = $ENV{HTTP_HOST};
	return 1;
}

# detainting routines, etc.






1;
