package Object::POOF::SQL;
use strict;
use warnings;

# routines imported by SQL packages

BEGIN {
	use Exporter ();
	our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,%EXPORT_TAGS);
	$VERSION = 1.00;
	@ISA = qw(Exporter);
	@EXPORT = qw( 	
		&where &save
	);
	%EXPORT_TAGS = ( );
	@EXPORT_OK = qw(); 
}
our @EXPORT_OK;

sub where : method {
	my ($self,$p) = @_;
	return undef unless $self->{db};
	map { return undef unless $p->{$_} } qw( obj fld val );

	my ($obj,$fld,$val,$db) = @{$p}{qw( obj fld val )}, $self->{db};
	my $ali = $p->{ali};

	my $tbl = $obj->field_table($fld);
	return undef unless defined $tbl;

	# try to keep track of field aliasing
	if (exists $self->{wheres}->{$tbl}->{$fld}) {
		return undef if (($ali) and (exists $self->{wheres}->{$tbl}->{$fld}->{$ali}));
	} elsif ($ali) {
		$self->{wheres}->{$tbl}->{$fld}->{$ali} = undef;
	} else {
		$self->{wheres}->{$tbl}->{$fld} = {};
	}
	
	my $fi = $db->{tables}->{$tbl}->{info}->{$fld};  # fi = field info
	
	if ($val =~ (/^(<|>|!|like)/) {
	}

}

sub save : method {
	my ($self,$p) = @_;
	return undef unless $self->{db};
}


1;
