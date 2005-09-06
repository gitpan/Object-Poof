#!perl -T

use Test::More;
eval "use Test::Pod 1.14";
plan skip_all => "Test::Pod 1.14 required for testing POD" if $@;

my @poddirs = qw( ../lib );
all_pod_files_ok( all_pod_files( @poddirs ) );
