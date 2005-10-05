# supermagic all-inclusive exceptions pkg.
# this way, you can always check:
#   if (my $e = Exception::Class->caught('Object::POOF::X')) { ... }

package Object::POOF::X;
use version; $VERSION = qv('0.0.6');

use strict;
use warnings;
use English;

use YAML;
use Carp qw( carp cluck croak confess longmess );
use Text::Wrap;
$Text::Wrap::columns = 72;

use Object::POOF::Constants;

use Exception::Class (

    'Object::POOF::X' => {
        fields      => [ qw( 
            class params
        ) ],
        description => 'A general Object::POOF error message.',
    },

    'Object::POOF::X::DB' => {
        isa         => 'Object::POOF::X',
        fields      => [ qw( 
            errstr config 
        ) ],
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

    'Object::POOF::X::DataType' => {
        isa         => 'Object::POOF::X',
        fields      => [ qw( 
            class table field value field_info 
        ) ],
        description => 'A report of a bad value used for the field datatype.',
    },

    'Object::POOF::X::SQL' => {
        isa         => 'Object::POOF::X',
        fields      => [ qw( 
            table field value 
        ) ],
        description => 'A report of a bad value used for the field datatype.',
    },
);

# the 'stringify' error messages for the above classes:

sub Object::POOF::X::DB::full_message {
    my ($self) = @_;

    my $params  = $self->params();
    my $errstr  = $self->errstr();
    my $config  = $self->config();

    my $message = $self->message();

    $message =   ref($self).qq{ error:\n'$message'\n};

    $message .= qq{params:          }.Dump($params)             if ($params);

    $message .= qq{errstr: $errstr\n}                           if $errstr;

    $message .= qq{config:          }.Dump($config).qq{\n}      if $config;

    $message .= qq{in package:      }.$self->package();
    $message .= qq{at line:         }.$self->line();

    my $autocluck = longmess(qq{auto-cluck from throw:\n});
    $autocluck = wrap( q{}, q{            }, $autocluck );

    $message .= qq{autocluck:\n$autocluck\n};

    return $message;
}

sub Object::POOF::X::full_message {
    my ($self) = @_;

    my $message = $self->message();
    #cluck "initial message is '$message'";

    $message =   ref($self).   qq{ error:\n$message\n};

    my $params  = $self->params();
    my $class   = $self->class();
    my $table   = $self->table();
    my $field   = $self->field();
    my $value   = $self->value();

    #carp("kalooga '$message'");
    #carp("err self isa \n---\n", ref $self, "\n---");
    $message    .= qq{params:       }.Dump($params)     if ($params);
    $message    .= qq{in package    }.$self->package();
    $message    .= qq{at line       }.$self->line();
    $message    .= qq{obj of class  $class\n}           if ($class);
    $message    .= qq{for table     $table\n}           if ($table);
    $message    .= qq{      field   $field\n}           if ($field);
    $message    .= qq{      value   $value\n}           if ($value);

    my $autocluck = longmess(qq{auto-cluck from throw:\n});
    $autocluck = wrap( q{}, q{            }, $autocluck );

    $message .= qq{autocluck:\n$autocluck\n};

    return $message;

}

sub Object::POOF::X::DataType::full_message {
    my ($self) = @_;

    return  qq{Object::POOF::X::DataType exception:\n}
        .   $self->message()                        .qq{\n}
        .   qq{class:       '}  .$self->class()     .qq{'\n}
        .   qq{table:       '}  .$self->table()     .qq{'\n}
        .   qq{field:       '}  .$self->field()     .qq{'\n}
        .   qq{value:       '}  .$self->value()     .qq{'\n}
        .   qq{field info:\n}
        .   Dump($self->field_info())               .qq{\n};
}


1;
