package TAEB::World::Tile;
use Moose;
use TAEB::OO;
use TAEB::Util qw/any all apply first/;
use TAEB::Util::World qw/delta2vi vi2delta/;
use TAEB::Util::Colors;

with 'TAEB::Role::Reblessing', 'TAEB::Role::Overload';

has level => (
    is       => 'ro',
    isa      => 'TAEB::World::Level',
    weak_ref => 1,
    required => 1,
    handles  => [qw/z known_branch branch glyph_to_type glyph_is_item/],
);

has type => (
    is      => 'rw',
    isa     => 'TAEB::Type::Tile',
    default => 'unexplored',
);

has glyph => (
    is      => 'rw',
    isa     => 'Str',
    default => ' ',
);

has itemly_glyph => (
    is      => 'rw',
    isa     => 'Str',
    default => ' ',
);

has itemly_color => (
    is      => 'rw',
    isa     => 'TAEB::Display::Color',
    default => sub { COLOR_NONE },
);

has floor_glyph => (
    is      => 'rw',
    isa     => 'Str',
    default => ' ',
);

has color => (
    is      => 'rw',
    isa     => 'TAEB::Display::Color',
    default => sub { COLOR_NONE },
);

has stepped_on => (
    is        => 'ro',
    traits    => ['Counter'],
    handles   => {
        inc_stepped_on => 'inc',
        dec_stepped_on => 'dec',
    },
    default  => 0,
);

has x => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has y => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has searched => (
    is        => 'ro',
    traits    => ['Counter'],
    handles   => {
        inc_searched => 'inc',
        dec_searched => 'dec',
    },
    default   => 0,
);

has explored => (
    is       => 'rw',
    isa      => 'Bool',
    default  => 0,
);

has nondiggable => (
    is       => 'rw',
    isa      => 'Bool',
    default  => 0,
);

# Is there an object on this square that's known to be a boulder,
# rather than a mimic just pretending?
has known_genuine_boulder => (
    is       => 'rw',
    isa      => 'Bool',
    default  => 0,
);

has engraving => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
    trigger => sub {
        my $self = shift;
        my $engraving = shift;
        if (length($engraving) > 255) {
            # Three-argument substr returns an lvalue with magic;
            # passing this directly to $self->engraving causes it to
            # fail the type constraint (technically, the return from
            # substr is not a 'Str'). This interpolation method strips
            # the magic and allows the code to run.
            my $shortened = substr($engraving, 0, 255);
            $self->engraving("$shortened");
        }
    },
);

has engraving_type => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
    documentation => "Store the writing type",
);

has has_unknown_items => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
    writer  => 'set_has_unknown_items',
);

has monster => (
    is        => 'rw',
    isa       => 'TAEB::World::Monster',
    clearer   => '_clear_monster',
    predicate => 'has_monster',
);

has items => (
    traits     => ['Array'],
    isa        => 'ArrayRef[NetHack::Item]',
    default    => sub { [] },
    handles    => {
        items           => 'elements',
        item_idx        => 'get',
        add_item        => 'push',
        clear_items     => 'clear',
        remove_item_idx => 'delete',
        item_count      => 'count',
    },
);

has last_step => (
    is            => 'rw',
    isa           => 'Int',
    documentation => "The last step that we were on this tile",
);

has last_turn => (
    is            => 'rw',
    isa           => 'Int',
    default       => 0,
    documentation => "The last turn that we were on this tile",
);

has in_shop => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => "Is this tile inside a shop?",
);

has in_temple => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => "Is this tile inside a temple?",
);

has in_vault => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => "Is this tile inside a vault?",
);

has in_zoo => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => "Is this tile inside a zoo?",
);

has is_lit => (
    is            => 'rw',
    isa           => 'Maybe[Bool]',
    documentation => "Is this tile probably lit?  Will usually be wrong except on floor and corridors.",
);

has kill_times => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        _add_kill_time    => 'push',
        _clear_kill_times => 'clear',
    },
    documentation => "Kills which have been committed on this tile.  " .
        "Each element is an arrayref with a monster name, a turn number, " .
        "and a force_verboten (used for unseen kills) flag.",
);

has intrinsic_cost => (
    is      => 'ro',
    isa     => 'Int',
    builder => '_build_intrinsic_cost',
    clearer => 'invalidate_intrinsic_cost_cache',
    lazy    => 1,
);

sub _build_intrinsic_cost {
    my $self = shift;
    my $cost = 100;

    $cost *= 20  if $self->has_monster;
    $cost *= 10  if $self->type eq 'trap';
    $cost *= 4   if $self->type eq 'ice';
    $cost *= 1.1 if !$self->is_engravable;

    # avoid traps
    # corridors can have traps (like trap doors, level teleporters) but they're
    # tame compared to the traps that exist in normal rooms
    $cost = $cost * .9
        if $self->stepped_on
        || $self->type eq 'corridor';

    # prefer stairs (since they're good for escaping, and can't be traps)
    $cost = $cost * .8
        if $self->type eq 'stairsup'
        || $self->type eq 'stairsdown';

    return int($cost);
}

# The NetHack display is structured as three layers; when we see a glyph,
# we can easily ID which layer it belongs to, then we set the higher layers
# to clear, and don't change what we know about the lower layers.  There's
# a bit of a special case for the floor, since if we see any item or any
# non-phasing monster, we know it's not rock; this case is very common, so
# not rock has a name, 'obscured'.
#
# The top layer, monsters, is handled seperately in try_monster.  See
# Cartographer for the overriding logic.
sub update {
    my $self        = shift;
    my $newglyph    = shift;
    my $color       = shift;
    my $oldtype     = $self->type;
    my $oldglyph    = $self->glyph;

    # gas spore explosions should not update the map
    # XXX what's this for?  we don't run the AI until we've seen all
    # output anyway, and worse things than this will break if we lose
    # sync
    # isn't it supposed to be green?
    return if $newglyph =~ m{^[\\/-]$} && $color == COLOR_RED;

    $self->glyph($newglyph);
    $self->color($color);

    $self->update_lit;

    $self->invalidate_intrinsic_cost_cache;

    # boulder messages
    TAEB->announce('boulder_change', 'tile' => $self)
        if $oldglyph eq '0' xor $newglyph eq '0';

    # dark rooms
    return if $self->glyph eq ' ' && $self->floor_glyph eq '.';

    my $newtype = $self->glyph_to_type($newglyph, $color);

    # rock next to where we're standing is definitely rock, unless
    # we're blinded; otherwise, it's unexplored if it was unexplored
    # before or if we weren't sure
    if ($newtype eq 'rock') {
        $newtype = 'unexplored' if $self->type eq 'unexplored'
                                || $self->type eq 'obscured';
        $newtype = 'rock' if abs($self->x - TAEB->x) <= 1
                          && abs($self->y - TAEB->y) <= 1
                          && !TAEB->is_blind;
    }

    # if we unveil a square and it was previously rock, then it's obscured
    # perhaps we entered a room and a tile changed from ' ' to '!'
    # if the tile's type was anything else, then it *became* obscured, and we
    # don't want to change what we know about it
    # XXX: if the type is olddoor then we probably kicked/opened the door and
    # something walked onto it. this needs improvement
    $self->change_itemview($newglyph, $color)
        unless $self->has_monster ||
            ($self->x == TAEB->x && $self->y == TAEB->y);

    if ($newtype eq 'obscured') {
        # ghosts and xorns and earth elementals should not update the map
        return if $newglyph eq 'X'
               || ($newglyph eq 'E' && $color == COLOR_BROWN);

        return unless $oldtype eq 'rock'
                   || $oldtype eq 'unexplored'
                   || $oldtype eq 'wall'
                   || $oldtype eq 'closeddoor';
    } else {
        # If the tile is not obscured, there are no items on it.
        $self->clear_items;
    }

    # If floor_glyph is space but the type is not rock, we've had information
    # implanted into us by T:S:Map.  Don't break that.
    return if ($self->floor_glyph eq ' ' && $newtype eq 'unexplored');

    $self->change_type($newtype => $newglyph);
}

my %is_walkable = map { $_ => 1 } qw/obscured stairsdown stairsup trap altar opendoor floor ice grave throne sink fountain corridor/;
sub is_walkable {
    my $self = shift;
    my $through_unknown = shift;
    my $dont_check_current_tile = shift;

    # current tile is always walkable, but don't check it if our caller
    # asked us not to (that check is rather slow)
    return 1 if !defined($dont_check_current_tile)
             && $self == TAEB->current_tile;

    # pathing through boulders is handled by dedicated behaviors
    return 0 if $self->has_boulder;

    # monsters are not pathable!
    if ($self->has_monster) {
        # XXX: but non-adjacent shks are, for now
        return $self->monster->is_shk
            && (abs($self->x - TAEB->x) > 1 || abs($self->y - TAEB->y) > 1);
    }

    # traps are unpathable in Sokoban
    return 0 if $self->type eq 'trap'
             && $self->level->known_branch
             && $self->level->branch eq 'sokoban';

    # we can path through unlit areas that we haven't seen as rock for sure yet
    # if we're blind, then all bets are off
    return 1 if $through_unknown
             && $self->is_unknown;

    return $is_walkable{ $self->type };
}

sub is_inherently_unwalkable {
    my $self = shift;
    my $through_unknown = shift;
    my $dont_check_current_tile = shift;

    # current tile is always walkable, but don't check it if our caller
    # asked us not to (that check is rather slow)
    return 0 if !defined($dont_check_current_tile)
             && $self == TAEB->current_tile;

    # traps are unpathable in Sokoban
    return 1 if $self->type eq 'trap'
             && $self->level->known_branch
             && $self->level->branch eq 'sokoban';

    # we can path through unlit areas that we haven't seen as rock for sure yet
    # if we're blind, then all bets are off
    return 0 if $through_unknown
             && $self->is_unknown;

    return not $is_walkable{ $self->type };
}

sub is_unknown { !TAEB->is_blind && shift->type eq 'unexplored' }

sub update_lit {
    my $self = shift;

    my $within_night_vision = abs(TAEB->x - $self->x) <= 1
                           && abs(TAEB->y - $self->y) <= 1;

    # A square which is displayed as . must be lit from some source, unless
    # it is right next to us.

    $self->is_lit(1) if $self->glyph eq '.' && !$within_night_vision;

    # If it was displayed as ., but turned to a space, it must not have been
    # lit after all, or it would have stayed ..

    $self->is_lit(0) if $self->glyph eq ' ' && $self->floor_glyph eq '.';

    # Corridors are lit if and only if they are brightly colored.

    $self->is_lit($self->color == COLOR_WHITE) if $self->glyph eq '#';

    # Other types of tiles cannot have light status easily determined.
    # Fortunately, they are rare and we usually do not fight on them.
}

sub step_on {
    my $self = shift;

    $self->inc_stepped_on;
    $self->explored(1);
    $self->last_turn(TAEB->turn);
    $self->last_step(TAEB->step);
    $self->set_has_unknown_items(0);
}

sub step_off {
    my $self = shift;

    $self->set_has_unknown_items(0);

    if ($self->level == TAEB->current_level) {
        # When we step off a tile, anything that's nearby and still . is lit
        $self->each_adjacent(sub {
            my ($tile, $dir) = @_;
            $tile->update_lit;
        });
    }
}

sub witness_kill {
    my ($self, $critter) = @_;

    return if TAEB->is_hallucinating;
    $self->_add_kill_time([ $critter, TAEB->turn, 0 ]);
}

sub iterate_tiles {
    my $self       = shift;
    my $controller = shift;
    my $usercode   = shift;
    my $directions = shift;

    my ($x, $y) = ($self->x, $self->y);

    if ($y <= 0) {
        TAEB->log->tile("" . (caller 1)[3] . " called with a y argument of ".$self->y.". This usually indicates an unhandled prompt.", level => 'error');
    }

    my $level = $self->level;

    my @tiles = grep { defined } map {
                                     $level->at_safe(
                                         $x + $_->[0],
                                         $y + $_->[1]
                                     )
                                 } @$directions;

    $controller->(sub {
        $usercode->($_, delta2vi($_->x - $x, $_->y - $y));
    }, @tiles);
}

my %tiletypes = (
    diagonal => [
        [-1, -1],          [-1, 1],

        [ 1, -1],          [ 1, 1],
    ],
    orthogonal => [
                  [-1, 0],
        [ 0, -1],          [ 0, 1],
                  [ 1, 0],
    ],
    adjacent => [
        [-1, -1], [-1, 0], [-1, 1],
        [ 0, -1],          [ 0, 1],
        [ 1, -1], [ 1, 0], [ 1, 1],
    ],
    adjacent_inclusive => [
        [-1, -1], [-1, 0], [-1, 1],
        [ 0, -1], [ 0, 0], [ 0, 1],
        [ 1, -1], [ 1, 0], [ 1, 1],
    ],
);
my %controllers = (
    each => \&apply,
    all  => \&all,
    any  => \&any,
    grep => sub { my $code = shift; grep { $code->($_) } @_ },
);

for my $tiletype (keys %tiletypes) {
    for my $name (keys %controllers) {
        __PACKAGE__->meta->add_method("${name}_${tiletype}" => sub {
            my $self = shift;
            my $code = shift;
            $self->iterate_tiles($controllers{$name},
                                 $code,
                                 $tiletypes{$tiletype})
        })
    }
}

sub elbereths {
    my $self = shift;
    my $engraving = $self->engraving;
    return $engraving =~ s/elbereth//gi || 0;
}

sub floodfill {
    my $self               = shift;
    my $continue_condition = shift;
    my $update_tile        = shift;

    return unless $continue_condition->($self);

    my @queue = $self;
    my %seen;

    while (my $tile = shift @queue) {
        next if $seen{$tile}++;
        $update_tile->($tile);

        $tile->each_adjacent(sub {
            my $t = shift;
            if (!$seen{$t} && $continue_condition->($t)) {
                push @queue, $t;
            }
        });
    }
}

sub base_class { __PACKAGE__ }

sub change_type {
    my $self     = shift;
    my $newtype  = shift;
    my $newglyph = shift;

    return if $self->type eq $newtype && $self->floor_glyph eq $newglyph;
    return if $self->level->is_rogue && $self->type eq 'stairsup';
    TAEB->announce('tile_type_change' => 'tile' => $self);

    $self->level->unregister_tile($self);

    $self->type($newtype);
    $self->floor_glyph($newglyph);

    $self->level->register_tile($self);

    $self->rebless("TAEB::World::Tile::\L\u$newtype", @_);
}

sub change_itemview {
    my ($self, $newglyph, $newcolor) = @_;

    return if $self->itemly_glyph eq $newglyph
           && $self->itemly_color == $newcolor;

    $self->itemly_glyph($newglyph);
    $self->itemly_color($newcolor);

    $self->set_has_unknown_items($self->glyph_is_item($newglyph) ? 1 : 0);
}

sub debug_line {
    my $self = shift;
    my @bits;

    push @bits, sprintf '(%d,%d)', $self->x, $self->y;
    push @bits, $1 if (blessed $self) =~ /TAEB::World::Tile::(.+)/;
    push @bits, 't=' . $self->type;

    push @bits, 'g<' . $self->glyph . '>';
    push @bits, 'i<' . $self->itemly_glyph . '>'
        if $self->glyph ne $self->itemly_glyph;
    push @bits, 'f<' . $self->floor_glyph . '>'
        if $self->itemly_glyph ne $self->floor_glyph;

    push @bits, sprintf 'i=%d%s',
                    $self->item_count,
                    $self->has_unknown_items ? '*' : '';

    if ($self->engraving) {
        push @bits, sprintf 'E=%d/%d',
                        length($self->engraving),
                        $self->elbereths;
    }

    push @bits, 'lit'   if defined $self->is_lit && $self->is_lit;
    push @bits, 'unlit' if defined $self->is_lit && !$self->is_lit;
    push @bits, 'shop'  if $self->in_shop;
    push @bits, 'vault' if $self->in_vault;

    if ($self->has_enemy) {
        push @bits, 'enemy';
    }
    elsif ($self->has_monster) {
        push @bits, 'monster';
    }

    return join ' ', @bits;
}

sub try_monster {
    my ($self, $glyph, $color) = @_;

    my $level = $self->level;

    # attempt to handle ghosts on the rogue level, which are always the
    # same glyphs as rocks. rogue level ignores your glyph settings.
    if ($glyph eq ' ' && $level->is_rogue && !TAEB->is_blind) {
        return unless abs($self->x - TAEB->x) <= 1
                   && abs($self->y - TAEB->y) <= 1;

        # if we're standing in a corridor, unexplored wall tiles are still
        # ' ' glyphs. this does mean that ghosts in corridors won't be noticed,
        # but there's not much we can do about that
        return unless TAEB->current_tile->type ne 'corridor'
                   && $self->any_adjacent(sub { shift->type eq 'floor' });

        $glyph = 'X';
        $color = COLOR_GRAY;
    }
    else {
        return unless $level->glyph_is_monster($glyph);
    }

    my $monster = TAEB::World::Monster->new(
        glyph => $glyph,
        color => $color,
        tile  => $self,
    );

    $self->monster($monster);
}

before _clear_monster => sub {
    my $self = shift;
    $self->level->remove_monster($self->monster);
};

after monster => sub {
    my $self = shift;
    return unless @_;
    $self->level->add_monster($_[0]);
};

sub has_enemy {
    my $monster = shift->monster
        or return 0;
    return $monster->is_enemy ? $monster : undef;
}

sub has_friendly {
    my $monster = shift->monster
        or return 0;
    return $monster->is_enemy ? undef : $monster;
}

sub has_boulder { shift->glyph eq '0' }

sub is_engravable {
    my $self = shift;

    return $self->type ne 'fountain'
        && $self->type ne 'altar'
        && $self->type ne 'grave';
}

sub normal_color {
    my $color = shift->color;
    return COLOR_NONE if !defined($color);
    $color = COLOR_WHITE if $color == COLOR_NONE;
    return $color;
}

sub debug_color {
    my $self = shift;

    my $color = $self->in_shop || $self->in_temple ? COLOR_BRIGHT_GREEN
              : $self->has_enemy                   ? COLOR_ORANGE
              : $self->has_unknown_items           ? COLOR_RED
              : $self->searched > 5                ? COLOR_CYAN
              : $self->stepped_on                  ? COLOR_BROWN
              : $self->explored                    ? COLOR_GREEN
                                                   : COLOR_WHITE;

    return $color;
}

sub lit_color {
    my $self = shift;

    return $self->is_lit          ? COLOR_YELLOW
         : !defined $self->is_lit ? COLOR_BROWN
                                  : COLOR_WHITE;
}

sub los_color { shift->in_los ? COLOR_YELLOW : COLOR_GRAY }

sub stepped_color {
    my $self = shift;
    my $stepped = $self->stepped_on;

    return COLOR_WHITE  if $stepped == 0;
    return COLOR_RED    if $stepped == 1;
    return COLOR_ORANGE if $stepped == 2;
    return COLOR_BROWN  if $stepped < 5;
    return COLOR_YELLOW if $stepped < 8;
    return COLOR_MAGENTA;
}

sub time_color {
    my $self = shift;
    my $last_turn = $self->last_turn;
    my $dt = TAEB->turn - $last_turn;

    return COLOR_WHITE          if $last_turn == 0;
    return COLOR_RED            if $dt > 1000;
    return COLOR_ORANGE         if $dt > 500;
    return COLOR_BROWN          if $dt > 100;
    return COLOR_YELLOW         if $dt > 50;
    return COLOR_MAGENTA        if $dt > 25;
    return COLOR_BRIGHT_MAGENTA if $dt > 15;
    return COLOR_GREEN          if $dt > 10;
    return COLOR_BRIGHT_GREEN   if $dt > 5;
    return COLOR_CYAN           if $dt > 3;
    return COLOR_BRIGHT_CYAN;
}

sub engraving_color {
    my $self = shift;

    return COLOR_BRIGHT_MAGENTA if $self->elbereths;
    return COLOR_GREEN if $self->engraving ne '';
    return COLOR_GRAY;
}

sub normal_glyph {
    my $self = shift;
    my $glyph = $self->glyph;
    return $glyph unless $glyph eq ' ';
    return $self->floor_glyph;
}

sub farlooked {}

# keep track of our items on the level object {{{
after add_item => sub {
    my $self = shift;
    $self->level->add_item(@_);

    for my $item (@_) {
        next unless $item->match(subtype => 'corpse');

        my @kl = @{ $self->kill_times };
        my ($date, $v) = (undef, 0);

        # I think this should be about 749, but the consequences of failure
        # are enough to motivate paranoia
        @kl = grep { $_->[1] >= TAEB->turn - 1000 } @kl;

        for my $kill (@kl) {
            my ($name, $age, $bad) = @$kill;

            my $monster = NetHack::Monster::Spoiler->lookup(
                $name,
                # werefoo always leave human corpses
                $name =~ /^were/ ? (glyph => '@') : (),
            );
            $age -= 100 if $monster->is_undead;
            $name = $monster->corpse_type->name;

            next unless $name eq $item->monster->name;

            if (!defined($date) || $date > $age) {
                $date = $age;
            }

            $v ||= $bad;
        }

        if (!defined($date)) {
            # This corpse has no kill record!  It must have died out of sight.
            push @kl, [ $item->monster->name, TAEB->turn, 1 ];
            $date = TAEB->turn;
            $v = 1;
        }

        $item->estimated_date($date);
        $item->is_forced_verboten($v);
        $item->buc('uncursed') unless $v;

        @{ $self->kill_times } = @kl;
    }
};

before clear_items => sub {
    my $self = shift;
    for my $item ($self->items) {
        $self->_remove_level_item($item);
    }
};

sub remove_item {
    my $self = shift;
    my $item = shift;

    my @items = $self->items;
    for my $i (0 .. $#items) {
        if ($item == $items[$i]) {
            return $self->remove_item_idx($i);
        }
    }
}

before remove_item_idx => sub {
    my $self = shift;
    my $idx = shift;
    $self->_remove_level_item($self->item_idx($idx));
};

sub _remove_level_item {
    my $self = shift;
    my $item = shift;
    my $level = $self->level;

    for my $i (0 .. $level->item_count - 1) {
        my $level_item = $level->item_idx($i);
        if ($item == $level_item) {
            $level->remove_item_idx($i);
            return;
        }
    }
}
# }}}

# keep track of which tiles has_unknown_items on the level object
# also announce if it started having unknown items
before set_has_unknown_items => sub {
    my $self = shift;
    my $set = shift(@_) ? 1 : 0;

    my $has_unknown_items = $self->has_unknown_items ? 1 : 0;

    # no change? don't care
    return if $set == $has_unknown_items;

    if ($set) {
        $self->level->register_tile($self => 'unknown_items');
        TAEB->publisher->announce(tile_has_unknown_items => tile => $self);
    }
    else {
        $self->level->unregister_tile($self => 'unknown_items');
    }
};

sub is_empty {
    my $self = shift;

    # probably okay for now, we may want to check items monster etc explicitly
    # though
    return $self->glyph eq $self->floor_glyph;
}

my %opaque = map { $_ => 1 } qw(unexplored rock wall tree closeddoor cloud water);

sub is_transparent {
    my $self = shift;

    return !$opaque{$self->type} && !$self->has_boulder;
}

my %shows_items = map { $_ => 1 } qw(floor ice trap stairsup stairsdown altar grave throne sink fountain corridor air);

sub shows_items {
    my $self = shift;
    return 0 if !$self->is_lit;

    return $shows_items{$self->type};
}

sub in_los {
    my $self = shift;

    return 0 if $self->level != TAEB->current_level;

    return TAEB->fov->[$self->x][$self->y];
}

sub distance {
    my $self  = shift;
    my $other = shift || TAEB->current_tile;

    return if $self->level != TAEB->current_level;

    return sqrt(($self->x - $other->x) ** 2 + ($self->y - $other->y) ** 2);
}

sub find_item_maybe {
    my $self       = shift;
    my $predicate  = shift;

    if (!ref($predicate)) {
        my $item = TAEB->new_item($predicate);
        $predicate = sub { $_->maybe_is($item) };
    }

    # The & ignores first's prototype. $predicate is a function so it'll work
    return &first($predicate, $self->items);
}

sub find_item {
    my $self = shift;

    return first { $_->match(@_) } $self->items if !wantarray;
    return grep { $_->match(@_) } $self->items;
}

sub unexplored {
    confess "Set 'explored' not 'unexplored'" if @_ > 1;
    not shift->explored;
}

sub is_searchable {
    my $self = shift;

    return $self->type eq 'wall'
        || $self->type eq 'rock'
        || $self->type eq 'unexplored';
}

sub at_direction {
    my $self      = shift;
    my $direction = shift;

    if ($direction eq '<' || $direction eq '>') {
        if ($self->isa('TAEB::World::Tile::Stairs')
         && $self->traverse_command eq $direction) {
            return $self->other_side;
        }
        else {
            my $error = sprintf "Tried to find the other side of %sstaircase",
                $self->isa('TAEB::World::Tile::Stairs')
                    ? "the wrong type of " : "a non-";
            TAEB->log->level($error, level => 'error');
            return;
        }
    }

    my ($dx, $dy) = vi2delta($direction);
    $self->level->at($self->x + $dx, $self->y + $dy);
}

sub from_direction {
    my $self      = shift;
    my $direction = shift;

    return $self->at_direction('<') if $direction eq '>';
    return $self->at_direction('>') if $direction eq '<';

    my ($dx, $dy) = vi2delta($direction);
    my $from_direction = delta2vi(-$dx, -$dy);

    return $self->at_direction($from_direction);
}

# XXX handle multiple containers, and nested containers
sub container {
    my $self = shift;

    my ($container) = grep { $_->isa('NetHack::Item::Tool::Container') }
                           $self->items;

    return $container;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 update_lit :: ()

Looks at the current glyph and position to make inferences about lighting
state.

=head2 is_empty -> Bool

Returns true if the tile is free from items, monsters, boulders, and the player
character.

It *can* have a dungeon feature, such as a fountain.

=head2 is_transparent -> Bool

Returns true if the player can see through the tile.

=head2 shows_items -> Bool

=head2 in_los -> Bool

=cut

