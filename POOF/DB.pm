package Object::POOF::DB;

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

use strict;
use warnings;
use Carp;

our @ISA = qw(Object::POOF);

use DBI;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = { @_ };
	$self->{class} = $class;
	bless $self,$class;
	($self->init) or return undef;
	return $self;
}


sub init {
	# this SUPER::init must be called AFTER the inheriting object
	# sets up values for self->{dsn},{dbuname},{dbpass}
	my $self = shift;
	$self->db_connect;

	#my @lame = $self->dbh->selectall_arrayref("show tables");
	#foreach (@lame) {
	   #warn "+++ LAME ++++ ".$_->[0]->[0]."\n";
	#}

	#@{$self->{table_list}} = map { $_->[0]->[0] } 
							#$self->dbh->selectall_arrayref("show tables");
	my $result = $self->dbh->selectall_arrayref("show tables");
	my @list = ();
	foreach (@$result) {
		push @list, $_->[0];
	}
	#warn "tables list is @list\n";
	$self->{table_list} = \@list;
	foreach (@{$self->{table_list}}) {
		#warn __PACKAGE__."->init() should be calling fields for $_...\n";
		$self->fields($_);
		#warn "... now self->{tables}->{$_} is ".$self->{tables}->{$_}."\n";
		#while (my ($k,$v) = each %{$self->{tables}->{$_}}) {
			#warn "***\t\t$k\t=\t$v\n";
			#while (my ($l,$w) = each %{$self->{tables}->{$_}->{$k}}) {
				#warn "\t\t\t\t$l\t=\t$w\n";
			#}
		#}
	}
	return 1;
}


sub destroy {
	my $self = shift;
	if ($self->{debug}) { warn __PACKAGE__."->destroy\n"; }
	$self->db_disconnect or warn __PACKAGE__."->destroy could not disconnect.\n";
	$self->{dbh} = undef;
	return;
}

sub dbh {
	my $self = shift;
	$self->db_connect unless ($self->{dbh});
	return $self->{dbh};
}

sub db_connect {
	my $self = shift;

	#warn qq#
		#dsn	  => $self->{dsn}
		#dbuname => $self->{dbuname}
		#dbpass  => $self->{dbpass}
	##;

	$self->{dbh} = DBI->connect(	$self->{dsn},
									$self->{dbuname},
									$self->{dbpass},
									{	PrintError => 1,
										RaiseError => 1, 
										AutoCommit => 0 
									}
								)
		or warn __PACKAGE__."->db_connect\n	No db: ".DBI::errstr."\n";
}

sub db_disconnect {
	my $self = shift;

	# commit or rollback should be called explicitly before destroy/disconnect

	my $rc = $self->dbh->disconnect 
		or warn "No db disconnect:".DBI::errstr."\n";;

	$self->{dbh} = '';
	return $rc;
}

sub commit {
	my $self = shift;
	my $rc = $self->dbh->commit;	# do any checks here?

	return $rc;
} 

sub rollback {
	# cancels all queries so far
	my $self = shift;
	$self->dbh->rollback;
	return ($self->{dbh}->errstr) ? $self->dbh->errstr : '';
}


sub rolldie {
	my $self = shift;
	my $errmsg = shift;
	$self->dbh->rollback;
	my $errstr = $self->dbh->errstr if ($self->dbh->errstr);
	$self->destroy;
	die "$errmsg: $errstr\n";
}



# typeglobs won't work right under mod_perl custom handler,
# neither will AutoLoader since it requires __END__ token,
# so have to use a parameter-based subroutine, hope it works.

sub fields {
	my ($self,$table) = @_;
	return undef unless ($table);
	return undef unless (grep(/$table/,@{$self->{table_list}}));

	#unless (defined $self->{tables}->{$table}) {
		my $sth = $self->dbh->prepare("show columns from $table");
		my $rv  = $sth->execute;
		#warn __PACKAGE__."->fields($table)...\n";
		while (my $hr = $sth->fetchrow_hashref) {
			my $field 	= $hr->{Field};
			my $type	= $hr->{Type};
			$self->{tables}->{$table}->{$field} = {};
			my $limit = '';
			if ($type =~ /^(\w.*)\((\d+)\)$/) {
				$type = $1;
				$limit = $2;
			}
			$self->{tables}->{$table}->{$field}->{type}		= $type;
			$self->{tables}->{$table}->{$field}->{limit}	= $limit;
			my $descript = $field;
			$descript =~ s/_/ /g;
			$descript = ucfirst($descript);  
			$self->{tables}->{$table}->{$field}->{descript} = $descript;
	
			# also set a flag that tells the object's save routine
			# whether or not to quote the value.  the object's save
			# routine must double-check whether the value matches characters
			# because enum types are not included in this check, since
			# they can be inputted as either strings or enumeration index vals
			if ($type =~ /[date|time|year]/i) {
				$self->{tables}->{$table}->{$field}->{type_datetime} = 1;
			}
			if ($type =~ /[char|text|blob]/i) {
				$self->{tables}->{$table}->{$field}->{type_string} = 1;
			}
		}
	#}
	return $self->{tables}->{$table};
}



sub olddynfields {
	# DEPRECATED
	# since this doesn't work under mod_perl custom handler
	# dynamic subs w/ typeglob weren't working under mod_perl handler.
	# so, now set up DB-inheriting object with 'preload_descriptions => 1'
	# or call $db->fields->fields({ table => $table }) to describe table.
	# the latter will be the preferential method.
	# Data.pm should have a fields routine that calls this one with
	# the table name.  So callers just call $obj->fields, which returns
	# $obj->{db}->fields->{$obj->{table}}
	# and $obj->fields_info returns $obj->{db}->fields->{$obj->{table_info}}
	my $self = shift;
	unless ($self->{fields}) {
	  require Object::POOF::DB::Fields;
		$self->{fields} = Object::POOF::DB::Fields->new( db => $self );
	}
	return $self->{fields};
}

1;

=head1 SEE ALSO

Object::POOF(3)
Object::POOF::App(3)

=head1 AUTHOR

Copyright 2005 Mark Hedges E<lt>hedges@ucsd.eduE<gt>, CPAN: MARKLE

=head1 LICENSE

Released under the standard Perl license (GPL/Artistic).

=cut
