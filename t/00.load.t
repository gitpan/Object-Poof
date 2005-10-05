#!/usr/bin/perl

use lib qw( ../lib .);
#use blib;

use Test::More qw( no_plan ); #tests => 16;

BEGIN {
use_ok( 'Object::POOF' );
use_ok( 'Object::POOF::App' );
use_ok( 'Object::POOF::App::Session' );
use_ok( 'Object::POOF::Constants' );
use_ok( 'Object::POOF::DB' );
use_ok( 'Object::POOF::Funk' );
use_ok( 'Object::POOF::User' );
use_ok( 'Object::POOF::SQL' );
use_ok( 'Object::POOF::SQL::Select' );
use_ok( 'Object::POOF::SQL::Save' );
use_ok( 'Object::POOF::Shepherd' );
use_ok( 'Object::POOF::Ranch' );

use_ok( 'TestApp::DB' );
use_ok( 'TestApp::Poofone' );
use_ok( 'TestApp::Poofcontainer' );
use_ok( 'TestApp::Poofthing' );
use_ok( 'TestApp::Poofhabitat' );
}

diag( "Testing Object::POOF $Object::POOF::VERSION" );
