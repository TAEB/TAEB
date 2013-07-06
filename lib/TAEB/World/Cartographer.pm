package TAEB::World::Cartographer;
use Moose;
use TAEB::OO;
use NetHack::Engravings 0.02 'is_degradation', 'is_maybe_preengraved';
use NetHack::FOV 0.01 'calculate_fov';
use TAEB::Util 'assert';
use TAEB::Util::World 'tile_type_to_glyph';
use TAEB::Util::Colors 'color_from_index';

has dungeon => (
    is       => 'ro',
    isa      => 'TAEB::World::Dungeon',
    weak_ref => 1,
    required => 1,
);

has x => (
    is  => 'rw',
    isa => 'Int',
);

has y => (
    is  => 'rw',
    isa => 'Int',
);

# Bounding box for tiles that have changed this step, to speed up
# updates of the screen in situations where we know things outside
# the bounding box won't change.
has [qw/tilechange_l tilechange_r tilechange_t tilechange_b/] => (
    is => 'rw',
    isa => 'Int',
);

has fov => (
    isa       => 'ArrayRef',
    is        => 'ro',
    default   => sub {
        calculate_fov(TAEB->x, TAEB->y, sub {
            my @coords = @_;
            $coords[0] = TAEB->x unless defined $coords[0];
            $coords[1] = TAEB->y unless defined $coords[1];
            my $tile = TAEB->current_level->at(@coords);
            return unless $tile;
            return $tile->is_transparent;
        })
    },
    clearer   => 'invalidate_fov',
    lazy      => 1,
);

# The last two locations the TAEB's been to, so we know which
# way we're going when entering a shop or other room.
has _earlier_location => (
    isa       => 'TAEB::World::Tile',
    is        => 'rw',
);

has _last_location => (
    isa       => 'TAEB::World::Tile',
    is        => 'rw',
    trigger   => sub {
        my $self = shift;
        my $new  = shift;
        return if $self->_last_location == $new;
        $self->_earlier_location($self->_last_location);
    }
);

sub update {
    my $self  = shift;

    my ($old_x, $old_y) = ($self->x, $self->y);
    my $old_level = $self->dungeon->current_level;

    my $vt = TAEB->vt;
    my ($Tx, $Ty) = ($vt->x, $vt->y);
    $self->x($Tx);
    $self->y($Ty);

    my ($tc_l, $tc_r, $tc_t, $tc_b) = ($Tx,$Tx,$Ty,$Ty);
    if (defined $old_x && defined $old_y) {
        $tc_l = $old_x if $old_x < $tc_l && $old_x >= 0;
        $tc_r = $old_x if $old_x > $tc_r && $old_x <= 79;
        $tc_t = $old_y if $old_y < $tc_t && $old_y >= 1;
        $tc_b = $old_y if $old_y > $tc_b && $old_y <= 21;
    }

    return if $self->is_engulfed;

    return unless $self->check_dlvl;

    my $level = $self->dungeon->current_level;

    my $tile_changed = 0;
    my $rogue = $level->is_rogue;

    my @old_monsters = $level->monsters;
    $_->tile->_clear_monster for @old_monsters;
    assert($level->monster_count == 0,
           "we removed all monsters from the level");

    $level->iterate_tile_vt(sub {
        my ($tile, $glyph, $color, $x, $y) = @_;

        # To save time, don't look for monsters in blank space, except
        # on the Rogue level. Likewise, . and # do not represent monsters.
        $tile->try_monster($glyph, $color)
            unless ($glyph eq ' ' && !$rogue)
                or ($glyph eq '.' || $glyph eq '#')
                or ($Tx == $x && $Ty == $y);

        if ($glyph ne $tile->glyph || $color != $tile->color) {
            $tile_changed = 1;
            $tc_l = $x if $x < $tc_l && $x >= 0;
            $tc_r = $x if $x > $tc_r && $x <= 79;
            $tc_t = $y if $y < $tc_t && $y >= 1;
            $tc_b = $y if $y > $tc_b && $y <= 21;
            $level->update_tile($x, $y, $glyph, $color);
        }

        return 1;
    }, TAEB->vt, 1);

    # XXX: should this be each_adjacent_inclusive? consider teleports etc
    TAEB->each_adjacent(sub {
        my $tile = shift;
        if ($tile->type eq 'unexplored') {
            my $x     = $tile->x;
            my $y     = $tile->y;
            my $glyph = $vt->at($x, $y);
            my $color = color_from_index($vt->color($x, $y))
                or confess "($x, $y) color=" . $vt->color($x, $y);

            $level->update_tile($x, $y, $glyph, $color);
        }
    });

    $old_level->step_off($old_x, $old_y) if defined($old_x);
    $level->step_on($self->x, $self->y);

    $self->tilechange_l($tc_l);
    $self->tilechange_r($tc_r);
    $self->tilechange_t($tc_t);
    $self->tilechange_b($tc_b);

    if ($tile_changed) {
        $self->autoexplore($level == $old_level);
        $self->dungeon->current_level->detect_branch;
        TAEB->send_message('tile_changes');
    }

    if ($tile_changed || $self->x != $old_x || $self->y != $old_y) {
        $self->invalidate_fov;
    }

    # replace previously known monsters if they moved out of view
    for my $monster (@old_monsters) {
        my $tile = $monster->tile;
        # if it was updated before, don't try to update it again
        next if $tile->has_monster;
        # we cleared all monsters at the beginning of this update, so we need
        # to check for monsters that didn't move (since iterate_tiles_vt won't
        # see them)
        # XXX: can we factor these tests out?
        my ($glyph, $color, $x, $y) = ($tile->glyph, $tile->color, $tile->x, $tile->y);
        $tile->try_monster($glyph, $color)
            unless ($glyph eq ' ' && !$rogue)
                or ($glyph eq '.' || $glyph eq '#')
                or ($Tx == $x && $Ty == $y);
        # if we saw another monster here, the old monster is gone
        next if $tile->has_monster;
        # if the tile is in los, we'd be able to see a monster there
        # XXX: cold-blooded monsters in darkness?
        next if $tile->in_los;
        # if the monster has been remembered for a while, forget it
        next if TAEB->turn - $monster->last_seen > $monster->persistence_time;
        $tile->monster($monster);
    }
}

sub map_like {
    my $self = shift;
    my $re = shift;

    defined TAEB->vt->find_row(sub {
        my ($row, $y) = @_;
        $y > 0 && $y < 22 && $row =~ $re;
    });
}

sub check_dlvl {
    my $self = shift;

    my $botl = TAEB->vt->row_plaintext(23);
    $botl =~ /^(Dlvl|Home|Fort Ludios|End Game|Astral Plane)(?::| )?(\d*) /
        or do {
            TAEB->log->cartographer("Unable to parse the botl for dlvl: $botl",
                                    level => 'error');
            return;
    };

    my $level = $self->dungeon->current_level;
    my $descriptor = $1;
    my $dlvl = $2 || $level->z;
    my $was_ludios = $level->known_branch && $level->branch eq 'ludios';
    my $is_ludios = $descriptor eq 'Fort Ludios';

    if ($level->z != $dlvl || $was_ludios != $is_ludios) {
        TAEB->log->cartographer("Oh! We seem to be on a different map. Was ".$level->z.", now $dlvl.");

        my @levels = $self->dungeon->get_levels($dlvl);
        my $newlevel;

        for my $level (@levels) {
            if ($level->matches_vt) {
                $newlevel = $level;
                last;
            }
        }

        unless ($newlevel) {
            $newlevel = $self->dungeon->create_level($dlvl);
            if ($dlvl >= 2 && $dlvl <= 10) {
                if ($newlevel->detect_sokoban_vt) {
                    $newlevel->branch('sokoban');
                }
            }
            if ($dlvl >= 10 && $dlvl <= 12) {
                if ($newlevel->detect_bigroom_vt) {
                    $newlevel->branch('dungeons');
                    $newlevel->is_bigroom(1);
                }
            }
            if ($botl =~ /\*:\d+/) {
                $newlevel->branch('dungeons');
                $newlevel->is_rogue(1);
            }
            else { $newlevel->is_rogue(0) }
            if ($descriptor eq 'Home') {
                $newlevel->branch('quest');
            }
            elsif ($descriptor eq 'Fort Ludios') {
                $newlevel->branch('ludios');
            }
            TAEB->log->cartographer("Created level: $newlevel");
        }
        else {
            TAEB->log->cartographer("We're returning to level: $newlevel");
        }

        $self->dungeon->current_level($newlevel);
        TAEB->send_message('level_change' => old_level => $level, new_level => $newlevel);
    }

    return 1;
}

sub autoexplore {
    my $self = shift;
    my $level = $self->dungeon->current_level;
    my $can_optimise = shift || 0;
    my $iterator = $can_optimise ? 'each_changed_tile_and_neighbors'
                                 : 'each_tile';

    $level->$iterator(sub {
        my $tile = shift;
        if (!$tile->explored
            && $tile->type ne 'rock'
            && $tile->type ne 'unexplored') {
            $tile->explored(1) unless $tile->any_adjacent(sub {
                shift->type eq 'unexplored'
            });
        }
    });
}

sub msg_dungeon_feature {
    my $self    = shift;
    my $feature = shift;
    my ($floor, $type, $subtype);

    if ($feature eq 'staircase down') {
        $floor = '>';
        $type  = 'stairsdown';
    }
    elsif ($feature eq 'staircase up') {
        $floor = '<';
        $type  = 'stairsup';
    }
    elsif ($feature eq 'bad staircase') {
        # Per Eidolos' idea: all stairs in rogue are marked as stairsdown, and
        # we only change them to stairs up if we get a bad staircase message.
        # This code was originally to fix mimics being stairs inside a shop,
        # but we don't have to worry about mimics in Rogue.
        if (!TAEB->current_level->is_rogue) {
            $floor = ' ';
            $type = 'obscured';
        } else {
            $floor = '<';
            $type = 'stairsup';
        }
        # if we get a bad_staircase message, we're obviously confused about
        # things, so make sure we don't leave other_side pointing to strange
        # places
        TAEB->current_tile->other_side->clear_other_side
            if TAEB->current_tile->can('other_side')
            && TAEB->current_tile->other_side
            && TAEB->current_tile->other_side->can('clear_other_side');
        TAEB->current_tile->clear_other_side
            if TAEB->current_tile->can('clear_other_side');
    }
    elsif ($feature eq 'fountain' || $feature eq 'sink') {
        $floor = '{';
        $type  = $feature;
    }
    elsif ($feature eq 'fountain dries up' || $feature eq 'brokendoor') {
        $floor = '.';
        $type  = 'floor';
    }
    elsif ($feature eq 'trap') {
        $subtype = shift;
        if ($subtype) {
            $floor = '^';
            $type  = 'trap';
        }
        else {
            $floor = '.';
            $type  = 'floor';
        }
    }
    elsif ($feature eq 'grave') {
        $floor = '\\';
        $type = 'grave';
    }
    elsif ($feature =~ /\baltar$/) {
        $floor = '_';
        $type = 'altar';
        $subtype = shift;
    }
    else {
        # we don't know how to handle it :/
        return;
    }

    my $tile     = TAEB->current_tile;
    my $oldtype  = $tile->type;
    my $oldfloor = $tile->floor_glyph;

    if ($oldtype ne $type || $oldfloor ne $floor) {
        TAEB->log->cartographer("msg_dungeon_feature('$feature') caused the current tile to be updated from ('$oldfloor', '$oldtype') to ('$floor', '$type')");
    }

    $tile->change_type($type => $floor, $subtype);
}

subscribe any => sub {
    my $self  = shift;
    my $event = shift;

    return unless $event->does('TAEB::Announcement::Dungeon::Feature')
               && $event->has_target_tile;

    my $tile    = $event->target_tile;
    my $type    = $event->tile_type;
    my $subtype = $event->tile_subtype;
    my $glyph   = tile_type_to_glyph($event->tile_type);

    $tile->change_type($type => $glyph, $subtype);
};

subscribe excalibur => sub {
    my $self = shift;

    TAEB->current_tile->change_type(floor => '.');
};

subscribe tile_noitems => sub {
    my $self  = shift;
    my $event = shift;

    $event->tile->clear_items;
};

sub msg_floor_item {
    my $self = shift;
    my $item = shift;

    TAEB->current_tile->add_item($item) if $item;
}

sub msg_item_price {
    my $self = shift;
    my $item = shift;
    my $cost_each = shift;
    my $tile = TAEB->current_tile;

    for my $i (0 .. $tile->item_count - 1) {
        my $tile_item = $tile->item_idx($i);

        if ($item->maybe_is($tile_item)) {
            $tile_item->cost_each($cost_each);
            return;
        }
    }
    assert(0, "Couldn't find the $item that's meant to be on this tile");
}

sub msg_remove_floor_item {
    my $self = shift;
    my $item = shift;
    my $tile = shift || TAEB->current_tile;

    # We teleported and the tile was cleared by the map update
    return if ($tile != TAEB->current_tile && !$tile->item_count);

    for my $i (0 .. $tile->item_count - 1) {
        my $tile_item = $tile->item_idx($i);

        if ($item->maybe_is($tile_item)) {
            $tile->remove_item_idx($i);
            return;
        }
    }

    return if $item->is_auto_picked_up;

    TAEB->log->consistency("Unable to remove $item from the floor.");
}

sub msg_floor_message {
    my $self = shift;
    my $message = shift;

    my $tile = TAEB->current_tile;

    TAEB->log->cartographer("$tile is now engraved with \'$message\'");
    $tile->engraving($message);

    my @doors = $tile->grep_adjacent(sub { $_->type eq 'closeddoor' });
    if (@doors) {
        if (is_degradation("Closed for inventory" => $message)) {
            $_->is_shop(1) for @doors;
        }
    }

    if (!$tile->player_engraving && !is_maybe_preengraved($message)) {
        my $level = TAEB->current_level;
        TAEB->log->cartographer("Identifying $level as a bones level, because $message couldn't have been preengraved and we didn't write on this tile");
        $level->is_bones(1);
    }
}

sub msg_engraving_type {
    my $self = shift;
    my $engraving_type = shift;

    TAEB->current_tile->engraving_type($engraving_type);
}

sub msg_pickaxe {
    TAEB->current_level->pickaxe(TAEB->turn);
}

sub floodfill_room {
    my $self = shift;
    my $type = shift;
    my $tile = shift || TAEB->current_tile;
    $tile->floodfill(
        sub {
            my $t = shift;
            $t->type eq 'floor' || $t->type eq 'obscured' || $t->type eq 'altar'
        },
        sub {
            my $t   = shift;
            my $var = "in_$type";
            return if $t->$var;
            TAEB->log->cartographer("$t is in a $type!");
            $t->$var(1);
        },
    );
}

subscribe debt => sub {
    shift->floodfill_room('shop');
};

subscribe step => sub {
    shift->_last_location(TAEB->current_tile);
};

sub msg_enter_room {
    my $self     = shift;
    my $type     = shift || return;
    my $subtype  = shift;

    # Okay, so we want to floodfill the room when we enter it.
    # Because we get the message in the doorway, we can't floodfill from that
    # tile.
    # Instead, we take into account which way the TAEB is going. If there's
    # exactly one square that is orthogonal to us, not adjacent to our
    # previous location, and walkable, fill from there. Otherwise we're
    # confused (maybe we teleported into the room?); log a warning and don't
    # fill anything.
    my @possibly_inside;
    my $last_tile = $self->_last_location;
    $last_tile = $self->_earlier_location
        if defined $last_tile && $last_tile == TAEB->current_tile;
    my $ltx = $last_tile ? $last_tile->x : -2;
    my $lty = $last_tile ? $last_tile->y : -2;
    TAEB->current_tile->each_orthogonal(sub {
        my $tile = shift;
        return if abs($tile->x - $ltx) <= 1
               && abs($tile->y - $lty) <= 1;
        return if $tile->is_inherently_unwalkable(1);
        push @possibly_inside, $tile;
    });

    if (@possibly_inside == 1) {
        $self->floodfill_room($type, $possibly_inside[0]);
    }
    else {
        TAEB->log->cartographer(
            "Can't figure out where the boundaries of this room are: "
          . @possibly_inside . " possibilities",
            level => 'warning'
        );
    }
}

subscribe vault_guard => sub {
    shift->floodfill_room('vault');
};

my @engulf_expected = (
    [-1, -1] => '/',
    [ 0, -1] => '-',
    [ 1, -1] => '\\',
    [-1,  0] => '|',
    [ 1,  0] => '|',
    [-1,  1] => '\\',
    [ 0,  1] => '-',
    [ 1,  1] => '/',
);

sub is_engulfed {
    my $self = shift;

    for (my $i = 0; $i < @engulf_expected; $i += 2) {
        my ($deltas, $glyph) = @engulf_expected[$i, $i + 1];
        my ($dx, $dy) = @$deltas;

        my $got = TAEB->vt->at(TAEB->x + $dx, TAEB->y + $dy);
        next if $got eq $glyph;

        return 0 unless TAEB->is_engulfed;

        TAEB->log->cartographer("We're no longer engulfed! I expected to see $glyph at delta ($dx, $dy) but I saw $got.");
        TAEB->send_message(engulfed => 0);
        return 0;
    }

    TAEB->log->cartographer("We're engulfed!");
    TAEB->send_message(engulfed => 1);
    return 1;
}

sub msg_branch {
    my $self   = shift;
    my $branch = shift;
    my $level  = $self->dungeon->current_level;

    $level->branch($branch)
        unless $level->known_branch;

    return if $level->branch eq $branch;

    TAEB->log->cartographer("Tried to set the branch of $level to $branch but it already has a branch.", level => 'error');
}

sub msg_quest_portal {
    my $self = shift;

    TAEB->current_level->has_quest_portal(1);
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 map_like Regex -> Bool

Returns whether any part of the map (not the entire screen) matches Regex.

=head2 check_dlvl

Updates the current_level if Dlvl appears to have changed.

=head2 autoexplore

Mark tiles that are obviously explored as such. Things like "a tile
with no unknown neighbors".

=head2 is_engulfed -> Bool

Checks the screen to see if we're engulfed. It'll inform the rest of the system
about our engulfedness. Returns 1 if we're engulfed, 0 if not.

=cut

