package TAEB::World::Level;
use Moose;
use TAEB::OO;
use TAEB::Util qw/first any assert/;
use TAEB::Util::World qw/deltas delta2vi vi2delta tile_types glyphs feature_colors/;
use TAEB::Util::Colors 'color_from_index';

our %GLYPHS = %{ glyphs() };
our %FEATURE_COLORS = %{ feature_colors() };

with 'TAEB::Role::Reblessing', 'TAEB::Role::Overload';

has tiles => (
    is      => 'ro',
    isa     => 'ArrayRef[Maybe[ArrayRef[TAEB::World::Tile]]]',
    default => sub {
        my $self = shift;
        # ugly, but ok
        [ undef,

          map { my $y = $_;
            [ map {
                TAEB::World::Tile->new(level => $self, x => $_, y => $y)
            } 0 .. 79 ]
        } 1 .. 21 ]
    },
);

has dungeon => (
    is       => 'ro',
    isa      => 'TAEB::World::Dungeon',
    weak_ref => 1,
);

has special_level => (
    is       => 'rw',
    isa      => 'Str',
    default  => "",
    trigger  => sub {
        my $self = shift;
        my $level = ucfirst(shift);
        my $new_pkg = "TAEB::World::Level::$level";

        if ($new_pkg->can('meta')) {
            $self->rebless($new_pkg);
        }
    },
);

has branch => (
    is        => 'rw',
    isa       => 'TAEB::Type::Branch',
    predicate => 'known_branch',
    trigger   => sub {
        my ($self, $name) = @_;
        TAEB->log->level("$self is in branch $name!");
    },
);

has z => (
    is  => 'ro',
    isa => 'Int',
);

has monsters => (
    traits     => ['Array'],
    isa        => 'ArrayRef[TAEB::World::Monster]',
    default    => sub { [] },
    handles    => {
        monsters           => 'elements',
        monster_idx        => 'get',
        add_monster        => 'push',
        clear_monsters     => 'clear',
        has_monsters       => 'count',
        monster_count      => 'count',
        remove_monster_idx => 'delete',
    }
);

before add_monster => sub {
    my $self = shift;
    my ($monster) = @_;
    assert((!any { $_->tile == $monster->tile } $self->monsters),
           "not adding two monsters to the same tile");
};

has turns_spent_on => (
    traits    => ['Counter'],
    is        => 'ro',
    default   => 0,
    handles   => {
        inc_turns_spent_on => 'inc',
    },
);

has pickaxe => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has tiles_by_type => (
    is      => 'ro',
    isa     => 'HashRef[ArrayRef[TAEB::World::Tile]]',
    default => sub { {} },
);

has items => (
    traits     => ['Array'],
    isa        => 'ArrayRef[NetHack::Item]',
    default    => sub { [] },
    handles    => {
        items           => 'elements',
        item_count      => 'count',
        remove_item_idx => 'delete',
        item_idx        => 'get',
        add_item        => 'push',
    },
);

has fully_explored => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

# Some information about the history of a Sokoban level needs to be
# retained in order to be able to solve it correctly. There's no
# reason we can't count the number of eliminated pit/hole traps on
# other levels too (could come in useful on the VoTD, for instance).
has pit_and_hole_traps_untrapped => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

subscribe covered_pit => sub {
    my $self = shift;
    $self->pit_and_hole_traps_untrapped(
        $self->pit_and_hole_traps_untrapped + 1
    );
};

# Note that the quest portal can be on the rogue level, so this can't
# be just another special level.
has has_quest_portal => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has _astar_cache => (
    traits  => ['Hash'],
    isa     => 'HashRef[Maybe[Str]]',
    lazy    => 1,
    clearer => 'clear_astar_cache',
    default => sub { {} },
    handles => {
        _has_cached_astar_path => 'exists',
        _cache_astar_path      => 'set',
        _get_cached_astar_path => 'get',
    },
);


# So, for these is_<speciallevel>,
#    true  => definitely that level
#    false => definitely not that level
#    undef => maybe that level?
#

our @special_levels = qw/minetown rogue oracle bigroom minend/;

for my $level (@special_levels) {
    has "is_$level" => (
        is      => 'rw',
        isa     => 'Bool',
        trigger => sub {
            my ($self, $is_level) = @_;
            $self->special_level($level) if $is_level;
            TAEB->log->level(
                sprintf('This level is most definitely%s %s.',
                        $is_level ? '' : ' not',
                        ucfirst($level)
                ),
            );
        },
    );
}

sub base_class { __PACKAGE__ }

sub is_on_map {
    my $self = shift;
    my ($x, $y) = @_;
    return if $x < 0 || $x > 79;
    return if $y < 1 || $y > 21;
    return 1;
}

# XXX: Yes this REALLY sucks but it's an "easy" optimization
sub at {
    my ($self, $x, $y) = @_;
    return $self->{tiles}->[$y][$x];
}

# A safer version of at, returns undef if given a tile out of range
# Call this if you know you're going to give out-of range input
# sometimes (for instance, adjacencies at the edge of the map)
sub at_safe {
    my $self = shift;
    # note: i'm assuming here that the cartographer always makes sure our
    # position is on the map
    if(!@_) {
        my $cartographer = TAEB->dungeon->cartographer;
        return $self->at($cartographer->x, $cartographer->y) unless @_;
    }
    my ($x, $y) = @_;
    return unless $self->is_on_map($x, $y);
    return $self->{tiles}->[$y][$x];
}

sub at_direction {
    my $self      = shift;
    my $x         = @_ > 2 ? shift : TAEB->x;
    my $y         = @_ > 1 ? shift : TAEB->y;
    my $direction = shift;

    $self->at($x, $y)->at_direction($direction);
}

sub update_tile {
    my $self     = shift;
    my $x        = shift;
    my $y        = shift;
    my $newglyph = shift;
    my $color    = shift;

    $self->tiles->[$y][$x]->update($newglyph, $color);
}

sub step_on {
    my $self = shift;
    my $x = shift;
    my $y = shift;

    $self->tiles->[$y][$x]->step_on;
}

sub step_off {
    my $self = shift;
    my $x = shift;
    my $y = shift;

    $self->tiles->[$y][$x]->step_off;
}

my %beamblock = map { $_ => 1 } qw/wall tree rock/;

sub _beamable {
    my ($tile, $nodoor, $nounknown) = @_;

    return $tile && !$beamblock{$tile->type}
        && (!$nodoor    || $tile->type ne 'closeddoor')
        && (!$nounknown || $tile->type ne 'unknown');
}

# FIXME this function has far too many parameters
sub _beam_fly {
    my ($self, $output, $bouncy, $dx, $dy, $oldx, $oldy, $range) = @_;

    my ($newx, $newy) = ($dx+$oldx, $dy+$oldy);

    my $tile = $self->at($newx, $newy);

    push @$output, [$range - 1, $tile] if $tile;

    return if $range <= 1;

    my ($continue, $hmirror, $vmirror, $reflect) = (0,0,0,0);

    $continue = 1 if _beamable($tile);
    $reflect  = 1 if !_beamable($tile, 0, 1) && $bouncy;

    if ($reflect && $dx && $dy) {
        my $offside = $self->at($newx, $oldy);
        my $into    = $self->at($newx+$dx, $oldy);

        $hmirror = 1 if _beamable($offside, 1, 0) && _beamable($into);

        $offside = $self->at($oldx, $newy);
        $into    = $self->at($oldx, $newy+$dy);

        $vmirror = 1 if _beamable($offside, 1, 0) && _beamable($into);
    }

    $self->_beam_fly($output, $bouncy,  $dx,  $dy, $newx, $newy,
        $range-1) if $continue;
    $self->_beam_fly($output, $bouncy,  $dx, -$dy, $newx, $newy,
        $range-2) if $hmirror;
    $self->_beam_fly($output, $bouncy, -$dx,  $dy, $newx, $newy,
        $range-2) if $vmirror;
    $self->_beam_fly($output, $bouncy, -$dx, -$dy, $newx, $newy,
        $range-2) if $reflect;
}

sub radiate {
    my $self = shift;
    my $code = shift;
    my %args = @_;

    my $max          = $args{max} || 80;
    my $stopper_max  = $args{stopper_max} || $args{max};
    my $stopper      = $args{stopper};
    my $allowself    = $args{allowself};
    my $bouncy       = $args{bouncy};
    my $new_dir      = $args{started_new_direction};
    my $current_tile = TAEB->current_tile;
    my ($x, $y)      = (TAEB->x, TAEB->y);

    # check each direction
    DIRECTION: for (deltas) {
        my ($dx, $dy) = @$_;

        $new_dir->($dx, $dy) if $new_dir;

        my @tile_set;

        if ($stopper) {
            $self->_beam_fly(\@tile_set, $bouncy, $dx, $dy, $x, $y, $stopper_max);

            # first, is there any stopper anywhere in range? if so, bail
            for (@tile_set) {
                my ($distance, $tile) = @$_;
                next DIRECTION if $stopper->($tile);
                next DIRECTION if !$allowself && $tile == $current_tile;
            }
        }

        if ($max != $stopper_max || !@tile_set) {
            @tile_set = ();
            $self->_beam_fly(\@tile_set, $bouncy, $dx, $dy, $x, $y, $max);
        }

        # next, does this direction actually have a target?
        for (@tile_set) {
            my ($distance, $tile) = @$_;

            next unless $code->($tile);

            # if they ask for a scalar, give them the direction
            return delta2vi($dx, $dy) if !wantarray;

            # if they ask for a list, give them more detail
            return (
                delta2vi($dx, $dy),
                $max - $distance,
                $tile,
            );
        }
    }
}

sub remove_monster {
    my $self    = shift;
    my $monster = shift;

    for (my $i = 0; $i < $self->monster_count; ++$i) {
        if ($self->monster_idx($i) == $monster) {
            $self->remove_monster_idx($i);
            return 1;
        }
    }

    TAEB->log->level("Unable to remove $monster from the current level!",
                     level => 'warning');
}

my @unregisterable = qw(unexplored rock wall floor corridor obscured);
my %is_unregisterable = map { $_ => 1 } @unregisterable;
sub is_unregisterable { $is_unregisterable{$_[1]} }

sub register_tile {
    my $self = shift;
    my $tile = shift;
    my $type = shift || $tile->type;

    push @{ $self->tiles_by_type->{$type} ||= [] }, $tile
        unless $self->is_unregisterable($type);
}

sub unregister_tile {
    my $self = shift;
    my $tile = shift;
    my $type = shift || $tile->type;

    return if $self->is_unregisterable($type);

    for (my $i = 0; $i < @{ $self->tiles_by_type->{$type} || [] }; ++$i) {
        if ($self->tiles_by_type->{$type}->[$i] == $tile) {
            return splice @{ $self->tiles_by_type->{$type} }, $i, 1;
        }
    }

    TAEB->log->level("Unable to unregister $tile", level => 'warning');
}

sub has_type {
    my $self = shift;
    map { @{ $self->tiles_by_type->{$_} || [] } } @_
}

*tiles_of = \&has_type;

sub has_enemies { grep { $_->is_enemy } shift->monsters }

sub exits {
    my $self = shift;

    my @exits = map { $self->tiles_of($_) } qw/stairsup stairsdown/;

    @exits = grep { $_->type ne 'stairsup' } @exits
        if $self->z == 1 && !TAEB->has_item("Amulet of Yendor");

    return @exits;
}

sub exit_towards {
    my $self = shift;
    my $other = shift;
    my $back = shift;

    return if $self == $other;

    for my $exit ($self->exits) {
        next if !$exit->other_side;

        next if defined $back && $exit->other_side->level == $back;

        return $exit if $exit->other_side->level == $other;

        my $rec = $exit->other_side->level->exit_towards($other, $self);

        return $exit if $rec;
    }

    return;
}

sub adjacent_levels {
    map  { $_->level }
    grep { defined }
    map  { $_->other_side }
    shift->exits
}

sub iterate_tile_vt {
    my $self = shift;
    my $code = shift;
    my $vt   = shift || TAEB->vt;
    my $skip_unchanged = shift || 0;

    for my $y (1 .. 21) {
        next if $skip_unchanged && !($vt->rows_changed->[$y]);
        my @glyphs = split '', $vt->row_plaintext($y);
        my @colors = $vt->row_color($y);

        # XXX: yes, this is another encapsulation breaker. boo hoo!
        my $tile_row = $self->{tiles}->[$y];

        for my $x (0 .. 79) {
            return unless $code->(
                $tile_row->[$x],
                $glyphs[$x],
                color_from_index($colors[$x]),
                $x,
                $y,
            );
        }
    }
    $vt->rows_changed([]) if $skip_unchanged;

    return 1;
}

sub first_tile {
    my $self = shift;
    my $code = shift;

    for my $y (1 .. 21) {
        for my $x (0 .. 79) {
            my $tile = $self->at($x, $y);
            return $tile if $code->($tile);
        }
    }

    return;
}

sub matches_vt {
    my $self = shift;
    my $vt   = shift || TAEB->vt;

    $self->iterate_tile_vt(sub {
        my ($tile, $glyph, $color, $x, $y) = @_;

        # the new level has rock where we used to have something else. that's
        # a pretty clear indicator
        return 0 if $glyph eq ' '
                 && $tile->type ne 'rock'
                 && $tile->type ne 'unexplored'
                 && $tile->type ne 'obscured'
                 && $tile->glyph ne ' '
                 && $tile->type ne 'floor';

        return 1;
    }, $vt);
}

my %branch = (
    dungeons => sub { shift->z < 29 },
    mines    => sub {
        my $self = shift;
        $self->z >= 3 && $self->z <= 13;
    },
);

sub detect_branch {
    my $self = shift;
    return if $self->known_branch;

    for my $name (keys %branch) {
        if ($branch{$name}->($self)) {
            my $method = "_detect_$name";
            if ($self->$method) {
                $self->branch($name);
                last;
            }
        }
    }
}

sub _detect_dungeons {
    my $self = shift;

    # out of range of the mines
    # XXX: this may misidentify gehennom, quest, sokoban..
    return 1 if $self->z < 3 || $self->z > 13;

    # is there a parallel mines level?
    return 1 if any { $_->known_branch && $_->branch eq 'mines' }
                $self->dungeon->get_levels($self->z);

    # dungeon features (fountain, sink, altar, door, etc) the z
    # constraint means we won't misidentify minetown as dungeons
    # also, this can't be minetown if there's a dungeons level
    # immediately next to us
    return 1 if (($self->z != 5 && $self->z != 6) ||
                 any {$_->known_branch && $_->branch eq 'dungeons'}
                 $self->adjacent_levels)
             && ($self->has_type('closeddoor')
             ||  $self->has_type('opendoor')
             ||  $self->has_type('altar')
             ||  $self->has_type('sink')
             ||  $self->has_type('fountain')
             ||  $self->has_type('throne'));

    return 0;
}

sub _detect_mines {
    my $self = shift;

    # is there a parallel dungeons level?
    return 1 if any { $_->known_branch && $_->branch eq 'dungeons' }
                $self->dungeon->get_levels($self->z);

    # the check we make is that any level where there are diagonally adjacent
    # walls with the same glyph, it's mines. that captures the following:
    # .....
    # ..---
    # ..-..
    # .....

    # future possibilities:
    # convex walls
    # - futilius has crazy schemes!
    #   + two diagonally adjacent walls of the same glyph
    #   + something that looks like:
    #         ---
    #           |
    #           ---

    # >6 or so floor tiles in a row (rooms have a max height)

    # the check
    my $mines = 0;
    return 1 if $self->first_tile(sub {
        my $tile = shift;
        return 0 if $tile->type ne 'wall';

        $tile->each_diagonal(sub {
            my $t = shift;
            $mines = 1 if $t->type eq 'wall'
                       && $t->glyph eq $tile->glyph;
        });

        return $mines;
    });

    return 0;
}

my $A1_row6  = qr/                                ------  -----/;
my $A1_row11 = qr/                                |---------.---/;
my $A1_row17 = qr/                                 |..----------/;

my $B1_row6  = qr/                                -------- ------/;
my $B1_row11 = qr/                                |.|------0----\|/;
my $B1_row16 = qr/                                ----   --------/;

sub detect_sokoban_vt {
    my $self = shift;
    my $vt   = shift || TAEB->vt;

    return 1 if $vt->row_plaintext(6)  =~ $A1_row6
             && $vt->row_plaintext(11) =~ $A1_row11
             && $vt->row_plaintext(17) =~ $A1_row17;

    return 1 if $vt->row_plaintext(6)  =~ $B1_row6
             && $vt->row_plaintext(11) =~ $B1_row11
             && $vt->row_plaintext(16) =~ $B1_row16;

    return 0;
}

around is_minetown => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig(@_) if @_;

    my $is_minetown = $self->$orig;
    return $is_minetown if defined $is_minetown;

    return unless $self->known_branch;
    unless ($self->branch eq 'mines' && $self->z >= 5 && $self->z <= 8) {
        $self->is_minetown(0);
        return 0;
    }

    return unless $self->has_type('closeddoor')
               || $self->has_type('opendoor')
               || $self->has_type('altar')
               || $self->has_type('sink')
               || $self->has_type('fountain')
               || $self->has_type('tree');

    TAEB->log->level("$self is Minetown!");
    $self->is_minetown(1);
    return 1;
};

around is_oracle => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig(@_) if @_;

    my $is_oracle = $self->$orig;
    return $is_oracle if defined $is_oracle;

    if ($self->known_branch && $self->branch ne 'dungeons') {
        $self->is_oracle(0);
        return 0;
    }
    unless ($self->z >= 5 && $self->z <= 9) {
        $self->is_oracle(0);
        return 0;
    }

    my $oracle_tile = $self->at(39,12);
    if ($oracle_tile->has_monster) {
        my $oracle = $oracle_tile->monster->is_oracle;
        $self->is_oracle($oracle);
        return $oracle;
    }

    return 0;
};

sub detect_bigroom_vt {
    my $self = shift;

    # Bigroom 1
    # Technically also 2 + 3, but it'll take a lot of exploration,
    # so we'll need something better for those.
    return 1 if TAEB->vt->row_plaintext(4) =~ /-{75}/;

    # XXX : Find out good ways to detect 2,3,4,5.
    #       Maps: http://nethack.wikia.com/wiki/Bigroom

    # Undef means unsure.
    return;
}

around is_bigroom => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig(@_) if @_;

    my $is_bigroom = $self->$orig;
    return $is_bigroom if defined $is_bigroom;

    unless ($self->z >= 10 && $self->z <= 12) {
        $self->is_bigroom(0);
        return 0;
    }

    $self->branch('dungeons') if $self->$orig($self->detect_bigroom_vt);
    return $self->$orig;
};

sub each_tile {
    my $self = shift;
    my $code = shift;

    for my $y (1..21) {
        for my $x (0..79) {
            $code->($self->at($x, $y));
        }
    }
}
# Iterates over a bounding rectangle containing all tiles whose
# visible glyphs have changed this step, and their neighbors.
sub each_changed_tile_and_neighbors {
    my $self = shift;
    my $code = shift;
    my $cartographer = TAEB->dungeon->cartographer;

    my ($t, $b, $l, $r);
    $t = $cartographer->tilechange_t || 1;
    $b = $cartographer->tilechange_b || 21;
    $l = $cartographer->tilechange_l || 0;
    $r = $cartographer->tilechange_r || 79;

    $t-- if $t > 1;
    $b++ if $b < 21;
    $l-- if $l > 0;
    $r++ if $r < 79;

    for my $y ($t..$b) {
        for my $x ($l..$r) {
            $code->($self->at($x, $y));
        }
    }
}


sub msg_dungeon_level {
    my $self = shift;
    my $level = shift;
    my $islevel = "is_$level";

    TAEB->log->level("Hey, I know this level! It's $level!")
        if !$self->$islevel;

    $self->branch('dungeons') if $level eq 'oracle'
                              || $level eq 'rogue'
                              || $level eq 'bigroom';

    $self->$islevel(1);
}

sub msg_level_message {
    my $self = shift;
    my $type = shift;

    TAEB->log->level("There's a $type on this level. Interesting.");

    $self->branch('dungeons') if $type eq 'vault';

    $self->is_minetown(1) if $type eq 'shop'
                          && $self->known_branch
                          && $self->branch eq 'mines';
}

subscribe turn => sub {
    my $self = shift;
    $self->inc_turns_spent_on;
};

sub glyph_to_type {
    my $self  = shift;
    my $glyph = shift;

    return $GLYPHS{$glyph} || 'obscured' unless @_;
    # glyph_to_type will always return 'rock' for blank tiles
    return $GLYPHS{$glyph}->[0] if $glyph eq ' ';

    # use color in an effort to differentiate tiles
    my $color = shift;

    return 'obscured' unless $GLYPHS{$glyph}
                          && $FEATURE_COLORS{$color};

    my @a = map { ref $_ ? @$_ : $_ } $GLYPHS{$glyph};
    my @b = map { ref $_ ? @$_ : $_ } $FEATURE_COLORS{$color};

    # calculate intersection of the two lists
    # because of the config chosen, given a valid glyph+color combo
    # we are guaranteed to only have one result
    # an invalid combination should not return any
    my %intersect;
    $intersect{$_} |= 1 for @a;
    $intersect{$_} |= 2 for @b;

   my $type = first { $intersect{$_} == 3 } keys %intersect;
   return $type || 'obscured';
}

sub glyph_is_monster {
    my $self = shift;
    return shift =~ /[a-zA-Z&';:1-5@]/;
}

sub glyph_is_item {
    my $self = shift;
    return shift =~ /[`?!%*()+=\["\$\/]/;
}


sub msg_farlooked {
    my $self = shift;
    my $tile = shift;
    my $msg  = shift;

    $tile->farlooked($msg);
}

subscribe tile_type_change => sub {
    my $self = shift;
    $self->fully_explored(0);
    $self->clear_astar_cache;
};

sub reblessed {
    my $self = shift;
    $self->dungeon->special_level->{ $self->special_level } = $self;
}

sub debug_line {
    my $self = shift;
    my $branch = $self->branch || '???';
    sprintf "branch=%s, dlvl=%d", $branch, $self->z;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 radiate CODE[, ARGS] -> (Str | (Str, Int))

This method will radiate in the eight NetHack directions. It will call the
coderef for each tile encountered. The coderef will receive the tile as its
argument. Once the coderef returns a true value, then the radiating stops and
something will be returned:

If called in scalar context, the vi-key direction will be returned. If called
in list context, the vi-key direction and distance will be returned.

The optional arguments are:

=over 4

=item max (default: 80)

How far to radiate outwards. You probably can't throw a dagger all the way
across the level, so you may want to decrease it to something more realistic.
Like 3, har har. You're weak.

If you're casting a spell, L<TAEB::World::Spell/minimum_range> and
L<TAEB::World::Spell/maximum_range> are your friends.

=item bouncy (default: false)

If true, the item will be assumed capable of bouncing.

=item stopper

If provided, this callback can be used to forbid a particular
direction because something is in the way (such as casting force
bolt when it could potentially hit a shopkeeper).

=item stopper_max (default: same as stopper)

This may be used to vary how far down the path you want to consider
stoppers, as separate from the regular target matching.

=item allowself (default: 0)

Like stopper, but for our own tile.

You might set this if you're zapping sleep which will bounce back
at you, but you have reflection or sleep resistance.

=item started_new_direction

A callback that is invoked every time a new direction is started
(including the first). Used so you can clear up any intermediate
state if needed.

=back

=head2 glyph_to_type str[, str] -> str

This will look up the given glyph (and if given color) and return a tile type
for it. Note that monsters and items (and any other miss) will return
"obscured".

=head2 glyph_is_monster str -> bool

Returns whether the given glyph is that of a monster.

=head2 glyph_is_item str -> bool

Returns whether the given glyph is that of an item.

=cut

