package Object::POOF::App::Web;

use strict;
use warnings;
use Carp;

#$Apache::Registry::Debug = 4;
use Apache::Constants qw(:common);
use Apache;
require Apache::Request;
require Apache::Cookie;

use Object::POOF::App::Web::Session;
use Object::POOF::App::Web::Output::Form;
use Object::POOF::App::Web::Output::HTML;
use Object::POOF::Data;

sub new {
	my ($proto) = shift;
	my $class = ref($proto) || $proto;
	my $self = { @_ };
	$self->{class} = $class;
	$self->{db} = (defined $self->{db}) 
					? $self->{db}
			 : undef;
	#warn __PACKAGE__."->new(), db is ".$self->{db}."\n";
	return undef unless (defined $self->{db});

	bless $self,$class;

	return $self;
}



sub app_init {
	my ($self,$p) = @_;

	#$self->{r} = Apache->request;

	my ($pack,$file,$line) = caller;
	#warn __PACKAGE__."->init, my r is ".$self->{r}."\n";
	#warn __PACKAGE__." caller package  = $pack\n";
	#warn __PACKAGE__." caller filename = $file\n";
	#warn __PACKAGE__." caller line     = $line\n";

	$self->{domain} = $ENV{SERVER_NAME};

	# get the incoming cookies
	$self->{c} = Apache::Cookie->fetch; 
	my ($cookie_warn) = (defined $self->{c}) ? $self->{c} : 'undef';
	#warn "init: self->{c} is $cookie_warn\n";

	# create an apache request object to get form variables
	#$self->{q} = Apache::Request->new($self->{r});  # global from handler
	my $status = $self->{q}->parse;
	unless (($status eq 'OK') || (!$status)) {
		$self->{q}->custom_response($status, 
									$self->{q}->notes("error-notes"));
		warn __PACKAGE__."->init(): bad apache parse status: $status,";
		warn "error-notes: ".$self->{q}->notes("error-notes");
		return $status;
	}

	$self->{s} = Object::POOF::App::Web::Session->new( 
										r => $self->{r}, 
													 c => $self->{c},
										sess_table => $self->{sess_table},
										sess_dbuname => $self->{sess_dbuname},
										sess_dbpasswd => $self->{sess_dbpasswd}
										);
	return "could not create Object::POOF::App::Web::Session object.\n" 
		unless (defined $self->{s});

	$self->{url} = $ENV{SCRIPT_NAME};

	return undef;
}

sub funk_setup {
	my ($self,$p) = @_;

	$self->{funk_name} 	= (	(defined $self->{q}->param('funk'))
							&& (length($self->{q}->param('funk')) <= 64)
				  			&& ($self->{q}->param('funk') =~ /^\w+$/) )
						? $self->{q}->param('funk')
						: "";
	$self->{funk_name}	=~ s/\/+/::/g;

	$self->{funk_num} 	= (	(defined $self->{q}->param('funk_num'))
							&& ($self->{q}->param('funk_num') !~ /\D/) )
						? $self->{q}->param('funk_num')
						: "";

	$self->{funklib} 	= $self->{baseclass};

	$self->{funklib}	.= (defined $self->{funk_dir})
						? '::'.$self->{funk_dir}
						: '';
	
	$self->{funklib} .= "::Funk";
	$self->{funklib} .= ($self->{funk_name}) 
					  	? "::".$self->{funk_name} 	
						: "::Default";
	$self->{funklib} .= ($self->{funk_num})	 
						? "::".$self->{funk_num}	
						: "";

	warn "self->{funklib} is '".$self->{funklib}."' in funk_setup()\n";

	eval("use ".$self->{funklib});

	# how do you like them apples?
	$self->{funk} = $self->{funklib}->new( 
						db 			=> $self->{db},
						baseclass 	=> $self->{baseclass},
					);
	#warn "self->{funk} is now '".$self->{funk}."' in funk_setup()\n";
	return;
}

sub run {
	my ($self,$p) = @_;
	
	$self->funk_setup;

	# now send headers and print
	$self->{r}->content_type("text/html");
	$self->{r}->send_http_header;
	$self->{r}->print( $self->{funk}->funk );
	#$self->{r}->print($self->output_header);
	#$self->{r}->print($self->output_header 
	                #. $self->{funk}->funk 
					#. $self->output_footer   );
	#$self->{r}->print("testing 1 2 3 testing\n");
	return;
}

sub bogusfunk {
	my ($self,$p) = @_;
	my $q = $self->{q} or return undef;  # tired of typing

	my $funk = $self->{funk_name};

	my $html = $self->bar;

	FUNK: {

		($funk eq 'info') and do {
	 $html .= $self->page_info;
	 last FUNK;
		};

		($funk eq 'login') and do {
			$html .= $self->page_login;
	 last FUNK;
		};

		#($funk eq 'qna') and do {
			#$html .= $self->page_qna;
			#last FUNK;
		#};


		do {
			# default
	 $html .= $self->page_index;
		};
	}

	return $html;
}



1;