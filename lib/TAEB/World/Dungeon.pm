package TAEB::World::Dungeon;
use Moose;
use TAEB::OO;
use TAEB::Util 'refaddr';

has levels => (
    is      => 'ro',
    isa     => 'ArrayRef[ArrayRef[TAEB::World::Level]]',
    default => sub { [] },
);

has current_level => (
    is      => 'rw',
    isa     => 'TAEB::World::Level',
    handles => [qw/z/],
);

has special_level => (
    is      => 'ro',
    isa     => 'HashRef[TAEB::World::Level]',
    default => sub { {} },
);

has cartographer => (
    is      => 'ro',
    isa     => 'TAEB::World::Cartographer',
    default => sub {
        my $self = shift;
        TAEB::World::Cartographer->new(dungeon => $self)
    },
    handles => [qw/update x y map_like fov/],
);

around current_level => sub {
    my $orig = shift;
    my $self = shift;
    return $orig->($self) unless @_;
    TAEB->publisher->unsubscribe($self->current_level)
        if $self->current_level;
    my $ret = $orig->($self, @_);
    TAEB->publisher->subscribe($self->current_level);
    return $ret;
};

# we start off in dungeon 1. this helps keeps things tidy (we only have to
# worry about level generation on level change)
sub BUILD {
    my $self = shift;
    $self->current_level( $self->create_level(1, branch => 'dungeons') );
}

sub current_tile {
    my $self = shift;
    my $cartographer = $self->cartographer;
    $self->current_level->at($cartographer->x, $cartographer->y);
}

for my $tiletype (qw/orthogonal diagonal adjacent adjacent_inclusive/) {
    for my $controllertype (qw/each any all grep/) {
        my $method = "${controllertype}_${tiletype}";
        __PACKAGE__->meta->add_method($method => sub {
            my $self = shift;
            my $code = shift;
            my $tile = shift || $self->current_tile;

            $tile->$method($code);
        })
    }
}

sub nearest_level_to {
    my $self = shift;
    my $code = shift;
    my @queue = shift;

    my %seen;

    while (my $level = shift @queue) {
        ++$seen{refaddr $level};
        return $level if $code->($level);

        push @queue, grep { !$seen{refaddr $_} } $level->adjacent_levels;
    }

    return;
}

sub nearest_level {
    my $self = shift;
    my $code = shift;
    return $self->nearest_level_to($code, TAEB->current_level);
}

sub shallowest_level {
    my $self = shift;
    my $code = shift;
    return $self->nearest_level_to($code, ($self->get_levels(1))[0]);
}

sub farthest_level_from {
    my $self = shift;
    my $code = shift;
    my @queue = shift;

    my %seen;

    my $ret;
    while (my $level = shift @queue) {
        ++$seen{refaddr $level};
        $ret = $level if $code->($level);

        push @queue, grep { !$seen{refaddr $_} } $level->adjacent_levels;
    }

    return $ret;
}

sub farthest_level {
    my $self = shift;
    my $code = shift;
    return $self->farthest_level_from($code, TAEB->current_level);
}

sub deepest_level {
    my $self = shift;
    my $code = shift;
    return $self->farthest_level_from($code, ($self->get_levels(1))[0]);
}

sub get_levels {
    my $self = shift;
    my $dlvl = shift;
    my $index = $dlvl - 1;

    if (!wantarray) {
        TAEB->log->dungeon("Called get_levels in scalar context. Fix your code.", level => 'error');
        return;
    }

    # XXX: reserved for the elemental planes
    if ($index < 0) {
        return;
    }

    return @{ $self->levels->[$index] ||= [] };
}

sub create_level {
    my $self = shift;
    my $dlvl = shift;
    my $index = $dlvl - 1;

    TAEB->log->dungeon("Creating a new level object in check_dlvl for $self, dlvl=$dlvl, index $index");

    my $level = TAEB::World::Level->new(
        z       => $dlvl,
        dungeon => $self,
        @_,
    );

    push @{ $self->levels->[$index] ||= [] }, $level;

    return $level;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 current_tile -> Tile

The tile TAEB is currently standing on.

=head2 nearest_level_to Code, Level -> Maybe Level

Finds the nearest level to the given level for which the code reference returns
true.

=head2 nearest_level Code -> Maybe Level

Finds the nearest level to TAEB for which the code reference returns true.

=head2 shallowest_level Code -> Maybe Level

Finds the nearest level to the top of the dungeon for which the code reference
returns true.

=head2 create_level dlvl, ARGS

Creates a new level and sticks it into the dungeon level tree. The given ARGS
will be passed to C<< ->new >>.

=cut

