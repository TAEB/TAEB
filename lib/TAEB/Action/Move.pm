package TAEB::Action::Move;
use Moose;
use TAEB::OO;
use TAEB::Util 'assert';
use TAEB::Util::World 'vi2delta';

extends 'TAEB::Action';
with 'TAEB::Action::Role::Direction';

has path => (
    is       => 'ro',
    isa      => 'TAEB::World::Path',
    provided => 1,
);

has [qw/hit_obscured_monster hit_immobile_boulder pushing/] => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

# if the first movement moves us into a boulder, record the fact
sub BUILD {
    my $self = shift;

    my $start;
    if ($self->path) {
        $start = substr($self->path->path, 0, 1);
    }
    elsif ($self->direction) {
        $start = substr($self->direction, 0, 1);
    }
    else {
        confess "You must specify a path or direction to the Move action.";
    }

    if (my $next_tile = TAEB->current_tile->at_direction($start)) {
        $self->pushing(1)
            if $next_tile->has_boulder;

        confess "Tried to move into a monster"
            if $start ne '<' && $start ne '>' && $next_tile->has_monster;
    }
}

sub directions {
    my $self = shift;
    return $self->direction || $self->path->path;
}

sub command {
    my $self = shift;

    # XXX: this will break when we have something like stepping onto a teleport
    # trap with TC (intentionally)
    return substr($self->directions, 0, 1);
}

sub complement_type {
    my $self = shift;
    return $self->command eq '>' ? (stairsup => '<')
         : $self->command eq '<' ? (stairsdown => '>')
         : do { TAEB->log->action("complement_type called on a move action of type " . $self->command); undef };
}

# if we didn't move, and we tried to move diagonally, and the tile we're trying
# to move onto (or off of) is obscured, then assume that tile is a door.
# XXX: we could also be # in a pit or bear trap
sub done {
    my $self = shift;

    my $start          = $self->starting_tile;
    my $current        = TAEB->current_tile;
    my $intra_level    = $self->command eq '<' || $self->command eq '>';
    my $changed_levels = TAEB->z != $start->z;

    # have to also check $intra_level or else we get confused by trapdoors and
    # level teleporters
    if ($changed_levels && $intra_level) {
        if (($start->isa('TAEB::World::Tile::Stairs') && !$start->other_side) ||
            $start->other_side == $start) {
            TAEB->log->action("Setting the other_side of $start to $current");
            $start->other_side($current);
        }

        # If we changed level, then connect the dungeon graph.
        if ($current->type eq 'obscured') {
            $current->change_type($self->complement_type);
            $current->other_side($start);
        }
    }

    my $walked = TAEB->x - $start->x
              || TAEB->y - $start->y
              || $changed_levels;

    if ($walked) {
        TAEB->send_message('walked');

        if ($self->pushing) {
            # If we pushed a boulder, then if it's still there, it
            # must be genuine.
            $current->known_genuine_boulder(0);
            my $beyond = TAEB->current_level->at_safe(
                TAEB->x * 2 - $start->x,
                TAEB->y * 2 - $start->y,
            );
            $beyond->known_genuine_boulder(1)
                if $beyond && $beyond->has_boulder;
        }

        if ($intra_level && (my $branch = $start->branch)) {
            if ($self->command eq '<') {
                if ($branch eq 'sokoban' || $branch eq 'vlad') {
                    $current->branch($branch);
                }

                # dungeons branch propagates upwards except for sokoban, which
                # is immediately identified
                if ($branch eq 'dungeons' && !$current->known_branch) {
                    $current->branch($branch);
                }

                # mines propagates if the new level is 5 or deeper. any higher
                # and we could've left the mines and entered the dungeon
                if ($branch eq 'mines' && $current->z >= 5) {
                    $current->branch($branch);
                }
            }
            elsif ($self->command eq '>') {
                $current->branch($branch)
                    if $branch eq 'mines'
                    || $branch eq 'quest'
                    || $branch eq 'gehennom'
                    || ($branch eq 'dungeons' && $start->z > 4);
            }
        }

        # the rest applies only if we haven't moved
        return;
    }

    # none of the rest applies if we're trying to change levels
    return if $intra_level;

    my $dir = substr($self->directions, 0, 1);
    my ($dx, $dy) = vi2delta($dir);

    $self->handle_blocking_wall($dx, $dy)
        if $self->hit_immobile_boulder;

    return if $self->hit_obscured_monster;
    return if $self->hit_immobile_boulder;

    $self->handle_obscured_doors($dx, $dy);
    $self->handle_items_in_rock($dx, $dy);
}

sub handle_blocking_wall {
    my $self = shift;
    my $dx   = shift;
    my $dy   = shift;

    my $opposed = TAEB->current_level->at_safe(TAEB->x + $dx*2,
        TAEB->y + $dy*2);

    if ($opposed && $opposed->type eq 'unexplored') {
        $opposed->change_type('rock' => ' ');
    } elsif ($opposed && $opposed->is_walkable) {
        TAEB->log->action("Weird.  Something blocked the boulder, but what?");
    }
}

sub handle_items_in_rock {
    my $self = shift;
    my $dx   = shift;
    my $dy   = shift;

    my $tile = TAEB->current_tile;
    return if $tile->type eq 'trap' && ($tile->trap_type eq 'bear trap'
                                     || $tile->trap_type eq 'pit'
                                     || $tile->trap_type eq 'spiked pit'
                                     || $tile->trap_type eq 'web');
    return if $tile->type eq 'opendoor' && $dx && $dy;

    my $dest = TAEB->current_level->at(TAEB->x + $dx, TAEB->y + $dy);

    # the second clause here is for when handle_obscured_doors is run
    # the third clause here is because we assume floors that go to ' ' are dark
    # room tiles
    return unless $dest->type eq 'obscured'
               || ($dest->type eq 'opendoor' && $dest->floor_glyph eq '-')
               || ($dest->type eq 'floor' && $dest->glyph eq ' ');

    # Don't turn a door into rock if we tried approaching it diagonally
    return if ($dest->type eq 'opendoor' && $dx && $dy);

    $dest->change_type('rock' => ' ');
}

sub handle_obscured_doors {
    my $self = shift;
    my $dx   = shift;
    my $dy   = shift;

    # can't move? then don't bother
    return if TAEB::Action::Move->is_impossible;

    # obscured doors only affect us when we move diagonally
    return unless $dx && $dy;

    # we only care if the tile was obscured
    for ([TAEB->x, TAEB->y], [TAEB->x + $dx, TAEB->y + $dy]) {
        my $tile = TAEB->current_level->at(@$_);
        next unless $tile->type eq 'obscured';

        TAEB->log->action("Changing tile at (" . $tile->x . ", " . $tile->y . ") from obscured to opendoor because I tried to move diagonally off or onto it and I didn't move.");
        $tile->change_type('opendoor' => '-');
    }
}

# falling into a trapdoor makes the new level the same branch as the old level
subscribe trapdoor => sub {
    my $self = shift;

    TAEB->current_level->branch($self->starting_tile->branch)
        if $self->starting_tile->known_branch;
};

subscribe got_item => sub {
    my $self  = shift;
    my $event = shift;
    TAEB->send_message(remove_floor_item => $event->item);
};

sub msg_hidden_monster { shift->hit_obscured_monster(1) }

sub msg_immobile_boulder { shift->hit_immobile_boulder(1) }

sub respond_really_escape { 'y' }

sub location_controlled_tele {
    my $self = shift;
    my $target = $self->path->to;
    return $target if $target->is_walkable && !$target->has_monster;
    my @adjacent = $target->grep_adjacent(sub {
        my $t = shift;
        return $t->is_walkable && !$t->has_monster;
    });
    return unless @adjacent;
    return $adjacent[0];
}

sub is_impossible {
    my $self = shift;

    # This used to check the following conditions as well, but we *can* usefully
    # move in such cases - to escape our being stuck
#   TAEB->in_beartrap || TAEB->in_pit || TAEB->in_web || TAEB->is_grabbed

    return TAEB->is_engulfed;
}

__PACKAGE__->meta->make_immutable;

1;

