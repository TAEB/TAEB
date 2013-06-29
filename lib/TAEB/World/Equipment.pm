package TAEB::World::Equipment;
use Moose;
use TAEB::OO;
extends 'NetHack::Inventory::Equipment';

with 'TAEB::Role::Overload';

sub debug_line {
    my $self = shift;
    my @eq;

    for my $slot ($self->slots) {
        my $item = $self->$slot;
        push @eq, $slot . ': ' . $item->debug_line
            if $item;
    }

    return join "\n", @eq;
}

sub msg_slot_empty {
    my ($self, $slot) = @_;

    my $clear = "clear_$slot";

    $self->$clear;
}

subscribe now_wielding => sub {
    my ($self, $event) = @_;
    my $item = $event->item;

    $self->weapon->is_wielded(0) if $self->weapon;
    $self->weapon($item);
    $item->is_cursed(1) if $event->welded;
    $item->is_wielded(1);
    TAEB->inventory->update($item->slot => $item);
};

sub has_left_sd {
    my $self = shift;
    my $ring = $self->left_ring or return;
    my $identity = $ring->identity or return;
    return $identity eq "ring of slow digestion";
}

sub has_right_sd {
    my $self = shift;
    my $ring = $self->right_ring or return;
    my $identity = $ring->identity or return;
    return $identity eq "ring of slow digestion";
}

__PACKAGE__->meta->make_immutable;

1;

