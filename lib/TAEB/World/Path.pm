package TAEB::World::Path;
use Moose;
use TAEB::OO;
use Heap::Simple;
use TAEB::Util qw/sum max refaddr/;
use TAEB::Util::World qw/delta2vi deltas/;
use Time::HiRes 'time';

with 'TAEB::Role::Actionable';

has from => (
    is       => 'ro',
    isa      => 'TAEB::World::Tile',
    required => 1,
);

has to => (
    is       => 'ro',
    isa      => 'TAEB::World::Tile',
    required => 1,
);

has path => (
    traits   => ['String'],
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    handles  => { length => 'length' },
);

has complete => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

has tiles => (
    is      => 'ro',
    isa     => 'HashRef[Int]',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $in   = {};
        my $tile = $self->from;

        for (split '', $self->path) {
            last if ++$in->{refaddr $tile} >= 2;
            $tile = $tile->level->at_direction($tile->x, $tile->y, $_)
                or last;
        }

        $in->{ refaddr $self->to } ||= 1;

        return $in;
    },
);

sub new {
    confess "You shouldn't call TAEB::World::Path->new directly. Use one of its path creation methods.";
}

sub calculate_path {
    my $class = shift;
    my $from  = @_ > 1 && @_ % 2 == 0 ? shift : TAEB->current_tile;
    my $to    = shift;
    my %args  = @_;

    my ($path, $complete) = $class->_calculate_path($from, $to, %args);

    if ($complete && $args{traverse_destination} && $to->can('traverse_command')) {
        $path .= $to->traverse_command;
    }

    Moose::Object::new($class,
        from     => $from,
        to       => $to,
        path     => $path,
        complete => $complete,
    );
}

sub first_match {
    my $class = shift;
    my $code = shift;
    return $class->max_match(sub { $code->(@_) ? 'q' : undef }, @_);
}

sub max_match {
    my $class = shift;
    my $code  = shift;
    my %args = @_;
    $args{from}     ||= TAEB->current_tile;
    $args{on_level} ||= TAEB->current_level;

    my ($to, $path);
    if ($args{on_level} != TAEB->current_level) {
        my $exit = $args{on_level}->exit_towards(TAEB->current_level)
            or return;

        my ($complete, $level);
        ($path, $complete, $level) = $class->_calculate_path(
            $args{from} => $exit,
            through_unknown => $args{through_unknown},
        );
        if (!$complete) {
            $args{interlevel_failure}->($level)
                if exists $args{interlevel_failure};
            return;
        }

        my $intralevel_path;
        ($to, $intralevel_path) = $class->_dijkstra($code,
                                                    (%args, from => $exit));
        if (!defined $intralevel_path) {
            $args{intralevel_failure}->() if exists $args{intralevel_failure};
            return;
        }

        $path .= $intralevel_path;
    }
    else {
        ($to, $path) = $class->_dijkstra($code, %args);
        if (!defined $path) {
            $args{intralevel_failure}->() if exists $args{intralevel_failure};
            return;
        }
    }

    $to or return;

    Moose::Object::new($class,
        from     => $args{from},
        to       => $to,
        path     => $path,
        complete => 1,
    );
}

sub _calculate_path {
    my $class = shift;
    my $from  = shift;
    my $to    = shift;
    my $path  = '';

    while ($from->level != $to->level) {
        my $exit = $from->level->exit_towards($to->level);
        return ($path, 0, $from->level) if !$exit;
        my ($p, $c) = $class->_calculate_intralevel_path($from, $exit, @_);

        $path .= $p if defined $p;
        return ($path, 0, $from->level) if !$c;

        $path .= $exit->traverse_command;

        $from = $exit->other_side;
    }

    my ($p, $c) = $class->_calculate_intralevel_path($from, $to, @_);

    $path .= $p if defined $p;

    return ($path, $c, $to->level);
}

sub _calculate_intralevel_path {
    my $class = shift;
    my $from  = shift;
    my $to    = shift;

    return ('', 1) if $from == $to;

    if ($from->level != $to->level) {
        confess "_calculate_intralevel_path called on tiles that weren't on the same level.";
    }

    my $path = $class->_astar($to, @_, from => $from);

    return ($path, defined($path) && length($path) ? 1 : 0);
}

sub _dijkstra {
    my $class  = shift;
    my $scorer = shift;
    my %args   = @_;

    my $from              = $args{from} || TAEB->current_tile;
    my $through_unknown   = $args{through_unknown};
    my $include_endpoints = $args{include_endpoints};
    my $sokoban           = $from->known_branch
                         && $from->branch eq 'sokoban';

    # XXX: this should be 600, but we aren't going to be able to get
    # the weight exact
    my $cant_squeeze = TAEB->inventory->weight > 500 || $sokoban;

    my $max_score;
    my $max_tile;
    my $max_path;

    my @closed;

    my $pq = Heap::Simple->new(elements => "Any");
    $pq->key_insert(0, [$from, '']);

    while ($pq->count) {
        my $priority = $pq->top_key;
        my ($tile, $path) = @{ $pq->extract_top };

        my $score = $scorer->($tile, $path, $priority);
        if (defined $score) {
            return ($tile, $path) if $score eq 'q';

            if (!defined($max_score) || $score > $max_score) {
                ($max_score, $max_tile, $max_path) = ($score, $tile, $path);
            }
        }

        if ($include_endpoints) {
            next unless $tile->is_walkable($through_unknown);
        }

        my ($x, $y) = ($tile->x, $tile->y);

        for (deltas) {
            my ($dy, $dx) = @$_;
            my $xdx = $x + $dx;
            my $ydy = $y + $dy;

            next if $xdx < 0 || $xdx > 79;
            next if $ydy < 1 || $ydy > 21;

            next if $closed[$xdx][$ydy];

            # can't move diagonally if we have lots in our inventory
            if ($cant_squeeze && $dx && $dy) {
                next unless $tile->level->at($xdx, $y)->is_walkable
                         || $tile->level->at($x, $ydy)->is_walkable;
            }

            # can't move diagonally off of doors
            next if $tile->isa('TAEB::World::Tile::Door')
                 && $dx
                 && $dy;

            my $next = $tile->level->at($xdx, $ydy)
                or next;

            # can't move diagonally onto doors
            next if $next->isa('TAEB::World::Tile::Door')
                 && $dx
                 && $dy;

            $closed[$xdx][$ydy] = 1;

            if (!$include_endpoints) {
                next unless $next->is_walkable($through_unknown);
            }

            my $dir = delta2vi($dx, $dy);
            my $cost = $next->intrinsic_cost;

            # ahh the things I do for aesthetics.
            $cost-- unless $dy && $dx;

            $pq->key_insert($cost + $priority, [$next, $path . $dir]);
        }
    }

    return ($max_tile, $max_path);
}

sub _astar {
    my $class  = shift;
    my $to     = shift;
    my %args   = @_;

    my ($tx, $ty) = ($to->x, $to->y);
    my $heur = $args{heuristic} || sub {
        return max(abs($tx - $_[0]->x), abs($ty - $_[0]->y));
    };

    my $from = $args{from} || TAEB->current_tile;
    my $through_unknown   = $args{through_unknown} || 0;
    my $key = join ":", (refaddr($to), refaddr($from), $through_unknown);
    my $level = $to->level;
    return $level->_get_cached_astar_path($key)
        if $level->_has_cached_astar_path($key);

    my $sokoban           = $from->known_branch
                         && $from->branch eq 'sokoban';
    my $cant_squeeze       = TAEB->inventory->weight > 500 || $sokoban;

    my @closed;

    my $pq = Heap::Simple->new(elements => "Any");
    $pq->key_insert(0, [$from, '']);

    while ($pq->count) {
        my $priority = $pq->top_key;
        my ($tile, $path) = @{ $pq->extract_top };

        if ($tile == $to) {
            $level->_cache_astar_path($key, $path);
            return $path;
        }

        my ($x, $y) = ($tile->x, $tile->y);

        for (deltas) {
            my ($dy, $dx) = @$_;
            my $xdx = $x + $dx;
            my $ydy = $y + $dy;

            next if $xdx < 0 || $xdx > 79;
            next if $ydy < 1 || $ydy > 21;

            next if $closed[$xdx][$ydy];

            # can't move diagonally if we have lots in our inventory
            # XXX: this should be 600, but we aren't going to be able to get
            # the weight exact
            if ($cant_squeeze && $dx && $dy) {
                next unless $tile->level->at($xdx, $y)->is_walkable
                         || $tile->level->at($x, $ydy)->is_walkable;
            }

            # can't move diagonally off of doors
            next if $tile->type eq 'opendoor'
                 && $dx
                 && $dy;

            my $next = $tile->level->at($xdx, $ydy)
                or next;

            next unless $next->is_walkable($through_unknown);

            # can't move diagonally onto doors
            next if $next->type eq 'opendoor'
                 && $dx
                 && $dy;

            $closed[$xdx][$ydy] = 1;

            my $dir = delta2vi($dx, $dy);
            my $cost = $next->intrinsic_cost + $heur->($next);

            # ahh the things I do for aesthetics.
            $cost-- unless $dy && $dx;

            $pq->key_insert($cost + $priority, [$next, $path . $dir]);
        }
    }

    $level->_cache_astar_path($key, undef);
    return;
}

sub contains_tile {
    my $self = shift;
    my $tile = shift;

    return $self->tiles->{refaddr $tile};
}

sub as_action {
    my $self = shift;
    return TAEB::Action::Move->new(path => $self);
}

sub spans_multiple_levels {
    my $self = shift;
    return $self->from->level != $self->to->level;
}

sub each_tile {
    my $self = shift;
    my $cb = shift;

    my $current = $self->from;

    for my $dir (split '', $self->path) {
        my $next = $current->level->at_direction($current->x, $current->y, $dir);
        if (!$cb->($next, $current, $dir)) {
            last;
        }
    }

    return $current;
}

sub intralevel_subpath {
    my $self = shift;

    my $new_path = '';

    my $new_to = $self->each_tile(sub {
        my ($next, $previous, $dir) = @_;

        return 0 unless if $next->level == $previous->level;

        $new_path .= $dir;

        return 1;
    });

    return if $new_path eq '';

    return Moose::Object::new(blessed($self), (
        from     => $self->from,
        to       => $new_to,
        path     => $new_path,
        complete => 1,
    ));
}

sub next_tile {
    my $self = shift;
    my $from = $self->from;
    my $dir = substr($self->path, 0, 1);

    return unless $dir;
    return $from->level->at_direction($from->x, $from->y, $dir);
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

__END__

=head2 calculate_path [Tile,] Tile -> Path

Calculates the best path from Tile 1 to Tile 2. Returns the path object. If the
path is incomplete, it probably leads to some unexplored area between the two
tiles.

The path may not necessarily be the shortest one. It may relax the path a bit
to avoid a dangerous trap, for example.

The "from" tile is optional. If elided, TAEB's current tile will be used.

=head2 first_match Code, ARGS -> Maybe Path

This will return a path to the first tile for which the coderef returns a true
value.

=head2 max_match Code, ARGS -> Maybe Path

This will return a path to the first tile for which the coderef returns the
maximum value.

=head2 _calculate_path Tile, Tile[, ARGS] -> Str, Bool, Level

Used internally by calculate_path -- returns just (path, complete, level),
where level is the level that the path ended on (not necessarily to->level if
the path was incomplete).

=head2 _calculate_intralevel_path Tile, Tile[, ARGS] -> Str, Bool

Same as _calculate_path, except the Tiles are supposed to be on the same level.
This is to simplify some internals. The results are undefined if the tiles
are not on the same level (most likely there'll be a controlled detonation).

=head2 _dijkstra Code, ARGS -> Tile, Str

This performs a search for some tile. The code reference is evaluated for each
tile along the way. It receives the current tile, the path to it, and the
path's cost thus far as its arguments. It's expected to return one of the
following:

=over 4

=item The string 'q'

This indicates that the search may be short-circuited, returning this tile.
This can be used when searching for a known tile.

=item A number

This is used to score relative tiles. The tile with the maximum score will
be returned from C<_dijkstra>.

=item C<undef>

This is used to indicate that the current tile is not a valid solution.

=back

The optional arguments are:

=over 4

=item from (default: TAEB->current_tile)

The starting tile

=item through_unknown (default: false)

Whether to assume unknown tiles are walkable

=item include_endpoints (default: false)

Whether to include nonwalkable endpoints in the scorer checks (in essence, do
you want to include monsters, walls, etc as targets?)

=head2 _astar Tile, ARGS -> Maybe[Str]

=cut

