#!/usr/bin/perl -Tw

use strict;
use warnings;
use Carp;
use English '-no-match-vars';
use YAML;

use lib qw( ../lib .);
#use blib;

use Test::More qw( no_plan );

BEGIN {
use_ok( 'Object::POOF::Constants' );
use_ok( 'Object::POOF::DB' );
use_ok( 'TestApp::DB' );
}

diag( "Testing Object::POOF::DB $Object::POOF::DB::VERSION" );

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

    # make sure dbh returns correct class
    isa_ok( $db->dbh(), 'DBI::db' );

    my ($two,$four) = $db->dbh()->selectrow_array(qq{
        SELECT 1 + 1 AS two, 2 * 2 AS four
    });

    ok( $two  == 2, 'SQL addition'          );
    ok( $four == 4, 'SQL multiplication'    );

    # well, the dbh seems to work like it should.
    # probably try some statement handle tests or something....
};


