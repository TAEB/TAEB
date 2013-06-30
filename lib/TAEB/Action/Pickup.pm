package TAEB::Action::Pickup;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

has count => (
    is       => 'ro',
    isa      => 'Int',
    provided => 1,
);

sub command { (shift->count || '') . ',' }

# the screenscraper currently handles this code. it should be moved here

subscribe got_item => sub {
    my $self  = shift;
    my $event = shift;

    # what about stacks?
    TAEB->send_message(remove_floor_item => $event->item, $self->starting_tile);
};

sub is_impossible {
    return TAEB->is_levitating;
}

__PACKAGE__->meta->make_immutable;

1;

