use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Object::POOF',
    AUTHOR              => 'Mark Hedges <hedges@ucsd.edu>',
    VERSION_FROM        => 'lib/Object/POOF.pm',
    ABSTRACT_FROM       => 'lib/Object/POOF.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Object-POOF-*' },
);
