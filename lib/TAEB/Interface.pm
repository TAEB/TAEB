package TAEB::Interface;
use Moose;
use TAEB::OO;

has min_read_iterations => (
    is      => 'ro',
    isa     => 'Int',
    default => 1,
);

has max_read_iterations => (
    is      => 'ro',
    isa     => 'Int',
    default => 3,
);

sub read { ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;

    my $input = '';
    for my $iter (1..$self->max_read_iterations) {
        my $output = inner();
        $input .= defined $output ? $output : '';
        last if $iter >= $self->min_read_iterations && length($input);
    }

    TAEB->log->log_to_channel(
        input => "Received '$input' from NetHack.",
        (length($input) ? () : (level => 'warning')),
    );
    return $input;
}

sub write { ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;
    my $text = join '', @_;

    return if !defined($text) || length($text) == 0;

    TAEB->log->log_to_channel(output => "Sending '$text' to NetHack.");

    inner();
}

sub flush { }

sub wait_for_termination { }

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::Interface - how TAEB talks to NetHack

=head1 METHODS

=head2 read -> STRING

This will read from the interface. It's quite OK to block and throw errors
in this method.

It should just return the string read from the interface.

Your subclass B<must> override this method.

=head2 write STRING, STRING, ...

This will write to the interface. It's quite OK to block and throw errors
in this method. Your subclass will receive potentially many strings as
arguments, it's vital to handle all of them
(by joining them together with C<join ''>)

Its return value is currently ignored.

Your subclass B<must> override this method.

=head2 flush

This causes a call to write() to take effect, if for some reason your
interface delays writes until the corresponding read. You can leave
this un-overriden if it would be a no-op. It's allowed to discard any
data it would otherwise read; this is for the purpose of ensuring that
the data is sent during emergency cleanup.

=head2 wait_for_termination

This is an optional override, which should be implemented on those
interfaces which run NetHack as a process themselves, rather than
connecting to someone else's NetHack process over a network, for
instance. Its purpose is to handle any errors NetHack may encounter
when trying to save your game and/or save the high-score table; this
is important because otherwise, the NetHack process itself can leave
NetHack's internals in a mess, requiring recover to be run, or even
preventing any updates to the high-score table until an administrator
can fix NetHack's playfield.

=cut

