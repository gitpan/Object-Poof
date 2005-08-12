package Object::POOF::Data;
use strict;
use warnings;

BEGIN {
	use Exporter ();
	our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,%EXPORT_TAGS);
	$VERSION = 1.00;
	@ISA = qw(Exporter);
	@EXPORT = qw( 	
		&dbh 
		&id &save &load
		&base &table &table_info
	);
	%EXPORT_TAGS = ( );
	@EXPORT_OK = qw(); 
}
our @EXPORT_OK;

# these are data routines that are inherited by other objects.
# they deal with the object's main table, which must be named the
# lowercase version of the class name, i.e. if class Foo::Bar::Baz,
# the tables in the db must be 'baz' and 'baz_info'.

sub save : locked method {
	my $self = shift;
	my $tmi = $self->{db}->{tables}->{ $self->table };
	my $tii = undef;
	if ($self->table_info) {
		$tii = $self->{db}->{tables}->{ $self->{table_info} };
	}
	while (my ($fld,$val) = each %{$self->{save}}) {
	}
}

sub field_table : method {
	my ($self,$fld) = @_;
	return undef unless (($fld) and (defined $self->{db}));
	return $self->{table} if (exists $self->{db}->{tables}->{ $self->table }->{info}->{$fld});
	if	(	($self->table_info) 
		and	(exists $self->{db}->{tables}->{ $self->{table_info} }->{info}->{$fld})
		) {
		return $self->{table_info} 
	} else {
		return undef;
	}
}

sub dbh : locked method {
	# for ease of use, returns object's POOF::DB->dbh thread
	# now caller app must initialize DB object(s) and pass around threads
	my $self = shift;
	return undef unless (defined $self->{db});
	return $self->{db}->dbh;
}

sub load : method {
	my ($self,$aref) = shift;
	return undef unless ((defined $self->{db}) and ($self->{id}));
	my ($tmf,$tif) = (undef,undef);  # tmf = table main fields, tif = table info fields
	if (not ref $aref and $aref eq 'all') {
		$tmf = [ grep(!/^id$/, $self->{db}->{tables}->{ $self->table }->{fields}) ];
		$tif =	($self->table_info)
			?	[ grep(!/^id$/, $self->{db}->{tables}->{ $self->{table_info} }->{fields}) ]
			:	[ ];
	} else {
		return undef unless ref $aref eq 'ARRAY';
		$tmf = []; 
		$tif = [];
		for my $fld (@$aref) {
			next if (/^id$/);
			if ($self->field_table($fld) eq $self->table) {
				push @$tmf, $fld;
			} 
			elsif (	($self->table_info)
				and	($self->field_table($fld) eq $self->table_info)
				) {
				push @$tif, $fld;
			}
		}
	}
	return undef unless ((@$tmf) or (@$tif));
	my $sql = qq(
		SELECT
	)
	.	join(" ,\n", map { "$self->{table}.$_" } @$tmf);

	$sql .= " ,\n".join(" ,\n", map { "$self->{table_info}.$_" } @$tif) if (@$tif);

	$sql .= qq(
		FROM $self->{table}
	);
	$sql .= qq(
		, $self->{table_info}
	) if ($self->{table_info});

	$sql .= qq(
		WHERE id = $self->{id}
	);

	my $data = $self->dbh->selectrow_hashref($sql);

	#@{$self}{keys %$data} = @{$self->{data}}{keys %$data} = values %$data;
	# maybe i don't really need the {data} hash at all, let's see.
	@{$self}{keys %$data} = values %$data;
}

sub id : locked method {
	my $self = shift;
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
		unless ($self->{table}) {
			($class = shift || ref $param) =~ /^\w+::(.*)$/;
			(my $table = lc($1)) =~ s/:/_/g;
			$self->{table} = $table;
		}
		return $self->{table};

	} else {
		($class = $param) =~ /^\w+::(.*)$/;
		(my $table = lc($1)) =~ s/:/_/g;
		return $table;
	}
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
		unless (exists $self->{table_info}) {
			($class = shift || ref $param) =~ /^\w+::(.*)$/;
			(my $table_info = lc($1).'_info') =~ s/:/_/g;
			if (exists $self->{db}->{tables}->{$table_info}) {
				$self->{table_info} = $table_info;
			} else {
				$self->{table_info} = undef;
			}
		}
		return $self->{table_info};
	} else {
		# for class method, we just don't know if it exists
		# because method has no access to DB object, so 
		# caller is responsible for figuring that out, unless
		# you pass a reference to the db!
		($class = $param) =~ /^\w+::(.*)$/;
		(my $table_info = lc($1).'_info') =~ s/:/_/g;
		if (my $db = shift) {
			$table_info = undef unless exists $db->{tables}->{$table_info};
		}
		return $table_info;
	}
}

sub base : method {
	my $self = shift;
	$self->{class} =~ /^(\w+)::/;
	return $1;
}


1;

