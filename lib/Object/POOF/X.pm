# supermagic all-inclusive exceptions package

package Object::POOF::X;
use version; $VERSION = qv('0.0.6');

use strict;
use warnings;

use Exception::Class (

    'Object::POOF::X::DB' => {
        fields      => [ qw( message errstr config ) ],
        description => 'A general Object::POOF::DB error message.',
    },

    'Object::POOF::X::DB::STH'          => {
        isa         => 'Object::POOF::X::DB',
        description => 'Errors when obtaining a DBI sth.',
    },

    'Object::POOF::X::DB::Do'           => {
        isa         => 'Object::POOF::X::DB',
        description => 'Errors when using DBI do().',
    },

    'Object::POOF::X' => {
        fields      => [ qw( message class ) ],
        description => 'A general Object::POOF error message.',
    },

);

# the 'stringify' error messages for the above classes:

sub Object::POOF::X::DB::STH::full_message {
    my ($self) = @_;

    # should I also call finish() for the sth?

    return qq{Object::POOF::DB::sth() error:\n}
        . qq{Message: } . $self->message()      .qq{\n}
        . $self->errstr()                       . qq{\n---\n};
}

sub Object::POOF::X::DB::Do::full_message {
    my ($self) = @_;

    return qq{Object::POOF::DB::query() error:\n}
        . qq{Message: } . $self->message()      . qq{\n}
        . qq{Errstr: }  . $self->errstr()       . qq{\n---\n};
}

sub Object::POOF::X::DB::full_message {
    my ($self) = @_;
    use YAML;
    return qq{Object::POOF::DB general error:\n}
        .  $self->message()                     . qq{\n}
        .  q{errstr: }  . $self->errstr()       . qq{\n}
        . qq{config: }                          . qq{\n}
        . Dump($self->config());
}

sub Object::POOF::X::full_message {
    my ($self) = @_;
    return qq{Object::POOF exception:\n}
        . q{INHERITING CLASS: } . $self->class(). qq{\n}
        . $self->message()                      . qq{\n}
}


1;
