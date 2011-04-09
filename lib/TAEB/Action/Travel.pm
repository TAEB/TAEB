package TAEB::Action::Travel;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

use constant command => '_';

has target_tile => (
    is       => 'ro',
    isa      => 'TAEB::World::Tile',
    provided => 1,
    required => 1,
);

sub location_controlled_tele {
    my $self = shift;
    my $target = $self->target_tile;
    return $target if $target->is_walkable && !$target->has_monster;
    my @adjacent = $target->grep_adjacent(sub {
        my $t = shift;
        return $t->is_walkable && !$t->has_monster;
    });
    return unless @adjacent;
    return $adjacent[0];
}

sub location_travel { shift->target_tile }

sub done {
    my $self = shift;
    # NetHack doesn't show or tell us what's on the floor when we
    # travel. So we have to check manually.
    TAEB->send_message(check => 'floor');
}

__PACKAGE__->meta->make_immutable;

1;

