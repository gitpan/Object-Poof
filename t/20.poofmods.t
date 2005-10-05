#!/usr/bin/perl -Tw

$| = 1;

use strict;
use warnings;
use Carp;
use English '-no-match-vars';
use YAML;

use lib qw( ../lib .);
#use blib;

use Test::More qw( no_plan );
use Test::Exception;

BEGIN {
    use_ok( 'Object::POOF' );
    use_ok( 'TestApp::DB' );

    use_ok( 'TestApp::Poofcontainer' );
    use_ok( 'TestApp::Poofone' );
    use_ok( 'TestApp::Poofthing' );
    use_ok( 'TestApp::Poofhabitat' );
}
# it's lame but i have to redefine the list here, i can't share w/ BEGIN
my @test_entity_classes = qw(
    TestApp::Poofcontainer  
    TestApp::Poofone    
    TestApp::Poofthing
    TestApp::Poofhabitat
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

    lives_ok
        { $db->check_save_pair( $poofone, 'enumerated', 'two' ) }
        'check_save_pair unexpectedly returned exception.';
    lives_ok
        { $db->check_save_pair( $poofone, 'enumerated', 1 ) }
        'check_save_pair unexpectedly returned exception.';

    # try passing a bad primary key to a new object.
    throws_ok { 
        my $badidtest = TestApp::Poofone->new({ 
            db          => $db, 
            primary_key => {
                id  => 9999999,
            },
        });
    }   qr{new\(\) could not verify_pk},
        'bad id passed should have thrown exception.';

    throws_ok {
        my $badsavetest = TestApp::Poofone->new({
            db      => $db,
            save    => {
                bogus => 'bogus',
            },
        })
    }   qr{could \s not \s find \s field \s bogus \s in \s its \s tables}xms,
        'bad save param passed to new() should have thrown exception.';
    #warn "badsavetest err was \n---\n$EVAL_ERROR\n---";


    use DateTime;
    use DateTime::Format::MySQL;
    my $now = DateTime->now();
    my $reagan = DateTime->new( year => '1987' );

    # now try saving something valid... lookup some unicodes for these...
    my $save = {
        # in poofone_text:
        char_one        => q{abcdefgh},
        char_two        => q{jeokjfkldsjf 'horta' kl" ""ajfkld;sajfklds;a},
        vchar_one       => q{329sdf9},
        vchar_two       => q{h}x50 . q{i}x50 . q{j}x50,
        text_one        => q{horta},
        text_two        => q{Spock!  Spock!},

        # in poofone_other:
        enumerated      => q{two},
        set_field       => [ qw( uno tres ) ],
        byte            => pack('a', q{J}),
        vbin            => pack('a', q{JXYZ}),
        dt_tm           => $now,
        dt              => $reagan,
        tstamp          => $now,
        tm              => $now,
        yr              => $reagan,
        flt             => '39394.392e15',
        dbl             => '32304039.383294342e19',
        dcml            => 32949249.394,
        intgr           => 3923940,
        zipcode         => 3924,
    };

    lives_ok {
        $poofone = TestApp::Poofone->new({
            db      => $db,
            save    => $save,
        });
        $poofone->save();
        $poofone->commit();
    } q{Created poofone.};
    diag(qq{save() EVAL_ERROR was '$EVAL_ERROR'});

    skip q{Skipping the rest}, 1;

    # got to get poofone id to save in poofcontainer later.
    # so, what should happen here is the following:
    #
    #   try to just find the field in $data.  can't find it.
    #   because is primary key, skip fetch_hash to database - don't know it.
    #   because it is the primary key and is autoincrement, call save?
    #
    my $poofone_id = '';
    lives_ok {
        $poofone_id = $poofone->id;
    } q{Got poofone_id.};
    diag("...got poofone_id '$poofone_id'");

    my ($poofcontainer, $poofhabitat, $poofthing) = (undef)x3;
    throws_ok {
        $poofcontainer = TestApp::Poofcontainer->new({
            db      => $db,
            save    => $save,
        });
    } qr{check_save_pair for .*? could not find},  
        q{Created poofcontainer with bad save.};

    lives_ok {
        # create poofcontainer - a cage for a thing from the habitat:
        $poofcontainer = TestApp::Poofcontainer->new({
            db      => $db,
            save    => {
                
            },
        });
        
    }   q{Created poofcontainer, poofhabitat, poofthing.}
    

    # the last thing to do is drop all tables again
    #drop_all_tables();
};

sub create_all_tables {
    eval { $db->do("set foreign_key_checks=0") };
    foreach my $class (@test_entity_classes) {
        foreach my $table_def ($class->table_definitions()) {
            #diag("table def is '$table_def'");
            eval { $db->do($table_def) };
            diag($EVAL_ERROR) if ($EVAL_ERROR);
        }
    }
    eval { $db->do("set foreign_key_checks=1") };
}

sub drop_all_tables {
    eval { $db->do("set foreign_key_checks=0") };
    foreach my $class (@test_entity_classes) {
        #my @tables = $class->all_tables();
        #diag("dropping tables for $class\n");

        # unfortunately i have to do this in order
        # because of foreign key constraints?
        #diag($EVAL_ERROR) if ($EVAL_ERROR);
        foreach my $table ($class->all_tables()) {
            #diag("deleting table $table");
            eval { $db->do("drop table $table") };
            #diag($EVAL_ERROR) if ($EVAL_ERROR);
        }
        diag($EVAL_ERROR) if ($EVAL_ERROR);
    }
    eval { $db->do("set foreign_key_checks=1") };
}

