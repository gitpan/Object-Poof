package POOF::App::Web;

use strict;
use warnings;
use Carp;

use Apache::Constants qw(:common);
use Apache;
require Apache::Request;
require Apache::Cookie;

use POOF::App::Web::Session;
use POOF::App::Web::Output::Form;
use POOF::App::Web::Output::HTML;
use POOF::Data;

require POOF::DB;

sub new {
   my ($proto) = shift;
   my $class = ref($proto) || $proto;
   my $self = { @_ };
   $self->{class} = $class;
   $self->{db} = (defined $self->{db}) 
               ? $self->{db}
	       : undef;
   return undef unless (defined $self->{db});

   bless $self,$class;

   my $status = $self->init;
   croak __PACKAGE__."->new(): init status: $status\n" 
      if (defined $status);
   return $self;
}



sub init {
   my ($self,$p) = @_;

   $self->{r} = Apache->request;
   warn "App->init, my r is ".$self->{r}."\n";

   $self->{domain} = $ENV{SERVER_NAME};

   # get the incoming cookies
   $self->{c} = Apache::Cookie->fetch; 
   my ($cookie_warn) = (defined $self->{c}) ? $self->{c} : 'undef';
   warn "init: self->{c} is $cookie_warn\n";

   # create an apache request object to get form variables
   $self->{q} = Apache::Request->new($self->{r});
   my $status = $self->{q}->parse;
   unless (($status eq 'OK') || (!$status)) {
      $self->{q}->custom_response($status, 
                                  $self->{q}->notes("error-notes"));
      return $status;
   }

   $self->{s} = POOF::App::Web::Session->new( r => $self->{r}, c => $self->{c} );
   return "could not create POOF::App::Web::Session object.\n" 
      unless (defined $self->{s});

   $self->{url} = $ENV{SCRIPT_NAME};

   return undef;
}


sub run {
   my ($self,$p) = @_;

   #$self->{funk_name} = (  (defined $self->{q}->param('funk'))
                        #&& (length($self->{q}->param('funk')) <= 64)
		        #&& ($self->{q}->param('funk') =~ /^\w+$/) )
                      #? $self->{q}->param('funk')
		      #: "default";

   #require POOF::Funk;

   #$self->{funk} = POOF::Funk->new( funk => $self->{funk_name} );

   #warn "self->{funk} is '".$self->{funk}."' in run()\n";

   #if (not defined $self->{funk}) {
      #$self->{r}->internal_redirect("/bad_funk.html");
      #die "Bad funk name '".$self->{funk_name}."'";
   #}

   my $html = '';

   $html .= $self->header;

   #$html .= $self->funk;
   $html .= "beef";

   $html .= $self->footer;

   # now send headers and print
   $self->{r}->send_http_header("text/html");
   $self->{r}->print($html);

   return OK;
}

sub funk {
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
