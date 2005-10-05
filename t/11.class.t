#!/usr/bin/perl -Tw

use strict;
use warnings;
use Carp;
use English '-no-match-vars';
use YAML;
use Scalar::Util;

use lib qw( ../lib .);
#use blib;

use Test::More qw( no_plan );

BEGIN {
use_ok( 'TestApp::DB' );
use_ok( 'TestApp::Poofone' );
use_ok( 'TestApp::Poofthing' );
use_ok( 'TestApp::Poofcontainer' );
}

diag( "Testing Object::POOF class methods $Object::POOF::VERSION" );

my $db = TestApp::DB->new();

my $class = 'TestApp::Poofone';

# test all_tables by class method:
my @all_tables = $class->all_tables();
eq_array( \@all_tables, [ qw( poofone poofone_text poofone_other ) ] );


my $poofone = TestApp::Poofone->new({ db => $db });
@all_tables = $poofone->all_tables();
eq_array( \@all_tables, [ qw( poofone poofone_text poofone_other ) ] );

# also test a package that has no more_tables, then try to reassign it
my @test_one_table = TestApp::Poofthing->all_tables;
eq_array( \@all_tables, [ qw( poofthing ) ] );
eval {
    no warnings 'once';  # it's the first time seen here, but it is in there.
    @TestApp::Poofthing::more_tables = qw( foo bar baz );
};
like(
    $EVAL_ERROR, 
    qr{Modification of a read-only value attempted}, 
    q{shouldn't be able to reassign internal more_tables value.}
);
# could write other tests for the other Readonly values that
# might have been stuck in by Object::POOF::Class....



# test relatives:

my $relatives_class_href = TestApp::Poofcontainer->relatives_href();
#diag("ref is '", ref $relatives_class_href, "'");
ok(
    ref($relatives_class_href) eq 'HASH', 
    q{relatives returns href in scalar context?}
);

my %relatives_class = %{ TestApp::Poofcontainer->relatives_href() };
my $poofcontainer = TestApp::Poofcontainer->new({ db => $db });
my %relatives_obj = %{ $poofcontainer->relatives_href() };

eq_hash(\%relatives_class, \%relatives_obj);

#diag(Dump(%relatives_class));


# test child_rootname:

my $child_rootname_1 = $poofone->child_rootname;
my $child_rootname_2 = $poofcontainer->child_rootname;

ok( 
    $child_rootname_1 eq 'TestApp',
    q{child_rootname eq 'TestApp'} 
);
ok( 
    $child_rootname_1 eq $child_rootname_2,   
    q{child_rootname eq across packages} 
);








