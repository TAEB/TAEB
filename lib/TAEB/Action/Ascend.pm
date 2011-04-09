package TAEB::Action::Ascend;
use Moose;
use TAEB::OO;
extends 'TAEB::Action::Move';

use constant command => '<';
use constant complement_type => 'stairsdown' => '>';

has '+direction' => (
    default  => sub { shift->command },
    provided => 0,
);

before done => sub {
    my $self    = shift;
    my $start   = $self->starting_tile;
    my $current = TAEB->current_tile;

    return if $current->level->z == $start->level->z;

    if (($start->isa('TAEB::World::Tile::Stairs') && !$start->other_side) ||
        $start->other_side == $start) {
        TAEB->log->action("Setting the other_side of $start to " . $current);
        $start->other_side($current);
    }

    # If we changed level, then connect the dungeon graph.
    if ($current->type eq 'obscured') {
        $current->change_type($self->complement_type);
        $current->other_side($start);
    }
};

after done => sub {
    my $self    = shift;
    my $start   = $self->starting_tile;
    my $current = TAEB->current_tile;

    return unless $self->command eq '<';

    if (my $branch = $start->branch) {
        if ($branch eq 'sokoban' || $branch eq 'vlad') {
            $current->branch($branch);
        }

        # dungeons branch propagates upwards except for sokoban, which is
        # immediately identified
        if ($branch eq 'dungeons' && !$current->known_branch) {
            $current->branch($branch);
        }

        # mines propagates if the new level is 5 or deeper. any higher and we
        # could've left the mines and entered the dungeon
        if ($branch eq 'mines' && $current->z >= 5) {
            $current->branch($branch);
        }
    }
};

sub respond_really_escape { 'y' }

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

