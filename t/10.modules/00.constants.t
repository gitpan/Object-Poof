#!/usr/bin/perl -Tw

use strict;
use warnings;

use lib qw( ../lib ./testlib );

use Test::More qw( no_plan );

BEGIN {
use_ok( 'Object::POOF::Constants' );
}

diag( "Testing Object::POOF::Constants $Object::POOF::Constants::VERSION" );

ok( $EMPTY_STR eq q{}, '$EMPTY_STR' );
