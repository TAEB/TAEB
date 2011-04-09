package TAEB::Action::Eat;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item' => { items => [qw/food/] };

use constant command => "e";

has '+food' => (
    required => 1,
);

sub respond_eat_ground {
    my $self = shift;
    my $floor = shift;

    my $floor_item = $self->starting_tile->find_item($floor);

    # no, we want to eat something in our inventory
    return 'n' unless $self->food == $floor_item;
    return 'y';
}

sub respond_eat_what {
    my $self = shift;

    if ($self->food->slot) {
        return $self->food->slot;
    }

    TAEB->log->action("Unable to eat '" . $self->food . "'. Sending escape, but I doubt this will work.", level => 'error');

    TAEB->send_message(check => 'inventory');
    TAEB->send_message(check => 'floor');
    $self->aborted(1);
    return "\e\e\e";
}

sub msg_stopped_eating {
    my $self = shift;
    my $item = shift;

    #when we stop eating, check inventory or the floor for the "partly"
    #eaten leftovers. The done method will take care of removing the original
    #item from inventory
    my $what = (blessed $item && $item->slot) ? 'inventory' : 'floor';
    TAEB->log->action("Stopped eating $item from $what");
    TAEB->send_message(check => $what);

    return;
}

sub done {
    my $self = shift;
    my $item = $self->food;

    if ($item->slot)  {
        TAEB->inventory->decrease_quantity($item->slot)
    }
    else {
        #This doesn't work well with a stack of corpses on the floor
        #because maybe_is used my remove_floor_item tries to match quantity
        TAEB->send_message(remove_floor_item => $item, $self->starting_tile);
    }

    my $old_nutrition = TAEB->nutrition;
    my $new_nutrition = $old_nutrition + $item->nutrition;

    TAEB->log->action("Eating $item is increasing our nutrition from $old_nutrition to $new_nutrition");
    TAEB->nutrition($new_nutrition);
}

sub edible_items {
    my $class = shift;

    return grep { $class->can_eat($_) }
           TAEB->current_tile->items,
           TAEB->inventory;
}

sub can_eat {
    my $class = shift;
    my $item = shift;

    return 0 unless $item->type eq 'food';
    return 0 unless $item->is_safely_edible;
    return 1;
}

sub overfull {
    # make sure we don't eat anything until we stop being satiated
    TAEB->nutrition(5000);
}

sub respond_stop_eating { shift->overfull; "y" }

subscribe finally_finished => sub { shift->overfull };

__PACKAGE__->meta->make_immutable;

1;

