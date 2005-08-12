package Object::POOF::Class;
use strict;
use warnings;

# these are class methods

BEGIN {
	use Exporter ();
	our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,%EXPORT_TAGS);
	$VERSION = 1.00;
	@ISA = qw(Exporter);
	@EXPORT = qw( 	
		&rel 
		$rel
	);
	%EXPORT_TAGS = ( );
	@EXPORT_OK = qw(); 
}
our @EXPORT_OK;

our $rel = undef;

sub rel () {
	return $rel;
}


1;

