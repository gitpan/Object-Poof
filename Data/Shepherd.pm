package POOF::Data::Shepherd;

use strict;
require POOF::DB;
use POOF::Data;  # should qw this, since Shepherd doesn't have a table.
                 # but we need routines like dbh, etc.

# POOF::Data::Shepherd->new( herds => $obj | ref $obj );
# if passed herd as $obj, saves ref as {herds} and makes {root} = $obj.
# then if class is a tree, breed() uses {root}.
# if class is a list, line() populates the list. 
# if class is some other structure, populate some other way, etc.

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = { @_ };
   bless $self,$class;
   ($self->init) or return undef;
   return $self;
}


sub init {
   my $self = shift;
   return undef unless $self->{db};
   if (ref $self->{herds}) {
      # if {herds} is an object, assume it's a root of some structure.
      $self->{root}  = $self->{herds};
      $self->{herds} = ref $self->{herds};
   } 
   # else {herds} is a class (ref $someobj), so just use it.
   return undef unless ($self->{herds});

   my $table = $self->{table} = $self->table($self->{herds});
   my $table_info = $table."_info";

   if ($self->{db}->fields->{table_fields}->{$table_info}) {
      $self->{table_info} = $table_info;
   }
   return 1;
}


#sub callOneToOne {
#   # only an instance method.
#   # $relation is a blessed object of some class.
#   my ($self,$relation) = @_;
#
#   my $relation_tab = POOF::Data::table( ref $relation );
#   
#   return undef unless grep(/^$relation_tab$/,
#                            @{$self->{db}->fields->{tables_list}});
#   my $reltab1 = $self->{table}."_".$p->{table};
#   my $reltab2 = $p->{table}."_".$self->{table};
#   my $reltab;
#   if grep(/^$reltab1$/,@{$self->{db}->fields->{tables_list}}) {
#      $reltab = $reltab1;
#   } elsif grep(/^$reltab2$/,@{$self->{db}->fields->{tables_list}}) {
#      $reltab = $reltab2;
#   } else {
#      return undef;
#   }
#   my $sql = qq#
#      select #.$relation_tab.qq#_id from $reltab 
#      where #.$self->table.qq#_id=#.$self->id.qq#
#   #;
#   my ($related_id) = $self->dbh->fetchrow_array($sql);
#   return $related_id;
#}


sub release {
   my ($self,$obj) = @_;
   # if obj has a structure depending on it, i.e. if it is the head
   # of a list flock, or it is the root of a tree flock, should the
   # flock be released as well?  I'm going to assume so right now.
   $self->release_root($obj);  # interestingly, this also calls release_head
   $obj->destroy;
   return;
}

sub release_all {
   my ($self,$p) = @_;
   # release all flocks, those pointed to by root() or head()
   $self->release_head;
   $self->release_root;
   return;
}

sub release_head {
   # releases (destroys) whole flock pointed to by {head}, i.e. a list
   my ($self,$p) = @_;
   
   my $leaf = ($p->{head}) ? $p->{head} : $self->{head};
   return unless $leaf;
   my $table = $leaf->table;
   return unless ($self->{db}->fields->$table->{next_id});

   while (my $next = $leaf->{next}) {
      $leaf->destroy;
      $leaf = $next;   # '$next' becomes the last pointer to the obj in loop
   }
   return;
}

sub release_root {
   # releases (destroys) whole flock pointed to by {root}, i.e. a tree
   # and any process lists stemming from any node

   my ($self,$p) = @_;

   my $root = ($p->{root}) ? $p->{root} : $self->{root};
   return unless $root;
   my $table = $root->table;
   return unless ($self->{db}->fields->$table->{up_id});

   # first, if $root has a {next}, it is also a stem process, so release that
   if ($root->{next}) {
      $self->release_head({ head => $root });
   }

   # now call recursively down the tree
   foreach (@{$root->{down}}) {
      $self->release_root({ root => $_ });
   }

   # while un-stacking recursive calls, destroy the object.
   # calling function in stack should contain the last reference to it.
   $root->destroy;
   return;
}

sub sql_select {
   my ($self,$p)  = @_;
   my $p_where  = $p->{where};
   my $p_what   = $p->{what};
   my $table      = $self->{table};
   my $table_info = $self->{table_info};
   my $fields     = $self->{db}->fields;  # DB::Fields object
   
   # here this needs to deal with the 'what' in either tm.what or ti.what
   # accordingly (and transparently).  what is a ref to an array.
   my $sql = "select ";

   my @append;
   foreach (@$p_what) {
      if ($fields->$table->{$_}) {
         push @append, "tm.".$_;
      } elsif ((defined $table_info) && ($fields->$table_info->{$_})) {
         push @append, "ti.".$_;
      } # else skip it, it isn't a valid field
   }
   $sql .= "\n". join " ,\n ", @append;
   $sql .= "\n";

   $sql   .= "from $table as tm \n";
   $sql   .= " , $table_info as ti \n"         if (defined $table_info);
   $sql   .= " where \n";
   $sql   .= " tm.id = ti.id and \n"           if (defined $table_info);

   my @pairs;
   foreach (keys %$p) {
      my $t;
      my $tab;
      # simply ignore fields that aren't in table or table_info
      if (defined $table_info) {
         next unless (($fields->$table->{$_}) || ($fields->$table_info->{$_}));
         # now, is the key in table or table_info?
	 if ($fields->$table_info->{$_}) {
	    $t = "ti";
	    $tab = $table_info;
	 } else {
	    $t = "tm";
	    $tab = $table;
	 }
      } else {
         next unless ($fields->$table->{$_});
	 $t = "tm";
	 $tab = $table;
      }
      push @pairs, " $t.$_ = "
                   .$self->dbh->quote( $p->{$_}, 
                                       $fields->$tab->{$_}->{type} );
		# dbh->quote is supposed to know whether to quote or not
		# if you pass it the type... but my 'type' may not be right
   }
   $sql .= join ' \n and ', @pairs;
   return $sql;
}

sub callOne {
   # instance method.  must already be herding.  creates an object
   # of self's herding class based on passed field criteria.
   # only parameters in $p should be fields and values
   my ($self,$p)  = @_;
   return undef unless ($self->{herds});

   my $sql = $self->sql_select($p);

   my ($id) = $self->dbh->fetchrow_array( 
                 $self->sql_select( where => $p, what => [ 'id' ] ) );
   $self->{lastcallOne} = eval { 
      $self->{herds}."->new( id => $id, db => ".$self->{db}." );" 
      # does this actually work?  that would be cool.
      # i'm concerned it will interpret $self->{db} as a string first.
      # (maybe that doesn't matter?)
   };
   warn "nope it didn't work.\n" unless ($self->{lastcallOne});
   return ($self->{lastcallOne}) ? $self->{lastcallOne} : undef;
}

sub callMany {
   my ($self,$p) = @_;
   return undef unless ($self->{herds});

   my $sth = $self->dbh->prepare( 
                $self->sql_select({ where => $p,
                                    what  => [ qw( id up_id down_id
				                   next_id prev_id
						   left_id right_id ) ]    }) 
				);
   # the various pointer id's just won't be there if not defined in table
   my $rv  = $sth->execute;
   while (my $row = $sth->fetchrow_hashref) {
      # WHAT IF... Shepherd doesn't need to structure anything.
      # Shepherd just builds objects for each id and fills in these vals.
      # It could do a 'one root detect' and 'one head detect' and set
      # self->{root} and/or self->{head}, but it doesn't have to.
      # as long as these objects are pushed to @{$self->{herd}} then
      # they are already essentially a structure and in order.
      # may want to make a more elaborate structure for self->{herd} later.

      my $obj = eval{ $self->{herds}."->new( id => ".$row->{id}.", 
                                             db => ".$self->{db}." );" };
      foreach (qw(up_id down_id next_id prev_id left_id right_id)) {
         $obj->{$_} = $row->{$_} if (defined $row->{$_});
      }
      push @{$self->{herd}}, $obj;
   }

   # this doesn't order/link the herd
}


   #my ($count) = $self->dbh->selectrow_array(
                    #$self->sql_select({ where => $p,
		                        #what  => [ 'count(id)' ] })
					    #);

sub order {
   my ($self,$p) = shift;
   # this could be an intensive process for a big structure... hmmm...
}

sub callOneToMany {
   my ($self,$p) = @_;
   my $obj = $p->{obj};
   return undef unless $obj;
   
   # clear the current flocks:
   foreach my $class (keys %{$obj->{contains}}) {
      my $table = POOF::Data->table($class);
      # $obj->{contains}->{$class} is shepherd for that contained flock
      if ($obj->{contains}->{$class}) {
         $obj->{contains}->{$class}->release_all;  # i.e. mass destroy()
      } else {
         $obj->{contains}->{$class} 
	    = POOF::Data::Shepherd->new({ herds => $class,
	                                  db    => $self->{db}  });
      }
      $obj->{contains}->{$class}->callMany({ $table."_id" => $obj->id });
   }

   # 

   # this is for calling a substructure of an object,
   # for example, if shepherd herds messages, and messages
   # contain attachments (i.e. true == grep(/^attachment$/,
   #                                        @$message->{onetomany}) 
   #                     ),
   # then $shep->callOneToMany($message) returns a list of the
   # objects returned by a call where 
   #
   # or should that be callManyToOne?  As shepherd allegory, that makes
   # more sense reading, but what it does is call sub-flocks of each
   # table/class in the array {onetomany}
   # hmmm.
   # {onetomany} has to be classes, because Shep knows how to get tables
   # from classes, but can't get classes from just tables--- what is
   # "My::" part of "My::Object"?

   # here's a thought... it should create an internal team of shepherds
   # and delegate responsibility for each flock returned... because these
   # are a different class.  if just one returned, pass 

   #foreach my $class (@{$obj->{onetomany}) {
      #$obj->{contains}
   #}

}

sub breed {
   # breeds generations of n-ary trees from $self->{root}, which
   # must be present and of a type that has up_id in database.
   # example: funks.  this is also capable of attaching process stems,
   # which are singly-linked lists using prev.
   # but for each object, breed() fills in {next},{prev},{up}, and {down}=\@..

      # NOTE this is horrendously inefficient to use callOne.
      # if the structure is very big, use callMany in the first place.
      # use this if only the root or head is known, but the criteria
      # to find children is not.

   my ($self,$stem) = @_;
   return undef unless ($self->{root});
   my $table = $stem->table;
   return undef unless ($self->{db}->table->fields->$table->{up_id});

   my $leaf = $stem;  # mixed metaphor hell

   if ($self->{db}->fields->$table->{next_id}) {
      # if this tree also has linked-list processes, fill them in if there
      while (my $next = $self->callOne({ prev_id => $leaf->id }) ) {
         $leaf->{next} = $next;
	 $next->{prev} = $leaf;
	 $leaf = $next;
      }
   }



}


# a module for keeping a flock of objects.
# should access objects' 'super', 'sub', 'prev' and 'next' objects of a class
# if they exists
#
# general data methods for find-by-field
#
# data population methods for a group of objects

# for example, if this is the Funk Shepherd, which keeps the menu,
# it already has all the superfunk, root funk, next funk etc.
# accessible from 'this' funk simply because 'super_id', 'next_id'
# and so on exist in the database.  if 'sub_id' doesn't exist,
# shepherd knows structure is a tree, so search for subs where
# super_id is this id.  

1;
