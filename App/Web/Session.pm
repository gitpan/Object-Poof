package POOF::App::Web::Session;

      # it would be nice if these values didn't have to be hardcoded

use strict;
use warnings;
use Carp;

use Apache::Session ();
use Apache::Session::MySQL;
use Apache::Cookie;

sub new {
   my ($proto) = shift;
   my $class = ref($proto) || $proto;
   my $self = { @_ };

   # must pass ref to Apache->request obj
   return undef unless (defined $self->{r}); 

   bless $self,$class;
   return $self;
}

sub session {
   my ($self,$p) = @_;

   # the session data hash

   unless ($self->{session}) {
   
      my $sess_cookie = undef;
      $sess_cookie = $self->{c}->{SESSION_ID} if (defined $self->{c});
      warn "incoming session_id cookie is '$sess_cookie'\n";
      my $inc_sess_id = undef;
      $inc_sess_id = $sess_cookie->value if (defined $sess_cookie);

      my %session_hash;
      tie %session_hash, 'Apache::Session::MySQL', $inc_sess_id, {
                DataSource => 'dbi:mysql:cfx_sessions', 
                UserName   => 'cfx',            #required when using
                Password   => 'beefnut364',           #MySQL.pm
                LockDataSource => 'dbi:mysql:cfx_sessions',
                LockUserName   => 'cfx',
                LockPassword   => 'beefnut364'
      };

      $self->{session} = \%session_hash;
   
      my $session_id = $self->{session}->{_session_id};
      warn "selected session_id is ".$session_id."\n";

      $sess_cookie = Apache::Cookie->new( $self->{r},
                                    -name    =>   'SESSION_ID',
				    -value   =>   $session_id,
				    -expires =>   '+10M',
				    -domain  =>   'internal.cobaltfx.com',
				    -path    =>   '/cgi-bin/'
				   );
      $sess_cookie->bake;
      warn "sess_cookie is ".$sess_cookie."\n";
   }
   
   # now $self->{session} is a tied hash of session data.
   return $self->{session};
}

#sub global {
   #my ($self,$p) = @_;

   # the easy answer to the locking problem if global is necessary is
   # to create another database.

   # the global data hash
   #
   # caller always undef after every use! -->   undef $self->{global};
   #
   # otherwise other instances cannot access the locked hash....
   # OH, I bet this doesn't work because session locks the session data...
   # I really don't think there's any need to use this.
   #
   # NOTE if this ever gets used, it apparently needs its own database.
   #
   # just in case, we make sure we undef first and release locks.
   #

   #undef $self->{global};
   #$self->{global} = {};

   #my %global_hash;
   #tie %global_hash, 'Apache::Session::MySQL', 1, {
                #DataSource => 'dbi:mysql:ez_sessions', #these arguments are
                #UserName   => 'ez',            #required when using
                #Password   => 'BeZappa929',         #MySQL.pm
                #LockDataSource => 'dbi:mysql:ez_sessions',
                #LockUserName   => 'ez',
                #LockPassword   => 'BeZappa929'
   #};

   #$self->{global} = \%global_hash;

   #return $self->{global};
#}


1;
