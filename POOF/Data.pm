package Object::POOF::Data;
use Carp;
use strict;
use warnings;

BEGIN {
	use Exporter ();
	our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,%EXPORT_TAGS);
	$VERSION = 1.00;
	@ISA = qw(Exporter);
	@EXPORT = qw( 	&save &dbh &data &data_info 
					&id &find1to1 &table &table_info
					&getOne &getOneClass
				);
	%EXPORT_TAGS = ( );
	@EXPORT_OK = qw(); 
}
our @EXPORT_OK;

sub getOneClass {
	# the class-method version of getOne... or you can fake 'self' yourself
	return Object::POOF::Data::getOne("bonk", @_); # tricksy
}
sub getOne {
	my ($self,$p) = @_;
	#warn __PACKAGE__."->getOne start... p is:\n";
	#while (my ($k,$v) = each %$p) {
		#warn "\t$k\t$v\n";
	#}
	return undef unless (($p->{class}) && ($p->{where}));
	#warn __PACKAGE__."->getOne okay...\n";
	my $db = ($p->{db}) ? $p->{db} : ($self->{db}) ? $self->{db} : undef;
	return undef unless ($db);
	#warn __PACKAGE__."->getOne moving on...\n";
	# easiest to create a temporary shepherd i guess... sheesh
	require Object::POOF::Data::Shepherd;
	my $shep = Object::POOF::Data::Shepherd->new( 	db 		=> $db,
													herds 	=> $p->{class} );
	#warn __PACKAGE__."->getOne: shep is $shep\n";
	#warn __PACKAGE__."->getOne: where is $p->{where}\n";
	#while (my ($k,$v) = each %{$p->{where}}) {
		#warn "$k\t=\t$v\n";
	#}
	return $shep->callOne({ where => $p->{where} });
}


# these are data routines that are inherited by other objects.
# they deal with the object's main table, which must be named the
# lowercase version of the class name, i.e. if class Foo::Bar::Baz,
# the tables in the db must be 'baz' and 'baz_info'.

sub save {
	# data saving.  
	#	 $msg->{save}->{subject} = $subject;
	#	 $msg->{save}->{from_email} = $from_email;
	#	 $msg->save;
	#	 $msg->commit;
	my ($self,$p) = @_;

	foreach (qw(save save_info)) {
		next unless (defined $self->{$_}); # data to save
		my $table = (/info/) ? $self->table : $self->table_info;
		next unless ($table); # somewhere to save it
		
		my $sql = qq#
			update $table set
		#;
		foreach my $field (keys %{$self->{$_}}) {
	
			my $field_desc = $self->{db}->{tables}->{$table}->{$field};
			next unless ($field_desc); # field doesn't exist in table

			if ($field_desc->{type_datetime}) {
				# if the field is a date or time type, any value means to
				# set the field to now()
	 			$sql .= " $field = now(), " if ($self->{save}->{$field});
			}
			elsif ($field_desc->{type_string}) {
				# quote the string value
	 			$sql .= " $field = "
						.$self->dbh->quote($self->{save}->{$field})
						.", ";
			}
			# else it is numeric... check?
		}
		#chop the last comma... maybe there is a way to wrap the above in map?
		$sql =~ s/,\s*$/ /;
		$sql .= qq# where id = #.$self->id;
		$self->dbh->do($sql);
	}

	return 1;  # assuming it went okay?
}


sub dbh {
	# for ease of use, returns object's POOF::DB->dbh thread
	# now caller app must initialize DB object(s) and pass around threads
	my ($self,$p) = @_;
	return undef unless (defined $self->{db});
	unless (defined $self->{dbh}) {
		$self->{dbh} = $self->{db}->dbh;
	}
	return $self->{dbh};
}


sub data {
	# data retrieval.  refer to table contents like 
	# self->data->{user_id}	 ... to select first time or reload
	# self->{data}->{user_id}  ... to use cached data
	my ($self,$p) = @_;
	$self->{data} = {};
	my $sql = qq# select * from #.$self->table.qq# where id = #.$self->id;
	$self->{data} = $self->dbh->selectrow_hashref($sql);
	return $self->{data};
}

sub data_info {
	# like data(), only used if object has supplementary obj_info field
	my ($self,$p) = @_;

	return undef unless (defined $self->table_info);
	$self->{data_info} = {};
	my $sql = qq# 
		select * 
		from #.$self->table_info.qq# 
		where id = #.$self->id.qq#
	#;

	$self->{data_info} = $self->dbh->selectrow_hashref($sql);
	return $self->{data_info};

}


sub id {
	my ($self,$p) = @_;
	unless (defined $self->{id}) {
		my $sql = qq#
			insert into #.$self->table.qq# (id) values (0)
		#;
		#warn $sql;
		$self->dbh->do($sql);
		$sql = qq#
			select last_insert_id()
		#;
		my ($id) = $self->dbh->selectrow_array($sql);
		warn __PACKAGE__."->id() didn't get an autoinc id back from insert.\n"
			unless defined ($id);

		$self->{id} = $id;

		my $table_info = $self->table_info;
		if (defined $table_info) {
			$self->dbh->do(qq#
				insert into $table_info (id) values ($id)
			#);
			# and verify?
		}
	}
	return $self->{id};
}


sub table {
	# can be called as instance or Data:: class method (passing class)... wacky
	my $param = shift;
	#warn __PACKAGE__."->table(): param is $param\n";
	my $self;
	my $class;
	if (ref $param) {
		$self = $param;
		$class = shift || ref $param;
	} else {
		$class = $param;
	}
	my @split = split /::/, $class;
	return lc(pop @split);
}

sub table_info {
	# can be called as instance or Data:: class method (passing class)... wacky
	my $param = shift;
	#warn __PACKAGE__."->table(): param is $param\n";
	my $self = {};
	my $class;
	if (ref $param) {
		$self = $param;
		$class = shift || ref $param;
	} else {
		$class = $param;
	}
	my @split = split /::/, $class;
	my $table_info = lc(pop @split)."_info";
	return undef 			# for class method, we just don't know if it exists
		if (($self->{db}) 	# because method has no access to DB object
		and not (grep /^$table_info$/, @{$self->{db}->{tables_list}}));
	return $table_info;
}



# findOneToOne, FindOneToMany, etc. should be in Data::Shepherd.
# up, down, left, right, they are all things Shepherd should do.


#---------------------------------------------------------------------




1;
