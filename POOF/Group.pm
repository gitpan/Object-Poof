package TT::Group;

use strict;
use Carp;
require TT::DB;
use TT::Data;


sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = { @_ };
   bless $self,$class;
   ($self->init) or return undef;
   return $self;
}

sub init {
   my ($self,$p) = @_;

   return undef unless (   (defined $self->{id}) 
                        || (  (defined $self->{name})
			   && (  (defined $self->{org})
			      || (defined $self->{org_id})
			)  )  );

   $self->{table}      = "groups";
   $self->{table_info} = "groups_info";

   $self->{db} = TT::DB->new() unless (defined $self->{db});

   if (not defined $self->{id}) {
      # first get the org obj
      require TT::Org;
      $self->{org} = TT::Org->new( id => $self->{org_id} ) 
         unless (defined $self->{org});

      # look group id up from name
      my $sql = qq#
         select id from groups 
	 where name='#.$self->{name}.qq#'
	   and org_id=#.$org->id.qq#
      #;
      $self->{$id} = $self->dbh->selectrow_array($sql);
   }

   return 1;
}

sub supergroup {
   # return the super (parent) group
   my ($self,$p) = @_;

   unless (defined $self->{super}) {

      $self->data unless (defined $self->{data});

      if ($self->{data}->{super_group_id}) {
         $self->{super} == TT::Group->new( 
	                      id => $self->{data}->{super_group_id},
			      db => $self->{db} );
      }
   }
   return $self->{super};
}

sub subgroups {
   my ($self,$p) = @_;
   unless (defined $self->{subgroups}) {
      $self->{subgroups} = [];
      my $sql = qq#
         select id from groups where super_group_id = #.$self->id.qq#
      #;
      my $sth = $self->dbh->prepare($sql);
      my $rc  = $sth->execute;
      while (my ($id) = $sth->fetchrow_array) {
         push @{$self->{subgroups}}, $id;
      }
   }
   return $self->{subgroups};
}

sub org {
   my ($self,$p) = @_;
   unless (defined $self->{org}) {
      return undef unless ($self->data->{org_id});
      require TT::Org;
      $self->{org} = TT::Org->new( org_id => $self->{data}->{org_id} );
   }
   return $self->{org};
}




sub add_user {
   my ($self,$p) = @_;
   return undef unless ((defined $p->{user}) || (defined $p->{user_id}));
   require TT::User;
   my $user = (defined $p->{user}) 
            ? $p->{user} 
	    : TT::User->new( user_id => $p->{user_id} );
   return undef unless ( $user->member_of_org({ org => $self->org }) );
   if ($user->member_of_group({ group => $self })) {
      return 1;
   } else {
      my $sql = qq#
         insert into users_groups (id, group_id, user_id) 
	 values (
	    0,
	    #.$self->id.qq#,
	    #.$user->id.qq#
	 )
      #;
      $self->dbh->do($sql) or return 0;
      return 1;
   }
}







1;
