package Object::POOF::SQL;

use version; $VERSION = qv('0.0.1');

use warnings;
use strict;
use Carp qw( carp cluck confess croak );
use English '-no_match_vars';
use Exception::Class;
use YAML;

use Object::POOF::X;
use Object::POOF::Constants;

# Other recommended modules (uncomment to use):
#  use IO::Prompt;
#  use Perl6::Export;
#  use Perl6::Slurp;
#  use Perl6::Say;
#  use Regexp::Autoflags;

# Module implementation here

use Class::Std;
{
    my %what_of         :ATTR( :get<what>                   );
    my %update_pairs_of :ATTR( :get<update_pairs>           );
    my %where_pairs_of  :ATTR( :get<where_pairs>            );
    my %from_of         :ATTR( :get<from>                   );
    my %joins_of        :ATTR( :get<joins>                  );
    my %order_of        :ATTR( :get<order>                  );
    
    my %action_of       :ATTR( :get<action>   :set<action>  );

    sub BUILD {
        my ($self, $ident, $arg_href) = @_;

        # check for bad params:
        map {
            if  (   exists $arg_href->{$_}
                &&  ref $arg_href->{$_} ne 'ARRAY'
                ) {
                Object::POOF::X::SQL->throw(
                    message =>  qq{BUILD: bad params: }
                            .   Dump($arg_href)
                            .   qq{---},
                );
            }
        } qw( what update_pairs where_pairs from joins );

        # if parms passed optionally set them:

        if (exists $arg_href->{what}) {
            map { $what_of{$ident}->{$_}         => 1 }
                @{ $arg_href->{what} };
        }
        if (exists $arg_href->{update_pairs}) {
            map { $update_pairs_of{$ident}->{$_} => 1 }
                @{ $arg_href->{update_pairs} };
        }
        if (exists $arg_href->{where_pairs}) {
            map { $where_pairs_of{$ident}->{$_} = 1 }
                @{ $arg_href->{where_pairs} };
        }
        if (exists $arg_href->{from}) {
            map { $from_of{$ident}->{$_}         => 1 }
                @{ $arg_href->{from} };
        }
        if (exists $arg_href->{joins}) {
            map { $joins_of{$ident}->{$_}        => 1 }
                @{ $arg_href->{joins} };
        }
        if (exists $arg_href->{order}) {
            map { $order_of{$ident}->{$_}        => 1 }
                @{ $arg_href->{order} };
        }
        if (exists $arg_href->{action}) {
            $action_of{$ident}          = $arg_href->{action};
        }

    }

    sub add_update_pair {
        my ($self, $pair) = @_;
        croak("bad pair to add_update_pair") if (ref $pair);
        $update_pairs_of{ ident($self) }->{$pair} = 1;
        return;
    }

    sub add_what {
        my ($self, $field) = @_;
        $what_of{ ident($self) }->{$field} = 1;
        return;
    }

    sub add_where_pair {
        my ($self, $pair) = @_;
        croak("bad pair to add_where_pair") if (ref $pair);
        $where_pairs_of{ ident($self) }->{$pair} = 1;
        return;
    }

    sub add_from {
        my ($self, $from) = @_;
        $from_of{ ident($self) }->{$from} = 1;
        return;
    }

    sub add_join {
        my ($self, $join) = @_;
        $joins_of{ ident($self) }->{$join} = 1;
        return;
    }

    sub add_order {
        my ($self, $order) = @_;
        $order_of{ ident($self) }->{$order} = 1;
        return;
    }

    sub sql : STRINGIFY {
        my ($self) = @_;
        my $ident = ident($self);

        my $sql = $action_of{$ident};

        if (!$sql) {
            Object::POOF::X::SQL->throw(
                error => qq{no action set for this sql statement.},
            );
        }

        my @where_pairs     = keys %{ $where_pairs_of{  $ident  } };
        my @update_pairs    = keys %{ $update_pairs_of{ $ident  } };
        my @what            = keys %{ $what_of{         $ident  } };
        my @from            = keys %{ $from_of{         $ident  } };
        my @joins           = keys %{ $joins_of{        $ident  } };
        my @order           = keys %{ $order_of{        $ident  } };

        # if they specify the wrong ones, their execute will bomb
        # and they will know -- this package doesn't need to check.
        # it's just a brainless aggregator.

        $sql .= join(qq{ ,\n    }, @what);
        $sql .= join(qq{ ,\n    }, @update_pairs);

        if (scalar @from) {
            $sql .= qq{\nFROM \n}
                .   join(qq{ ,\n    }, @from);
        }

        if (scalar @joins) {
            $sql .= join(qq{\n}, @joins);
        }

        if (scalar @where_pairs) {
            $sql .= qq{\nWHERE \n      }
                .   join(qq{\nAND   }, @where_pairs);
        }

        if (scalar @order) {
            $sql .= qq{\nORDER BY \n}
                .   join(qq{ ,\n    }, @order);
        }

        return $sql;
    }
}





1; # Magic true value required at end of module
__END__

=head1 NAME

Object::POOF::SQL - [One line description of module's purpose here]


=head1 VERSION

This document describes Object::POOF::SQL version 0.0.1


=head1 SYNOPSIS

    use Object::POOF::SQL;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Object::POOF::SQL requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-object-poof-sql@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Mark Hedges  C<< <hedges@ucsd.edu> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, Mark Hedges C<< <hedges@ucsd.edu> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
