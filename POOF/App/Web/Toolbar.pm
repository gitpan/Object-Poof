package Object::POOF::App::Web::Toolbar;

use strict;
use warnings;
use Carp;

sub new {
	my $class = shift;
	my $self = { @_ };
	$self->{class} = $class;
	bless $self, $class;
	($self->init) or return undef;
	return $self;
}

sub init {
	my $self = shift;
	$self->{url} = $ENV{SCRIPT_NAME};
	return 1;
}

sub jscript {
	my $self = shift;
	my $script = qq(
<SCRIPT LANGUAGE="JavaScript1.2">
<!--
function loadMenus() {
	);
	my $i = 0;
	my $k = 0;
	foreach my $lev1 (@{$self->{menu}}) {
		$i++;
		my $lev1tag = ucfirst($lev1->{name});
		$lev1tag =~ s/[^\w\d]//g; #squeeze
		$script .= qq(
			window.myMenu$lev1tag = new Menu("$lev1->{name}");
			window.myMenu$lev1tag.addMenuItem("$lev1->{name}",
				"top.window.location='?$lev1->{funk}'");
		);
		my $j = 0;
		foreach my $lev2 (@{$lev1->{submenu}}) {
			$j++;
			my $lev2tag = ucfirst($lev2->{name});
			$lev2tag =~ s/[^\w\d]//g; #squeeze

			$script .= qq(
				window.myMenu$lev2tag = new Menu("$lev2->{name}");
				window.myMenu$lev2tag.addMenuItem("$lev2->{name}",
					"top.window.location='?$lev2->{funk}'");
			);
			# then do foreach for level 3 links, and add level 3 to level 2

			# then come back and add the level 2 menu to the level 1

		}

		
	}
	$script .= qq(
	myMenu1.writeMenus();
}
//-->
</SCRIPT>
	);
}

sub output {
	my $self = shift;
	if ($self->{orient} eq "top") {
		return $self->output_top;
	} else {
		return undef;
	}
}

sub output_top {
	my $self = shift;
	my $html = qq(
		<table border="$self->{border}" cellpadding="0" cellspacing="0">
		<tr>
		
		<td>
			<img src="$self->{logo}->[0]" 
				width="$self->{logo}->[1]"
				height="$self->{logo}->[2]"
				border="0">
		</td>
	);

	foreach (@{$self->{menu}}) {
		$html .= qq(
		<td align="center">
			<a href="$self->{url}?funk=$_->{funk}">
			<img src="$_->{img}->[0]"
				width="$_->{img}->[1]"
				height="$_->{img}->[2]"
				border="0"><br>
			$_->{name}
		</td>
		);
	}
	$html .= qq(
		</tr>
		</table>
	);
	return $html;
}

1;
