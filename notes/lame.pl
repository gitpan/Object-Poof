#!/usr/bin/perl


package Lazy::Call;

sub new {
    my ($class, $real_obj, @calls) = @_;
    print "in Lazy::Call->new(): real_obj: $real_obj, calls '@calls'\n";
    return bless { real_obj => $real_obj, calls => \@calls }, $class;
}

sub AUTOLOAD {
    my ($self) = @_;
    print "in AUTOLOAD, = '$AUTOLOAD'\n";
    $AUTOLOAD =~ s/.*:://;
    print "\t=~ '$AUTOLOAD'\n";
    #push @{$self->{calls}}, $AUTOLOAD;
    #return $self;

    my $call = Lazy::Call->new($self,$AUTOLOAD);
    return $call;
}

sub DESTROY {
    my ($self) = @_;

    # Replace this code with the actual look-ahead and processing...
    use Data::Dumper;
    print "Now able to lookahead on calls to: $self->{real_obj}\n",
        "Calls were:\n",
        Dumper $self->{calls};
    print "caller was '".join(',',caller())."'\n";

    return 'retval from DESTROY';
}

package Foo;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub bar {
    my ($self) = @_;

    print "in Foo::Bar()\n";
    return Lazy::Call->new($self, 'bar');
}

package main;

my $foo = Foo->new();

print "beef.\n";

my $retval = $foo->bar->biz->baz;

print "retval = '$retval'\n";


