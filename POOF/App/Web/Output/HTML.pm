package Object::POOF::App::Web::Output::HTML;

use strict;
use warnings;

BEGIN {
	use Exporter ();
	our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,%EXPORT_TAGS);
	$VERSION = 1.00;
	@ISA = qw(Exporter);
	@EXPORT = qw( &output_header &button &blank &bar &output_footer );
	%EXPORT_TAGS = ( );
	@EXPORT_OK = qw(); 
}
our @EXPORT_OK; # ???


sub output_header {
	my ($self,$p) = @_;
	my $title = ($p->{title}) ? $p->{title} : $self->{funk}->{title};
	my $html = qq#
		<head>
		<title>$title</title>
	#;
	(defined $self->{csslib_file}) && do {
		$html .= qq#
			<link rel="stylesheet" href="/#.$self->{csslib_file}.qq#"></link>
		#;
	};
	(defined $self->{jslib_file}) && do {
		$html .= qq#
			<script language="JavaScript" type="text/JavaScript" 
			src="/#.$self->{jslib_file}.qq#"></script>
		#;
	};
	$html .= qq#
		</head>
		<body>
	#;
	return $html;
}

sub button {
	# button for the menu bar... stuff for inside a <td>
	my ($self,$p) = @_;
	return "button\n";
#	my $button = $p->{button};
#	return undef if (not defined $button);
#	my $button_sel = $button . "_sel";
#	my $button_on  = $button . "_on";
#	my $button_name = uc($button);
#	my $html = qq#
#		<a class="bar"
#			href="#.$self->{url}.qq#?funk=$button"
#			onMouseOut="MM_swapImgRestore()"
#	 onMouseOver="MM_swapImage('BUTTON$button_name','',
#								 '/imgs/button_$button_on.72x56.png',1)">
#		<img src="/imgs/button_#;
#	#warn "self->{funk} is '".$self->{funk}."'\n";
#	#warn "button is '".$button."'\n";
#
#	#my $funkroot = (  (defined $self->{funk}->root)
#						#&& ($self->{funk}->root->data->{funk} eq $button)  )
#					 #? 1
#		#: undef;
#
#	$html .= (  ($self->{funk_name} eq $button) 
#				|| ($p->{sel})
#		 || ($funkroot) ) 
#			 ? $button_sel
#	  : $button;
#	$html .= qq#.72x56.png" width="72" height="56"
#			name="BUTTON$button_name" border="0"><br>
#	#;
#	$html .= $self->{bar_desc}->{$button};
#	$html .= "</a>\n";
#	return $html;
}

sub bar {
	my ($self,$p) = @_;
	my ($info_sel,$howto_sel,$signup_sel,$contractors_sel,$login_sel);

	my $sel = {};
	if (defined $p->{sel}) {	# p->{sel} = 'info', whichever
		$sel->{$p->{sel}} = 1;
		#warn "sel->{p->{sel}} = sel->{".$p->{sel}."} = ".$sel->{$p->{sel}}."\n";
	}

	# define the toolbar item funks and their descriptions
	unless (defined $self->{bar_desc}) {
		$self->{bar_desc} = {
			info		  => 'More Info',
	 qna			=> 'Q &amp; A',
	 login		 => 'Log In',
	 request	  => 'Get Help'
		};
	}
	unless (defined $self->{bar_order}) {
		$self->{bar_order} = [ qw( info qna login request ) ];
	}

	my $titleimg = "/imgs/orgs/".$self->{org}->id."/title.png";
	my $html = qq#
		<table class="bar">
		<tr>
		<td class="bar">
			<a class="bar" href="/cgi-bin/main.pl">
			<img src="$titleimg" width="216" height="72" border="0">
	 </a>
		</td>
	#;

	my $button;
	#foreach $button (keys %{$self->{bar_desc}}) {
	foreach $button (@{$self->{bar_order}}) {
		$html .= qq#<td class="bar">#.$self->blank(6,1).qq#</td>#;

		$html .= qq#<td class="bar">#;
		my $selected = 0;
		$selected = 1 if ($sel->{$button});
		$html .= $self->button({ button => $button, sel => $selected });

		$html .= "</td>\n";
	}

	$html .= qq#
		</tr>
		</table>
	#;
	return $html;
}

sub blank {
	my ($self,$width,$height) = @_;
	return qq#
		<img class="blank"
		src="/imgs/blank.png" width="$width" height="$height">
	#;
}

sub output_footer {
	my ($self,$p) = @_;
	return qq#
		<p class="footer">
			footer section
		</p>
	#;
#	$self->{org}->data		unless (defined $self->{org}->{data});
#	$self->{org}->data_info unless (defined $self->{org}->{data_info});
#	my $html = qq#
#		<p class="footer">
#			#.$self->{org}->{data}->{name}.qq#<br>
#	 #.$self->{org}->{data_info}->{addr1}.qq#<br>
#	#;
#	if (defined $self->{org}->{data_info}->{addr2}) {
#		$html .= qq#
#			#.$self->{org}->{data_info}->{addr2}.qq#<br>
#		#;
#	}
#	$html .= qq#
#	 #.$self->{org}->{data_info}->{city}.", "
#		 .uc($self->{org}->{data_info}->{state})."  "
#		 .$self->{org}->{data_info}->{zip}." "
#		 .uc($self->{org}->{data_info}->{country}).qq#<br>
#	 #.$self->{org}->{data_info}->{phone}.qq#
#		</p>
#	#;
#	return $html;
}



1;
