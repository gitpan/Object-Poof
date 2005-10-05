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
    use_ok( 'Object::POOF::SQL' );
}

diag( "Testing Object::POOF::SQL $Object::POOF::SQL::VERSION" );

my $sql = undef;

lives_ok 
    { $sql = Object::POOF::SQL->new() }   
    'construct empty sql object.';

throws_ok
    {   $sql = Object::POOF::SQL->new({
            where_pairs => 'blah blah',
        })
    }
    qr{bad params},
    'should throw error with bad param types';

lives_ok
    {   $sql = Object::POOF::SQL->new({
            where_pairs => [ 
                qq{ beef = 'horta' },
                qq{ chicken = NULL },
                qq{ horta = 'bacon' },
            ]
        })
    }
    'optionally set things in constructor';

my $sql_as_str = undef;
throws_ok
    {   $sql_as_str = qq{$sql} }
    qr{no action set},
    'stringify sql w/o action.';

lives_ok
    {   $sql->set_action("BOGUS ACTION")    }
    'set bogus action';

lives_ok
    {   $sql_as_str = qq{$sql} }
    'stringify.';

    diag($EVAL_ERROR) if $EVAL_ERROR;

    diag("sql_as_str: \n---\n$sql_as_str\n---");



#diag(qq{sql is a '$sql'});
