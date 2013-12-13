package TAEB::Action::Role::Direction;
use Moose::Role;
use TAEB::OO;
use TAEB::Util 'none';
use TAEB::Util::World 'vi2delta';

has direction => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_direction',
    provided  => 1,
);

has target_tile => (
    is       => 'ro',
    isa      => 'Maybe[TAEB::World::Tile]',
    init_arg => undef,
    lazy     => 1,
    default  => sub {
        my $direction = shift->direction;
        return unless $direction;
        return TAEB->current_level->at_direction($direction);
    },
);

has victim_tile => (
    is       => 'rw',
    isa      => 'TAEB::World::Tile',
    init_arg => undef,
);

sub respond_what_direction { shift->direction }

before run => sub {
    my $self = shift;
    my $direction = $self->direction;

    return unless $direction;
    return if $direction eq '<' || $direction eq '>';

    my ( $x,  $y) = (TAEB->x, TAEB->y);
    my ($dx, $dy) = vi2delta($direction);

    return unless $dx || $dy;

    while (1) {
        $x += $dx;
        $y += $dy;

        my $tile = TAEB->current_level->at_safe($x, $y) or last;

        if ($tile->has_monster) {
            $self->victim_tile($tile);
            last;
        }

        $tile->is_walkable(1) or last;
    }
};

around target_tile => sub {
    my $orig = shift;
    my $self = shift;

    my $tile = $self->$orig;

    if (@_ && none { $tile->type eq $_ } @_) {
        TAEB->log->action(blessed($self) . " can only handle tiles of type: @_", level => 'warning');
    }

    return $tile;
};

sub msg_killed {
    my ($self, $monster_name) = @_;

    return unless defined $self->victim_tile;

    $self->victim_tile->witness_kill($monster_name);
}

no Moose::Role;
no TAEB::OO;

1;

