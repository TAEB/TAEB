package TAEB::AI::PickupDrop;
use Moose;
use TAEB::OO;
extends 'TAEB::AI';

has dropping => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

sub next_action {
    my $self = shift;

    if ($self->dropping) {
        my @items = TAEB->inventory_items;
        if (@items) {
            return TAEB::Action::Drop->new(items => [$items[0]]);
        }
        else {
            $self->dropping(0);
            # fall through to search
        }
    }
    else {
        my @items = TAEB->current_tile->items;
        if (@items) {
            return TAEB::Action::Pickup->new;
        }
        else {
            $self->dropping(1);
            # fall through to search
        }
    }

    TAEB::Action::Search->new(iterations => 1);
}

subscribe query_pickupitems => sub {
    my $self  = shift;
    my $event = shift;

    my @items = $event->all_menu_items;
    my $item = $items[rand @items];

    $item->selected(1);
    $item->quantity('all');
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::AI::SteadyState - Sit there doing nothing, for benchmarking purposes

=cut


