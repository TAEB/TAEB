package TAEB::Action::Loot;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

use constant command => "#loot\n";

sub respond_loot_it { "y" }

# XXX is there ever a case where we'd want to put something in? our own bag
# that we've dropped, maybe?
sub respond_take_something_out { "y" }
sub respond_put_something_in { "n" }

subscribe got_item => sub {
    my $self  = shift;
    my $event = shift;

    # what about stacks?
    TAEB->send_message(remove_floor_item => $event->item, $self->starting_tile);
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

    if (my $container = TAEB->current_tile->container) {
        $container->locked(1);
    }
    else {
        TAEB->log->action("Got a locked message, but no container here!");
    }
}

sub begin_select_pickup {
    my $self = shift;
    my ($container) = @_;
    TAEB->announce('container_noitems', item => $container);
}

sub select_pickup {
    my $self = shift;
    my ($slot, $item, $container) = @_;
    $item = TAEB->new_item($item)
        or return;
    TAEB->send_message('container_item', $item, $container);
    TAEB->want_item($item);
}

sub is_impossible {
    return TAEB->is_levitating;
}

__PACKAGE__->meta->make_immutable;

1;
