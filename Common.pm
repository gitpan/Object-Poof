package TT::Common;

use strict;
use warnings;

BEGIN {
   use Exporter ();
   our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,%EXPORT_TAGS);
   $VERSION = 1.00;
   @ISA = qw(Exporter);
   @EXPORT = qw( &sendmail );
   %EXPORT_TAGS = ( );
   @EXPORT_OK = qw(); 
}
our @EXPORT_OK;



# these are common routines used by both objects and script processor libs.
# they should require no parameters set in the caller.

sub sendmail {
   my ($self,$p) = @_;
   my $ent = $p->{ent}; # a MIME::Entity
   return undef unless (defined $ent);
   require Mail::Send;
   my $sender = new Mail::Send;
   foreach ($ent->head->tags) {       # give the sender our headers
      $sender->set($_, map {chomp $_; $_} $ent->head->get($_));
   }
   my $fh = $sender->open('sendmail');
   $ent->print_body($fh);
   $fh->close;
   return 1;
}








END { }


1;
