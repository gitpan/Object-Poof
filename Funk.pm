package POOF::Funk;

use strict;
use Carp;
require POOF::DB;
use POOF::Data;

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
                        || (defined $self->{funk}) );
   return undef unless (defined $self->{db});

   $self->{table}      = "funk";

   if (not defined $self->{id}) {
      my $sql = qq#
         select id from funk where funk='#.$self->{funk}.qq#'
      #;
      $self->{id} = $self->dbh->selectrow_array($sql);
      #warn "Funk init got ".$self->{id}." as id from \n$sql";
   }
   return undef unless (defined $self->{id});
   
   return 1;
}

sub root {
   # find the root superfunk, or undef if this is a root funk
   my ($self,$p) = @_;

   #warn __PACKAGE__."->root\n";
   #warn "self->{root} is '".$self->{root}."'\n";

   unless (defined $self->{root}) {
      $self->data unless (defined $self->{data});

      #warn "finding self->{root}...\n";
      #warn "self->{data}->{superfunk_id} is '".$self->{data}->{superfunk_id}."'\n";
      unless (not defined $self->{data}->{superfunk_id}) {
         $self->{root} = undef;
         my $root = $self->superfunk;
         unless (not defined $root) {
            if (not defined $root->superfunk) {
               $self->{root} = $root;
            } else {
               do {
                  $root = $root->superfunk;
               } until (not defined $root->superfunk);
            }
         }
      }
   }
   return $self->{root};  # could be undef
}

sub group_auth {
   # does a group have auth to use this funk?
   my ($self,$p) = @_;
   return undef unless ((defined $p->{group}) || (defined $p->{group_id}));
   my $group_id = (defined $p->{group})
                ? $p->{group}->id
		: $p->{group_id};
   my $sql = qq#
      select count(id) from groups_funks 
      where funk_id  = #.$self->id.qq#
        and group_id = $group_id
   #;
   my ($c) = $self->dbh->selectrow_array($sql);

   # housekeeping code if c >= 2 could go here

   return ($c >= 1) ? 1 : undef;
}



#  these notes are old....
# 
# if a data shepherd passed a "root" as a funk, it populates
# a tree of funks in dimensions it finds.  because POOF::Data knows
# that Funks do not have a sub_id field, they are not a double-linked
# list that should be using only prev_id and next_id, and they are
# not a binary tree using left_id and right_id, or a double-linked
# binary tree using left_id, right_id and super_id.  so the routines
# sub (oh, sub is going to be a problem, how about up and down instead
# of super and sub.  The structure used by Funk Shepherds is not good
# for a larger structure, it is meant for things like HTML menus.
# To accomplish double-linked n-ary trees would require a one-to-many
# relational table called funk_funk ( id, up_funk_id, down_funk_id ).
# Then use a Shepherd:  @many = callOneToMany({ up => $funk });
# It doesn't matter what class 'up' is.  Shepherd returns undef if 
# the class passed doesn't have an 'up'.  Y
# ideally, Shepherd's functions should know whether the function is
# passing back into an array or a hash, and format accordingly 
# (sort by id's, or just build hash of id's)

# so, Shepherd will set values of the funk for {up}, {next} and {prev}
# as appropriate, maybe even compile an array for {down}, like a pseudo-"down",
# since table doesn't actually have fields.





1;
