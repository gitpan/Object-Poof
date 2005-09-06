#!/usr/bin/perl -Tw

use strict;
use warnings;
use Carp;
use English '-no-match-vars';
use YAML;

use lib qw( ../lib ./testlib );

use Test::More qw( no_plan );

BEGIN {
    use_ok( 'Object::POOF' );
    use_ok( 'TestApp::DB' );

    use_ok( 'TestApp::Poofcontainer' );
    use_ok( 'TestApp::Poofone' );
    use_ok( 'TestApp::Poofthing' );
}
# it's lame but i have to redefine the list here, i can't share w/ BEGIN
my @test_entity_classes = qw(
    TestApp::Poofcontainer  
    TestApp::Poofone    
    TestApp::Poofthing
);

diag( "Testing Object::POOF $Object::POOF::VERSION" );


#my %relatives = %TestApp::Poofcontainer::relatives;
#diag(Dump(%relatives));

my $db = TestApp::DB->new();
#isa_ok($db, 'TestApp::DB');

SKIP: {
    # try to get a dbh handle:
    my $dbh = undef;
    eval { $dbh = $db->dbh };
    #diag($EVAL_ERROR) if ($EVAL_ERROR);

    skip q{Cannot connect to database 'test'}, 1 if ($EVAL_ERROR);

    # okay, first make sure all tables are dropped:
    drop_all_tables();

    # create the tables:
    create_all_tables();

    $db->commit();

    # here i could run 'show tables' and make sure output is right

    # now try constructing objects of our TestApp

    #my $poofcontainer = TestApp::Poofcontainer->new();
    my $poofone = TestApp::Poofone->new({ db => $db });
    my $table = $poofone->table_of_field('tstamp');
    ok($table eq 'poofone_other', 'table_of_field() method');

    my $desc = $db->poofone_other;
    #diag(Dump($desc));

};

sub create_all_tables {
    foreach my $class (@test_entity_classes) {
        foreach my $table_def ($class->table_definitions()) {
            #diag("table def is '$table_def'");
            eval { $db->do($table_def) };
            #diag($EVAL_ERROR) if ($EVAL_ERROR);
        }
    }
}

sub drop_all_tables {
    foreach my $class (@test_entity_classes) {
        #my @tables = $class->all_tables();
        #diag("dropping tables for $class\n");

        # unfortunately i have to do this in order
        # because of foreign key constraints?
        eval { $db->do("set foreign_key_checks=0") };
        #diag($EVAL_ERROR) if ($EVAL_ERROR);
        foreach my $table ($class->all_tables()) {
            #diag("deleting table $table");
            eval { $db->do("drop table $table") };
            #diag($EVAL_ERROR) if ($EVAL_ERROR);
        }
        eval { $db->do("set foreign_key_checks=1") };
        #diag($EVAL_ERROR) if ($EVAL_ERROR);
    }
}

