#!/usr/bin/perl

# DB.pm has general subroutines for the database.
# a reference this object can be passed around to objects,
# or objects can create their own 
# so they have an independent commit/rollback thread

package POOF::DB;

require DBI;

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = { @_ };
   $self->{class} = $class;
   bless ($self, $class) or warn "Could not bless $self, $class\n";

   $self->db_connect;

   return $self;
}


sub destroy {
   my $self = shift;
   if ($self->{debug}) { warn "SL::DB::destroy\n"; }
   $self->db_disconnect or warn __PACKAGE__."->destroy could not disconnect.\n";
   $self->{dbh} = undef;
   return;
}

sub dbh {
   my $self = shift;
   $self->db_connect unless ($self->{dbh});
   return $self->{dbh};
}

sub db_connect {
   my $self = shift;

   #my $dbname = "TT";
   #my $dbhost = "localhost";
   #my $dbstr  = "dbi:mysql:dbname=$dbname;host=$dbhost";
   #my $dbuname = 'tt';
   #my $dbpass = 'bobshish997';

   #warn qq#
      #dsn     => $self->{dsn}
      #dbuname => $self->{dbuname}
      #dbpass  => $self->{dbpass}
   ##;

   $self->{dbh} = DBI->connect( $self->{dsn}, $self->{dbuname}, $self->{dbpass},
                                 { PrintError => 1,
				   RaiseError => 1, 
				   AutoCommit => 0 }
		  
      )
      or warn __PACKAGE__."->db_connect\n   No db: ".DBI::errstr."\n";
}

sub db_disconnect {
   my $self = shift;

   # commit or rollback should be called explicitly before destroy/disconnect

   my $rc = $self->dbh->disconnect 
      or warn "No db disconnect:".DBI::errstr."\n";;

   $self->{dbh} = '';
   return $rc;
}

sub commit {
   my $self = shift;
   my $rc = $self->dbh->commit;   # do any checks here?

   return $rc;
} 

sub rollback {
   # cancels all queries so far
   my $self = shift;
   $self->dbh->rollback;
   return ($self->{dbh}->errstr) ? $self->dbh->errstr : '';
}


sub rolldie {
   my $self = shift;
   my $errmsg = shift;
   $self->dbh->rollback;
   my $errstr = $self->dbh->errstr if ($self->dbh->errstr);
   $self->destroy;
   die "$errmsg: $errstr\n";
}

sub fields {
   # NEW dynamic subs, preferred.
   # Data.pm should have a fields routine that calls this one with
   # the table name.  So callers just call $obj->fields, which returns
   # $obj->{db}->fields->{$obj->{table}}
   # and $obj->fields_info returns $obj->{db}->fields->{$obj->{table_info}}
   my $self = shift;
   unless ($self->{fields}) {
      $self->{fields} = POOF::DB::Fields;
   }
   return $self->{fields};
}

sub oldfields {
   # OLD fields object, deprecated
   #
   my ($self,$p) = shift;
   # this is a hash of all database tables, fields, types, descripts.
   # hardcode descripts or just leave them empty.
   # that means a caller referring to a descript that doesn't get anything 
   # back will either have to put in a blank or just use the field name.
   unless ($self->{fields}) {
      $self->{fields} = {};
      my $sql = qq#
         show tables
      #;
      my $table;
      my $sth = $self->dbh->prepare($sql);
      my $rv = $sth->execute;
      while (($table) = $sth->fetchrow_array) {
         $self->{fields}->{$table} = {};
      }
      my $hr;
      foreach $table (keys %{$self->{fields}}) {
         $sql = qq#
	    show columns from $table
	 #;
	 $sth = $self->dbh->prepare($sql);
	 $rv = $sth->execute;
	 while ($hr = $sth->fetchrow_hashref) {
	    my $field = $hr->{Field};
	    $self->{fields}->{$table}->{$field} = {};
	    my $type = $hr->{Type};
	    my $limit = '';
	    if ($type =~ /^(\w.*)\((\d+)\)$/) {
	       $type = $1;
	       $limit = $2;
	    }
	    $self->{fields}->{$table}->{$field}->{type}  = $type;
	    $self->{fields}->{$table}->{$field}->{limit} = $limit;
	    my $descript = $field;
	    $descript =~ s/_/ /g;
	    $descript = ucfirst($descript); # override manually if needed
	    $self->{fields}->{$table}->{$field}->{descript} = $descript;

	    # also set a flag that tells the object's save routine
	    # whether or not to quote the value.  the object's save
	    # routine must double-check whether the value matches characters
	    # because enum types are not included in this check, since
	    # they can be inputted as either strings or enumeration index vals
	    if ($type =~ /[date|time|year]/i) {
	       $self->{fields}->{$table}->{$field}->{type_datetime} = 1;
	    }
	    if ($type =~ /[char|text|blob]/i) {
	       $self->{fields}->{$table}->{$field}->{type_string} = 1;
	    }
	 }
      }
      # here's where to override descriptions if necessary
      #$self->{fields}->{user}->{fullname}->{descript}       = "Full name";
      #$self->{fields}->{user}->{phone_business}->{descript} = "Business phone";
      #... etc. when there is time
   }
   return $self->{fields};  # sally?
}

1;
