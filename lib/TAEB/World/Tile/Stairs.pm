package TAEB::World::Tile::Stairs;
use Moose;
use TAEB::OO;
use TAEB::Util qw/:colors display/;
extends 'TAEB::World::Tile';

has other_side => (
    is       => 'rw',
    isa      => 'TAEB::World::Tile',
    clearer  => 'clear_other_side',
    weak_ref => 1,
);

override debug_color => sub {
    my $self = shift;

    my $different_branch = $self->known_branch
                        && $self->other_side
                        && $self->other_side->known_branch
                        && $self->branch ne $self->other_side->branch;

    return $different_branch
         ? display(COLOR_YELLOW)
         : super;
};

override change_type => sub {
    my $self = shift;
    my $newtype = shift;

    # If we're replacing stairs by anything but stairs, obviously
    # we're confused as to where the other stairs lead, and we should
    # clear that value. This happens when, for instance, we end up
    # somewhere other than the stairs when going downstairs (say if a
    # monster followed us, and it was on the staircase, not us).
    if ($newtype ne 'stairsup' && $newtype ne 'stairsdown') {
        $self->other_side->clear_other_side if $self->other_side;
    }

    # Once we've done that, call the original procedure.
    super;
};

__PACKAGE__->meta->make_immutable;

1;

