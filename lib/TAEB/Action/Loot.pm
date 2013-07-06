package TAEB::Action::Loot;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

use constant command => "#loot\n";

has container => (
    is       => 'ro',
    isa      => 'NetHack::Item::Tool::Container',
    required => 1,
);

sub respond_loot_it { "y" }

# XXX is there ever a case where we'd want to put something in? our own bag
# that we've dropped, maybe?
sub respond_take_something_out { "y" }
sub respond_put_something_in { "n" }

subscribe got_item => sub {
    my $self  = shift;
    my $event = shift;

    # what about stacks?
    # XXX make into announcement
    $self->container->remove_item($event->item);
};

# better place for these?
subscribe container_noitems => sub {
    my $self = shift;
    my ($event) = @_;

    $event->item->contents([]);
    $event->item->contents_known(1);
};

sub msg_container_item {
    my $self = shift;
    my ($item, $container) = @_;

    $container->add_item($item) if $item;
}

sub msg_container_locked {
    my $self = shift;
    $self->container->locked(1);
}

sub is_impossible {
    return TAEB->is_levitating;
}

__PACKAGE__->meta->make_immutable;

1;
