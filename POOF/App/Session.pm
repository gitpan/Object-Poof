package Object::POOF::App::Session;

use strict;
use warnings;

require Apache::Cookie;

sub new {
	my ($proto) = shift;
	my $class = ref($proto) || $proto;
	my $self = { @_ };

	$self->init or return undef;

	bless $self,$class;
	return $self;
}

sub init {
	my $self
}

sub session {
	my ($self,$p) = @_;

	# the session data hash

	unless ($self->{session}) {
	
		my $sess_cookie = undef;
		$sess_cookie = $self->{c}->{SESSION_ID} if (defined $self->{c});
		#warn "incoming session_id cookie is '$sess_cookie'\n";
		my $inc_sess_id = undef;
		$inc_sess_id = $sess_cookie->value if (defined $sess_cookie);

		my %session_hash;

		tie %session_hash, 'Apache::Session::MySQL', $inc_sess_id, {
					 DataSource => 'dbi:mysql:'.$self->{sess_table}, 
					 UserName	=> $self->{sess_dbuname},  #required when using
					 Password	=> $self->{sess_dbpasswd}, #MySQL.pm
					 LockDataSource => 'dbi:mysql:'.$self->{sess_db},
					 LockUserName	=> $self->{sess_dbuname},
					 LockPassword	=> $self->{sess_dbpasswd}
		};

		$self->{session} = \%session_hash;
	
		my $session_id = $self->{session}->{_session_id};
		#warn "selected session_id is ".$session_id."\n";

		$sess_cookie = Apache::Cookie->new( $self->{r},
						-name		=>	'SESSION_ID',
						-value		=>	$session_id,
						-expires	=>	'+10M',
						-domain 	=>	$self->{domain},
						-path		=>	'/cgi-bin/'
					);
		$sess_cookie->bake;
		#warn "sess_cookie is ".$sess_cookie."\n";
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
	# caller always undef after every use! -->	undef $self->{global};
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
					 #UserName	=> 'ez',				#required when using
					 #Password	=> 'BeZappa929',			#MySQL.pm
					 #LockDataSource => 'dbi:mysql:ez_sessions',
					 #LockUserName	=> 'ez',
					 #LockPassword	=> 'BeZappa929'
	#};

	#$self->{global} = \%global_hash;

	#return $self->{global};
#}


1;