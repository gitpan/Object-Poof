#!/usr/bin/perl -Tw

use strict;
use warnings;
use Carp;
use English '-no-match-vars';
use YAML;

use lib qw( ../lib ./testlib );

use Test::More qw( no_plan );
use Test::Exception;

BEGIN {
use_ok( 'TestApp::DB' );
use_ok( 'TestApp::Poofone' );
}

diag( "Testing Object::POOF::X $Object::POOF::X::VERSION" );

my $db = TestApp::DB->new();
isa_ok($db, 'TestApp::DB');

# try to get a dbh handle:
my $dbh = undef;
eval {
    $dbh = $db->dbh;
};
SKIP: {
    if ($EVAL_ERROR) { 
        #diag($EVAL_ERROR);
        skip q{Cannot connect to database 'test'}, 3;
    }

    my $poofone = TestApp::Poofone->new({ db => $db });

    my $table;
    throws_ok 
        { $table = $poofone->table_of_field() }
        qr{empty fieldname passed to table_of_field}, 
         q{empty table_of_field() call caught?};

    throws_ok 
        { $table = $poofone->table_of_field('id') }
        qr{cannot lookup field 'id'}, 
         q{table_of_field('id') call caught?};

    throws_ok 
        { $table = TestApp::Poofone->table_of_field('bogus') }
        qr{called as class method},
         q{table_of_field() called as class caught?};


};


