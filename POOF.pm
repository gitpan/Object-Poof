package Object::POOF;

# Anything generic to every object should be done here.
# Then, any special Object::POOF::SomeObject should inherit this,
# and any MyApp::OtherObject should inherit/construct as this.

use strict;
use warnings;
use Carp;
use Object::POOF::Data;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = { @_ };
	$self->{class} = $class;
	bless $self,$class;
	($self->init) or return undef;
	return $self;
}

sub init {
	my $self = shift;
	return 1;
}


1;

=head1 NAME

Object::POOF - Perl Object-Oriented Framework

=head1 SYNOPSIS

 package MyApp::Model;
 require Object::POOF;
 @ISA = qw( Object::POOF );
 
 sub init {
    my $self = shift;
    $self->{table}      = "model";       # quick database table
    $self->{table_info} = "model_info";  # suppl. info table
    $self->SUPER::init;                  # call parent init
    # other custom setup...
    return 1;
 }
 
 sub some_method {
    my ($self,$p) = @_;
    my $var1 = $p->{var1};
    my $var2 = $p->{var2};
    # do something....
    return;
 }
 
 package main;
 require MyApp::Model;
 require MyApp::DB;  # see Object::POOF::DB;
 my $model = MyApp::Model->new(   id      => $id;
                                  prop2   => "val2",
                                  db      => $db   );
 print $model->id."\n";
 print $model->data->{quick_dbfield1}."\n";
 print $model->{data}->{quick_dbfield2}."\n";    # cached data values
 print $model->data_info->{info_dbfield1}."\n";  # suppl. info data
 
 $model->{save}->{quick_dbfield1}       = "new_value1";
 $model->{save_info}->{info_dbfield1}   = "new_value2";
 $model->save;
 $model->commit;
 
 $model->data;   # re-select and re-cache new data values
 
 # MyApp::DB object can be passed around as a shared transaction thread
 # or a new MyApp::DB object can be created for independent transactions.
    
 my $newmodel = MyApp::Model->new( db => $db );      # autoinserts id
 $newmodel->{save}->{quick_dbfield1} = "new_value1";
 $newmodel->save;
 $newmodel->commit;   # or $newmodel->rollback;
 
=head1 DESCRIPTION

Perl Object-Oriented Framework attempts to provide an easier way
to construct and deal with objects that map to entries in a database.
To define a new class of object, in the example MyApp::Model, simply
create tables in the database named "model" and "model_info".

Object::POOF and related classes require some conventions to be
adhered to in order to reduce work and make object interfaces consistent.

An object package inheriting from Object::POOF need not define a constructor,
instead, the generic Object::POOF constructor is inherited and used.

An object package inheriting from Object::POOF must declare a method 'init',
which must first define the names of the tables associated with the object,
and then calls SUPER::init, that is, Object::POOF::init().  (Right now this
isn't used for anything, but it may be, so it should be called.)

The init() method MUST ALWAYS RETURN 1 UPON SUCCESS, otherwise the
object will not be created and the inherited constructor will return undef.

An object package inheriting from Object::POOF also imports a wide array
of data functions from Object::POOF::Data.  These are designed to reduce
the amount of work necessary to extract data from the database tables and
to insert or replace data.  Object::POOF::Data uses some nifty magic
from Object::POOF::DB::Fields to determine whether these values should
be quoted as strings or not, so you don't have to worry about it... just
save whatever data you want and it should take care of it.  If it is an
incorrect data type (for example, a string saved to a numeric-type field),
it will just ignore that field.

The object also gets the ability to call or create Shepherds
(Object::POOF::Data::Shepherd), a machine class object that can 
find an instance of a given object based on field search criteria,
or instantiate herds of objects from search criteria that can then
be compared, crossed, ordered, etc.

=head1 SEE ALSO

Object::POOF::Data(3),
Object::POOF::Data::Shepherd(3),
Object::POOF::DB(3),
Object::POOF::App(3),
Object::POOF::User(3)

=head1 AUTHOR

Copyright 2005 Mark Hedges E<lt>hedges@ucsd.eduE<gt>, CPAN: MARKLE

Released under the standard Perl license (GPL/Artistic).

=cut
