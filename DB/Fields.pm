#!/usr/bin/perl

package TT::DB::Fields;

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;

   my $self = { @_ };
   $self->{class} = $class;
   bless ($self, $class) or warn "Could not bless $self, $class\n";

   return undef unless (defined $self->{db});
   $self->{tables_list} = [];
   $self->init;

   return $self;
}

sub init {
   my ($self,$p) = @_;
   # generate subroutines dynamically to access column data of each table 
   # also builds some little structures for quick "table exists" checking,
   # since calling the sub will bomb for a table that doesn't exist
   my $sql = qq#
      show tables
   #;
   my $table;
   my $sth = $self->dbh->prepare($sql);
   my $rv = $sth->execute;
   no strict 'refs';
   while (($table) = $sth->fetchrow_array) {
      push @{$self->{tables_list}}, $table;
      $self->{$table}->{table_fields}->{$field} = 1;
      *$table = *{uc $table} = sub {
         my ($self,$p) = @_;
	 unless (defined $self->{$table}) {
	    my $sql = qq#
	       show columns from $table
	    #;
	    $sth = $self->dbh->prepare($sql);
	    $rv = $sth->execute;
	    while ($hr = $sth->fetchrow_hashref) {
	       my $field = $hr->{Field};
	       $self->{$table}->{$field} = {};
	       my $type = $hr->{Type};
	       my $limit = '';
	       if ($type =~ /^(\w.*)\((\d+)\)$/) {
	          $type = $1;
	          $limit = $2;
	       }
	       $self->{$table}->{$field}->{type}  = $type;
	       $self->{$table}->{$field}->{limit} = $limit;
	       my $descript = $field;
	       $descript =~ s/_/ /g;
	       $descript = ucfirst($descript); # override manually if needed
	       $self->{$table}->{$field}->{descript} = $descript;
   
	       # also set a flag that tells the object's save routine
	       # whether or not to quote the value.  the object's save
	       # routine must double-check whether the value matches characters
	       # because enum types are not included in this check, since
	       # they can be inputted as either strings or enumeration index vals
	       if ($type =~ /[date|time|year]/i) {
	          $self->{$table}->{$field}->{type_datetime} = 1;
	       }
	       if ($type =~ /[char|text|blob]/i) {
	          $self->{$table}->{$field}->{type_string} = 1;
	       }
	    }
         }
	 return $self->{$table};
      }
   }
   use strict 'refs';

}






1;
