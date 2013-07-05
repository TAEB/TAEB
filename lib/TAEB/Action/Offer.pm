package TAEB::Action::Offer;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item';

use constant command => "#offer\n";

has '+item' => (
    required => 1,
);

has did_sacrifice => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub respond_sacrifice_ground {
    my $self = shift;
    my $floor = shift;
    my $floor_item = TAEB->current_tile->find_item_maybe($floor);

    if ($self->item == $floor_item) {
        return 'y';
    }

    return 'n';
}

sub respond_sacrifice_what {
    my $self = shift;

    if (defined $self->item->slot) {
        return $self->item->slot;
    }

    TAEB->send_message(check => 'inventory');
    TAEB->send_message(check => 'floor');
    return "\e\e\e";
}

sub msg_sacrifice_gone {
    my $self = shift;
    my $item = $self->item;

    if ($item->slot)  {
        TAEB->inventory->decrease_quantity($item->slot)
    }
    else {
        #This doesn't work well with a stack of corpses on the floor
        #because maybe_is used my remove_floor_item tries to match quantity
        TAEB->send_message(remove_floor_item => $item);
    }

    $self->did_sacrifice(1);
}

sub done {
    my $self = shift;

    return if $self->did_sacrifice;

    $self->item->failed_to_sacrifice(1);
}

__PACKAGE__->meta->make_immutable;

1;

