package TAEB::AI::Role::Path::AStar;
use Moose::Role;
use TAEB::OO;
use TAEB::Util qw/sum max refaddr/;
use TAEB::Util::World qw/delta2vi deltas/;

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

sub astar {
    my $self   = shift;
    my $class  = shift;
    my $to     = shift;
    my %args   = @_;

    my ($tx, $ty) = ($to->x, $to->y);
    my $heur = $args{heuristic} || sub {
        return max(abs($tx - $_[0]->x), abs($ty - $_[0]->y));
    };

    my $from = $args{from};
    my $through_unknown = $args{through_unknown} || 0;
    my $key = join ":", (refaddr($to), refaddr($from), $through_unknown);
    return $self->_get_cached_astar_path($key)
        if $self->_has_cached_astar_path($key);

    my $sokoban  = $from->known_branch
                && $from->branch eq 'sokoban';
    my $cant_squeeze = TAEB->inventory->weight > 500 || $sokoban;

    my @closed;

    my $pq = Heap::Simple->new(elements => "Any");
    $pq->key_insert(0, [$from, '']);

    while ($pq->count) {
        my $priority = $pq->top_key;
        my ($tile, $path) = @{ $pq->extract_top };

        if ($tile == $to) {
            $self->_cache_astar_path($key, $path);
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

    $self->_cache_astar_path($key, undef);
    return;
}

no Moose::Role;
no TAEB::OO;

1;
