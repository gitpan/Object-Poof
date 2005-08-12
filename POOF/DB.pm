package Object::POOF::DB;
use strict;
use warnings;

use DBI;

my $d = 0;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = { @_ };
	$self->{class} = $class;
	bless $self,$class;
	($self->init) or return undef;
	return $self;
}

sub clone {
	my $self = shift;
	return $self->new(
		dbhost		=> $self->{dbhost},
		dbname		=> $self->{dbname},
		dbuname		=> $self->{dbuname},
		dbpass		=> $self->{dbpass},
		pooftypes	=> $self->{pooftypes},
		tables		=> $self->{tables},
	);
}

sub init {
	my $self = shift;

	$self->db_connect;

	map { $self->{tables}->{$_->[0]} = undef; } 
		@{$self->dbh->selectall_arrayref("show tables")}
		unless defined $self->{tables};

	# use exists value in caller to see if table exists.
	# if (exists $db->{tables}->{$tbl}) { ...

	$self->{pooftypes} = {
		varchar		=> 'str',	char		=> 'str',	text		=> 'str',
		tinytext	=> 'str',	mediumtext	=> 'str',	longtext	=> 'str',
		enum		=> 'str',	set			=> 'str', 

		float		=> 'num',	double		=> 'num',	decimal		=> 'num',
		tinyint		=> 'num',	smallint	=> 'num',	mediumint	=> 'num',
		'int'		=> 'num',	bigint		=> 'num', 

		datetime	=> 'dt',	timestamp	=> 'dt',	date		=> 'dt',
		'time'		=> 'dt',	year		=> 'dt',

		binary		=> 'bin',	varbinary	=> 'bin',	tinyblob	=> 'bin',
		blob		=> 'bin',	mediumblob	=> 'bin',	bigblob		=> 'bin',
	} unless defined $self->{pooftypes};

	return 1;
}


sub DESTROY {
	my $self = shift;
	warn __PACKAGE__."->DESTROY\n" if ($d);
	$self->finish;
	$self->rollback;
	$self->unlock;
	$self->db_disconnect or warn __PACKAGE__."->destroy could not disconnect.\n";
	$self->{dbh} = undef;
	return;
}

sub unlock {
	my $self = shift;
	if	(	(defined $self->{locks})
		and	(@{$self->{locks}}) 
		) {
		$self->dbh->do("UNLOCK TABLES");
	}
	return $self;
}

sub finish {
	my $self = shift;
	if (exists $self->{sth}) {
		$self->{sth}->finish if (defined $self->{sth});
		$self->{sth} = undef;
		delete $self->{sth};
	}
	return $self;
}

sub dbh {
	my $self = shift;
	$self->db_connect unless ($self->ping);
	return $self->{dbh};
}

sub ping {
	my $self = shift;
	return undef unless defined $self->{dbh};
	return $self->{dbh}->ping();
}

sub db_connect {
	my $self = shift;

	return $self if ($self->ping);

	#warn qq(
		#dbhost  => $self->{dbhost}
		#dbname  => $self->{dbname}
		#dbuname => $self->{dbuname}
		#dbpass  => $self->{dbpass}
	#\n) if ($d);

	$self->{dbh} = DBI->connect(
		'dbi:mysql:dbname='.$self->{dbname}.';host='.$self->{dbhost},
		$self->{dbuname},
		$self->{dbpass},
		{	
			PrintError => 1,
			RaiseError => 1, 
			AutoCommit => 0 
		}
	) or do {
		$@ = DBI::errstr;
		warn __PACKAGE__."->db_connect\n\tNo db:\n\t$@\n---\n";
	};

	return $self;
}

sub db_disconnect {
	my $self = shift;

	# commit or rollback should be called explicitly before destroy/disconnect

	$self->finish();

	my $rc = $self->dbh->disconnect 
		or warn "No db disconnect:".DBI::errstr."\n";

	$self->{dbh} = undef;
	delete $self->{dbh};
	return $rc;
}

sub commit {
	my $self = shift;
	if (defined $self->{dbh}) {
		my $rc = $self->{dbh}->commit or $@ = $self->{dbh}->errstr;	
		return $rc;
	} else {
		$@ = __PACKAGE__."->commit(): no dbh.\n";
		return undef;
	}
} 

sub rollback {
	# cancels all queries so far
	my $self = shift;
	if (defined $self->{dbh}) {
		my $rc = $self->{dbh}->commit or $@ = $self->{dbh}->errstr;	
		return $rc;
	} else {
		$@ = __PACKAGE__."->commit(): no dbh.\n";
		return undef;
	}
}


sub table {
	my ($self,$tbl) = @_;

	my $d = 0;

	# don't want use as hash key to bomb, so it returns an empty {} if not there:
	return {} unless exists $self->{tables}->{$tbl}; 

	unless (defined $self->{tables}->{$tbl}) {
		$self->finish;
		$self->{sth} = $self->dbh->prepare("describe $tbl");
		$self->{sth}->execute;
		while (my $info = $self->{sth}->fetchrow_hashref) {

			my $fld = $info->{Field};

			push @{$self->{tables}->{$tbl}->{fields}}, $fld;

			$self->{tables}->{$tbl}->{info}->{$fld} = $info;

			$info->{Type} =~ /^(\w+)\(?(.*?)\)?\s?(\w+)?$/;
			warn "parsing Type '$info->{Type}' for fld '$fld'\n" if ($d);
			my ($type,$lim,$unsigned) = ($1,$2,$3);
			warn "type '$type', lim '$lim'\n" if ($d);
			
			@{$self->{tables}->{$tbl}->{info}->{$fld}}{'type','unsigned'} 
				= ($type,$unsigned);
			warn "type is '$type'\n" if ($d);
			my $pooftype 
				= $self->{tables}->{$tbl}->{info}->{$fld}->{pooftype} 
				= $self->{pooftypes}->{$type};

			if	(	($type eq 'decimal')
				and	(defined $lim) 
				and ($lim =~ /^(\d+),(\d+)$/)
				) {
				@{$self->{tables}->{$tbl}->{info}->{$fld}}{'digits','decimals'} = ($1,$2);

			} elsif	
				(	(($type eq 'float') or ($type eq 'double')) 
				and (defined $lim) 
				and ($lim =~ /^(\d+),(\d+)$/)
				) {
				@{$self->{tables}->{$tbl}->{info}->{$fld}}{'width','decimals'} = ($1,$2);

			} elsif 
				(	(($type eq 'enum') or ($type eq 'set')) 
				and	(defined $lim) 
				) {
				#warn "lim before is '$lim'\n" if ($d);
				$lim =~ s/'//g;
				#warn "lim after is '$lim'\n" if ($d);
				$self->{tables}->{$tbl}->{info}->{$fld}->{options} = [ split /,/, $lim ];
			} 
			if ((defined $lim) and ($lim =~ /^\d+$/)) {
				$self->{tables}->{$tbl}->{info}->{$fld}->{limit} = $lim;
			}
				
		}
		$self->finish;
		if ($d) {
			warn "field order for tbl $tbl is now: \n";
			warn join(',', @{$self->{tables}->{$tbl}->{fields}})."\n";
		}
	}
	return $self->{tables}->{$tbl};
}


1;

=head1 NAME

Object::POOF::DB - database transaction thread object for POOF:
Perl Object Oriented Framework.

=head1 DESCRIPTION

Your object that inherits this one is a database connection and
transaction thread.  You can share it among POOF objects by passing it
into their constructors as 'db' (Shepherd usually does this.)
Create a new one and pass it around as an independent transaction thread.

You create a DB object in your namespace as the following:

 package Sample::DB;

 require Object::POOF::DB;
 @ISA = qw(Object::POOF::DB);

 sub init {
     my ($self,$p)    = @_;
     $self->{dbname}  = "database_name";
     $self->{dbhost}  = "database_host";
     $self->{dbuname} = "database_uname";
     $self->{dbpass}  = "database_passwd";
     
     # right now we only work with mysql
     $self->{dsn} = "dbi:mysql:dbname=".$self->{dbname}
                    .";host=".$self->{dbhost};
     
     # always call the SUPER::init
     $self->SUPER::init or return undef;
     return 1;
 }

 1;

Always call the SUPER::init function from most init functions in POOF.
Note that you don't need a constructor in your object.  The POOF::DB
constructor is inherited.

=cut
=head1 SEE ALSO

Object::POOF(3)
Object::POOF::App(3)

=head1 AUTHOR

Copyright 2005 Mark Hedges E<lt>hedges@ucsd.eduE<gt>, CPAN: MARKLE

=head1 LICENSE

Released under the standard Perl license (GPL/Artistic).

=cut
