package Object::POOF::User;

use strict;
use warnings;
use Carp;
use Object::POOF::Data;
our @ISA = qw( Object::POOF );
use Object::POOF;


sub init {
	my ($self,$p) = @_;

	return undef unless ($self->{db});

	if ($self->{uname}) {
		
	}

	$self->id unless (defined $self->{id});  # generate if not passed
	
	return 1;
}



sub fullname {
	my ($self,$p) = @_;
	unless (defined $self->{fullname}) {
		$self->{fullname} = $self->data->{first_name}." ";

		if ($self->{data}->{middle_name}) {
			$self->{fullname} .= $self->{data}->{middle_name}." ";
		}
		
		$self->{fullname} .= $self->{data}->{last_name};

		if ($self->{data}->{suffix}) { 
			$self->{fullname} .= ", ".$self->{data}->{suffix}; 
		}
	}
	return $self->{fullname};
}



sub set_passwd {
	my ($self,$p) = @_;
	return undef unless (defined $p->{passwd});
	my $sql = qq#
		update users set sha=sha($p->{passwd}) where id=#.$self->id.qq#
	#;
	$self->dbh->do($sql);
	return 1;
}


sub auth {
	my ($self,$p) = @_;
	return undef unless (defined $p->{passwd});
	my $sql = qq#
		SELECT (sha(#.$self->dbh->quote($p->{passwd}).qq#) = sha)
		FROM #.$self->table.qq#
		WHERE id = #.$self->id.qq#
	#;
	#warn __PACKAGE__."->auth(): sql is $sql\n";
	my ($auth) = $self->dbh->selectrow_array($sql);
	return $auth;
}


1;
