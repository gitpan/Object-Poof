#!/usr/bin/perl

package Object::POOF::DB::Fields;
use Object::POOF::Data qw( dbh );

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = { @_ };
	$self->{class} = $class;
	bless ($self, $class) or warn "Could not bless $self, $class\n";

	return undef unless (defined $self->{db});
	$self->init;

	return $self;
}


sub fields {
	my ($self,$p) = @_;
	return undef unless ($p->{table});
	return undef unless (grep(/^$p->{table}$/, @{$self->{tables}}));
	my $table = $p->{table};
	unless (defined $self->{$table}) {
		my $sth = $self->dbh->prepare("show columns from $table");
		my $rv  = $sth->execute;
		while (my $hr = $sth->fetchrow_hashref) {
			my $field 	= $hr->{Field};
			my $type	= $hr->{Type};
			$self->{$table}->{$field} = {};
			my $limit = '';
			if ($type =~ /^(\w.*)\((\d+)\)$/) {
				$type = $1;
				$limit = $2;
			}
			$self->{$table}->{$field}->{type}	= $type;
			$self->{$table}->{$field}->{limit}	= $limit;
			my $descript = $field;
			$descript =~ s/_/ /g;
			$descript = ucfirst($descript);  
			$self->{$table}->{$field}->{descript} = $descript;

			# also set a flag that tells the object's save routine
			# whether or not to quote the value.  the object's save
			# routine must double-check whether the value matches characters
			# because enum types are not included in this check, since
			# they can be inputted as either strings or enumeration index vals
			if ($type =~ /[date|time|year]/i) {
				$self->{$table}->{$field}->{type_datetime} = 1;
			}
			if ($type =~ /[char|text|blob]/i) {
				$self->{$table}->{$field}->{type_string} = 1;
			}
		}
	}
	return $self->{$table};
}

sub init {
	my $self = shift;
	@{$self->{tables}} = map { $_->[0] } 
							$self->dbh->selectall_arrayref("show tables");
	if ($self->{db}->{preload_descriptions}) {
		foreach (@{$self->{tables}}) {
			$self->fields({ table => $_ });
		}
	}
	return 1;
}

sub oldinit {
	my ($self,$p) = @_;
	# generate subroutines dynamically to access column data of each table 
	# also builds some little structures for quick "table exists" checking,
	# since calling the sub will bomb for a table that doesn't exist
	my $sql = qq#
		show tables
	#;
	my $table;
	my $sth = $self->dbh->prepare($sql);
	my $rv = $sth->execute;

	# this doesn't actually work under mod_perl running as a custom handler,
	# something about typeglobs getting screwed up.  so in that case,
	# you have to use the 'fields' routine and pass 'table' as a param.
	# this will probably become the default.
	no strict 'refs';
	while (($table) = $sth->fetchrow_array) {
		push @{$self->{tables_list}}, $table;
		$self->{$table}->{table_fields}->{$field} = 1;
		warn __PACKAGE__."->init(): table = $table\n";
		*$table = *{uc $table} = sub {
			my ($self,$p) = @_;
			warn __PACKAGE__."->?? self is $self, p is $p, self->table is $self->{table}\n";
			unless (defined $self->{$table}) {
				my $sql = qq#
					show columns from $table
				#;
				$sth = $self->dbh->prepare($sql);
				$rv = $sth->execute;
				while ($hr = $sth->fetchrow_hashref) {
					my $field = $hr->{Field};
					$self->{$table}->{$field} = {};
					my $type = $hr->{Type};
					my $limit = '';
					if ($type =~ /^(\w.*)\((\d+)\)$/) {
						$type = $1;
						$limit = $2;
					}
					$self->{$table}->{$field}->{type}  = $type;
					$self->{$table}->{$field}->{limit} = $limit;
					my $descript = $field;
					$descript =~ s/_/ /g;
					$descript = ucfirst($descript); # override manually if needed
					$self->{$table}->{$field}->{descript} = $descript;
		
					# also set a flag that tells the object's save routine
					# whether or not to quote the value.  the object's save
					# routine must double-check whether the value matches characters
					# because enum types are not included in this check, since
					# they can be inputted as either strings or enumeration index vals
					if ($type =~ /[date|time|year]/i) {
						$self->{$table}->{$field}->{type_datetime} = 1;
					}
					if ($type =~ /[char|text|blob]/i) {
						$self->{$table}->{$field}->{type_string} = 1;
					}
				}
			}
			return $self->{$table};
		};
	}
	use strict 'refs';

}






1;
