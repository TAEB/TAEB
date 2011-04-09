package TAEB::World::Tile::Door;
use Moose;
use TAEB::OO;
use TAEB::Util qw/min/;
extends 'TAEB::World::Tile';

has state => (
    is  => 'rw',
    isa => 'TAEB::Type::DoorState',
);

sub is_locked {
    my $self = shift;
    $self->state && $self->state eq 'locked';
}

sub is_unlocked {
    my $self = shift;
    $self->state && $self->state eq 'unlocked';
}

sub blocked_door {
    my $self = shift;
    my $blocked_door = 0;
    my $orthogonal_tiles = 0;

    $self->each_orthogonal( sub {
        my $tile = shift;
        return if $tile->type eq 'rock' || $tile->type eq 'unexplored';
        $orthogonal_tiles++;
        $blocked_door++ if $tile->is_inherently_unwalkable;
    });

    # all visible orthogonal tiles to the door must be unblocked, and if both
    # the inside and the outside of the door are visible, they must both be
    # unblocked
    return $blocked_door >= min($orthogonal_tiles, 3);
}

__PACKAGE__->meta->make_immutable;

1;

