package TT::Data;
use Carp;
use strict;
use warnings;

BEGIN {
   use Exporter ();
   our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,%EXPORT_TAGS);
   $VERSION = 1.00;
   @ISA = qw(Exporter);
   @EXPORT = qw( &save &dbh &data &data_info &id &find1to1 &table );
   %EXPORT_TAGS = ( );
   @EXPORT_OK = qw(); 
}
our @EXPORT_OK;

# these are data routines that are inherited by other objects.
# they deal with the object's main table, which should be set
# as self->{table}.

sub save {
   # data saving.  
   #    $msg->{save}->{subject} = $subject;
   #    $msg->{save}->{from_email} = $from_email;
   #    $msg->save;
   #    $msg->commit;
   my ($self,$p) = @_;

   my $sql = undef;

   my $field = undef;
   if (defined $self->{save}) {
      return undef unless (defined $self->{save});
   
      $sql = qq#
         update #.$self->{table}.qq# set
      #;
      foreach $field (keys %{$self->{save}}) {
   
         if ($self->_fields->{$field}->{type_datetime}) {
            # if the field is a date or time type, any value means to
            # set the field to now()
	    $sql .= " $field = now(), ";
         }
         if ($self->_fields->{$field}->{type_string}) {
            # quote the string value
	    $sql .= " $field = '".$self->dbh->quote($self->{save}->{$field})."', ";
         }
      }
      #chop the last comma
      $sql =~ s/,\s*$/ /;
   
      # some objects have text ids, like ticket(id)
      if ($self->_fields->{id}->{type_string}) {
         $sql .= qq# where id = '#.$self->id.qq#' #;
      } else {
         $sql .= qq# where id = #.$self->id.qq# #;
      }
      $self->dbh->do($sql);
   }

   # now if the object has a supplementary info table, do it too, the same way

   if (  (defined $self->{table_info}) 
      && (defined $self->{save_info})  ) {
      $sql = qq#
         update #.$self->{table_info}.qq# set
      #;
      foreach $field (keys %{$self->{save_info}}) {
         if ($self->_fields_info->{$field}->{type_datetime}) {
	    $sql .= " $field = now(), ";
         }
         if ($self->_fields_info->{$field}->{type_string}) {
	    $sql .= " $field = '".$self->dbh->quote($self->{save}->{$field})."', ";
         }
      }
      $sql =~ s/,\s*$/ /;
      # some objects have text ids, like ticket(id)
      if ($self->_fields_info->{id}->{type_string}) {
         $sql .= qq# where id = '#.$self->id.qq#' #;
      } else {
         $sql .= qq# where id = #.$self->id.qq# #;
      }
      $self->dbh->do($sql);
   }

   # that should be it
   return undef;
}

sub dbh {
   # for ease of use, returns object's POOF::DB->dbh thread
   # now caller app must initialize DB object(s) and pass around threads
   my ($self,$p) = @_;
   return undef unless (defined $self->{db});
   unless (defined $self->{dbh}) {
      $self->{dbh} = $self->{db}->dbh;
   }
   return $self->{dbh};
}


sub data {
   # data retrieval.  refer to table contents like 
   # self->data->{user_id}    ... to select first time or reload
   # self->{data}->{user_id}  ... to use cached data
   my ($self,$p) = @_;
   $self->{data} = {};
   my $sql = qq# select * from #.$self->{table}.qq# where id = #;
   $sql .= ($self->_fields->{id}->{type_string}) 
         ? "'".$self->id."'"
	 : $self->id;
   $self->{data} = $self->dbh->selectrow_hashref($sql);
   return $self->{data};
}

sub data_info {
   # like data(), only used if object has supplementary obj_info field
   my ($self,$p) = @_;

   return undef unless (defined $self->{table_info});
   $self->{data_info} = {};
   my $sql = qq# 
      select * 
      from #.$self->{table_info}.qq# 
      where id = #.$self->id.qq#
   #;

   $self->{data_info} = $self->dbh->selectrow_hashref($sql);
   return $self->{data_info};

}


sub id {
   my ($self,$p) = @_;
   unless (defined $self->{id}) {
      my $sql = qq#
         insert into #.$self->{table}.qq# (id) values (0)
      #;
      warn $sql;
      $self->dbh->do($sql);
      $sql = qq#
         select last_insert_id
      #;
      my ($id) = $self->dbh->selectrow_array($sql);
      warn __PACKAGE__."->id() didn't get an autoinc id back from insert.\n"
         unless defined ($id);

      $self->{id} = $id;
   }
   return $self->{id};
}


sub table {
   # can be called as instance or Data:: class method (passing class)... wacky
   my $param = shift;
   my $self;
   my $class;
   if (ref $param) {
      $self = $param;
      return $self->{table} if ($self->{table});
      $class = ref $param;
   } else {
      $class = $param;
   }
   my ($crap,$table,$trash) = split /::/, $class;
   return lc $table;
}




# findOneToOne, FindOneToMany, etc. should be in Data::Shepherd.
# up, down, left, right, they are all things Shepherd should do.


#---------------------------------------------------------------------


sub _fields {
   # return the dynamic sub that returns hash of main table columns & props
   my $self = shift;
   return $self->{db}->fields->{$self->{table}};
}
sub _fields_info {
   # return the dynamic sub that returns hash of info table columns & props
   my $self = shift;
   return $self->{db}->fields->{$self->{table}};
}

END { }

1;
