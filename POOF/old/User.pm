package Object::POOF::User;

use strict;
use Carp;
require Object::POOF::DB;
use Object::POOF::Data;

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = { @_ };
   bless $self,$class;
   $self->init;
   return $self;
}

sub init {
   my ($self,$p) = @_;

   $self->{db} = Object::POOF::DB->new() unless (defined $self->{db});

   $self->{table}      = "users";
   $self->{table_info} = "users_info";

   $self->id unless (defined $self->{id});  # generate if not passed
   
   if ((defined $self->{org}) || (defined $self->{org_id})) {
      # check to make sure user doesn't already have a primary org
      if ($self->data->{org_id}) {
	 require Object::POOF::Org;
         $self->{org} = Object::POOF::Org->new( id => $self->{data}->{org_id}, 
	                               db => $self->{db}               );
         # and what, throw an exception?  that might cause total rollback.
      } elsif ((defined $self->{org_id}) and (not defined $self->{org})) {
	 require Object::POOF::Org;
         $self->{org} = Object::POOF::Org->new( id => $self->{data}->{org_id}, 
	                               db => $self->{db}               );
      }
   } # otherwise I guess the user gets no org
   return 1;
}


sub find_user_by_email {
   # class method to return a user object found by searching uname/email
   # field for the passed fields 'replyto', 'from' and 'email' in that order
   my ($self,$p) = @_;  # is this appropriate for a class method?

   my ($db) = (defined $p->{db})
            ? $p->{db}
	    : Object::POOF::DB->new();
   my $org  = (defined $p->{org})
            ? $p->{org}
	    : undef;

   my $addr = undef;
   my @possible_emails = ();
   foreach $addr ($p->{replyto}, $p->{from}, $p->{email}) {
      push @possible_emails, $addr if (defined $addr);
   }
   return undef unless (defined $possible_emails[0]);

   my $id = undef;

   my $sql = qq#
      select u.id from users as u 
   #;
   if (defined $org) {
      if ($org->data->{share_users}) {
	 # find user by email where org_id matches org that shares users
         $sql .= qq#
	    , orgs as o
	    where o.share_users and o.id = u.org_id and ( 
	 #;
      } else {
         # find user by email where org_id matches this org id
	 $sql .= qq#
	    where u.org_id = #.$org->id.qq# and ( 
	 #;
      }
   } else {
      $sql .= qq#
         where (
      #;
   }
   my $i = undef;
   for $i (0 .. $#possible_emails ) {
      $addr = $possible_emails[$i];
      $sql .= qq#
         (u.uname = '$addr' or u.email = '$addr')
      #;
      $sql .= " or " unless ($i == $#possible_emails);
   }
   $sql .= " ) ";
   ($id) = $db->dbh->selectrow_array($sql);

   if (defined $id) {
      return Object::POOF::User->new( id => $id, db => $db );
   } else {
      return undef;
   }
}


sub add_to_group {
   # add the user to a particular group
   my ($self,$p) = @_;

   # make sure group exists 
   require Object::POOF::Group;  
   my $group = undef;
   if (defined $p->{name}) {
      $group = Object::POOF::Group->find({ name => $p->{name}, 
                                 org  => $self->org,
				 db   => $db         });
   }


   my $sql = qq#
      select count(name) from groups where name='#.$p->{group}.qq#'
   #;
   if ($self->org) {
      # assume that if the user has an org, add user to that org's group
      $sql .= qq# and #; #HRMMM
   }
   my ($exists) = $self->dbh->selectrow_array($sql);
   return undef unless ($exists);  # no need to croak or anything

   # no need to add to group if already a member
   $sql = qq#
      select count(id) from users_groups 
      where  user_id    = #.$self->id.qq#
        and  group_name = '#.$p->{group}.qq#'
   #;
   my ($count) = $self->dbh->selectrow_array($sql);
   return undef if ($count == 1);

   if ($count > 1) {
      # do some housekeeping... shouldn't be more than one relating entry
      $sql = qq#
         delete from users_groups
	 where  user_id    = #.$self->id.qq#
	   and  group_name = '#.$p->{group}.qq#'
      #;
      $self->dbh->do($sql);
      $count = 0;
   }
   if ($count == 0) {
      $sql = qq#
         insert into users_groups 
	 values (  0,
	           '#.$p->{group}.qq#',
		   #.$self->id.qq#
		)
      #;
      $self->dbh->do($sql);
   }
   return 1;  # OK
}

sub fullname {
   my ($self,$p) = @_;
   unless (defined $self->{fullname}) {
      my $fullname = $self->data->{firstname}." ".$self->{data}->{lastname};

      if ($self->{data}->{suffix}) { 
         $fullname .= ", ".$self->{data}->{suffix}; 
      }
      $self->{fullname} = $fullname;
   }
   return $self->{fullname};
}



sub set_passwd {
   my ($self,$p) = @_;
   return undef unless (defined $p->{passwd});
   my $sql = qq#
      update users set sha=sha($passwd) where id=#.$self->id.qq#
   #;
   $self->dbh->do($sql);
   return 1;
}

sub member_of_group {
   my ($self,$p) = @_;
   return undef unless ((defined $p->{group}) || (defined $p->{group_id}));
   my $group_id = (defined $p->{group_id})
                ? $p->{group_id}
		: $p->{group}->id;
   my $sql = qq#
      select count(id) from users_groups
      where group_id = $group_id
        and user_id  = #.$self->id.qq#
   #;
   my ($c) = $self->dbh->selectrow_array($sql);

   # could stick in some housekeeping code here to delete multiple entries
   # if $c >= 2, just in case

   return ($c > 0) ? 1 : 0;
}

sub member_of_org {
   my ($self,$p) = @_;
   return undef unless ((defined $p->{org}) || (defined $p->{org_id}));
   my $org_id = (defined $p->{org_id})
              ? $p->{org_id}
	      : $p->{org}->id;
   $self->data unless (defined $self->{data});
   return 1 if ($self->{data}->{org_id} == $org_id);

   # if not created for this org, check to see if shared w/ another org
   my $sql = qq#
      select count(id) from users_orgs 
      where org_id  = $org_id 
        and user_id = #.$self->id.qq#
   #;
   my ($c) = $self->dbh->selectrow_array($sql);

   # could stick in some housekeeping code here to delete multiple entries
   # if $c >= 2, just in case

   return ($c > 0) ? 1 : 0;
}



1;
