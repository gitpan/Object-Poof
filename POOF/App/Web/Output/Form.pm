package Object::POOF::App::Web::Output::Form;

# form tools.  Inherited by App.pm

use strict;
use warnings;

BEGIN {
   use Exporter ();
   our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,%EXPORT_TAGS);
   $VERSION = 1.00;
   @ISA = qw(Exporter);
   @EXPORT = qw(&form_start &form &form_input);
   %EXPORT_TAGS = ( );
   @EXPORT_OK = qw(); 
}
our @EXPORT_OK; # ???



sub form_start {
   my ($self,$p) = @_;
   my $html = qq#
      <form action="/cgi-bin/main.pl" method="POST">
   #;
   return $html;
}

sub form {
   my ($self,$p) = @_;
   # here's how to handle initial detainting - vars that aren't supposed
   # to be there.  caller function creates a hash, self->{form_wanted}
   # that contains keys of the wanted variable names and values that
   # reflect attributes they are supposed to have, like length limits.
   return undef unless (defined $self->{form_wanted});
   unless (defined $self->{form}) {
      $self->{form} = {};
      my $var = undef;
      foreach $var (keys %{$self->{form_wanted}}) {
         # detaint it here:
	 my $bad = 0;  # innocent until proven guilty

	 # first check types... if int, no characters, etc.
	 $_ = $self->{form_wanted}->{$var}->{type};
	 DATA_TYPE: {
	    (/int/) and do {
	       $bad++ if ($self->{q}->param($var) =~ /\D/);
	       last DATA_TYPE;
	    };

	    (/num/) and do {
	       $bad++ if ($self->{q}->param($var) !~ /^[\d\.\-]*$/);
	       last DATA_TYPE;
	    };
	    (/char/) and do {
	       my $check = $self->{q}->param($var);
	       $bad++ if ($check =~ /[[:cntrl:]]/);

	       # note that these may be excessively restrictive and
	       # may cause errors, for example, if someone is typing
	       # a note or e-mail that includes SQL statements
	       last DATA_TYPE if ($self->{form_wanted}->{$var}->{sql_allowed});
	       $bad++ if ($check =~ /select\s+\S+\s+from\s+\S+\s+/i);
	       $bad++ if ($check =~ /delete\s+from\s+\S+/i);

	       last DATA_TYPE;
	    };
	    (/binary/) and do {
	       # any checks here?
	       last DATA_TYPE;
	    };

	    # else the default is, it's bad
	    $bad++;
         }
	 
	 # then assign it to the form hash if it passes
	 $self->{form}->{$var} = $self->{q}->param($var) unless ($bad);
      }
   }
}

sub form_input {
   my ($self,$p) = @_;

   if (!$p->{name}) {
      warn __PACKAGE__."->form_input(): no field name!\n";
      return undef;
   }
   # type, name, value, size, maxlength:
   # type = text, checkbox, hidden, passwd, textarea
   # name = name
   # value = value
   #    (if checkbox, any value will make it 'on')
   # size      = size
   # maxlength = maxlength
   # etc... other values get stuck onto the tag as applicable
   
   my $html;

   $p->{type} = ($p->{type}) ? $p->{type} : 'text';
   $p->{type} = ($p->{type} eq 'passwd') ? "password" : $p->{type};

   # use submitted values if we are coming back to blank form with an error
   # ... otherwise the form value will (should?) be empty

   unless ($p->{type} eq 'password') {
      $p->{value} = (defined $p->{value}) 
                  ? $p->{value} 
		  : (defined $self->form) ? $self->form->{$p->{name}} : undef;
   }
   # but that still prefers the passed value over form value

   $p->{value} = ($p->{value}) ? $p->{value} : ''; #init for strict

   $_ = $p->{type};
   TYPE: {
      (/checkbox/) and do {
         my $checked = ($p->{value}) ? 'checked' : '';
         $html = qq#<input 
	      type="checkbox" name="$p->{name}" $checked value="1">
         #;
         last TYPE;
      };
      (/textarea/) and do {
         my $rows = ($p->{rows}) ? $p->{rows} : 24;
         my $cols = ($p->{cols}) ? $p->{cols} : 80;
         $html = qq#<textarea 
	       name="$p->{name}"
	       rows="$rows"
	       cols="$cols">$p->{value}</textarea>
	 #;
         last TYPE;
      };
      (/select/) and do {
	 $html = qq#<select name="$p->{name}">
	 #;
         
	 if (!$p->{options}) {
	    $p->{options} = ({ true => 'Yes', false => 'No' });
	    $p->{value} = 'true'  if ($p->{value} eq '1');
	    $p->{value} = 'false' if ($p->{value} eq '0');
	 }

	 my ($optionval,$optiontext);
	 foreach $optionval (keys %{$p->{options}}) {
	    $html .= qq#<option 
	    #;
	    $html .= qq#
	       selected 
	    # if ($optionval eq $p->{value});
	    $html .= qq#
	       value="$optionval">#.$p->{options}->{$optionval}.qq#</option>
	    #;
	 }
	 $html .= qq#
	    </select>
	 #;
         last TYPE;
      };
      (/file/) and do {
         $html = qq#<input
	       type="$p->{type}"
               name="$p->{name}">
	 #;
         last TYPE;
      };
      (/.*/) and do {
	 # 'else' ...
	 #print STDERR qq#
	    #type  = $p->{type}
	    #value = $p->{value}
	 ## if (($p->{type} eq 'password') && ($self->{debug}));
         $html = qq#<input 
	      type="$p->{type}" 
	      name="$p->{name}"
	      value="$p->{value}"
         #;
         $html .= qq# size="$p->{size}"#           if ($p->{size});
         $html .= qq# maxlength="$p->{maxlength}"# if ($p->{maxlength});
         $html .= qq#>\n#;
         last TYPE;
      };
   }
   return $html;
}

END { }

1;
