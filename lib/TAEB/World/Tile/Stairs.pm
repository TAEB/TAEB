package TAEB::World::Tile::Stairs;
use Moose;
use TAEB::OO;
extends 'TAEB::World::Tile';
with 'TAEB::World::Tile::Role::LevelChanger';

before change_type => sub {
    my $self = shift;
    my $newtype = shift;

    # If we're replacing stairs by anything but stairs, obviously
    # we're confused as to where the other stairs lead, and we should
    # clear that value. This happens when, for instance, we end up
    # somewhere other than the stairs when going downstairs (say if a
    # monster followed us, and it was on the staircase, not us).
    if ($newtype ne 'stairsup' && $newtype ne 'stairsdown') {
        $self->other_side->clear_other_side if $self->other_side_known;
    }
};

__PACKAGE__->meta->make_immutable;

1;

