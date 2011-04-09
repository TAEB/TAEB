package TAEB::World::Tile::Closeddoor;
use Moose;
use TAEB::OO;
use TAEB::Util qw/:colors display/;
extends 'TAEB::World::Tile::Door';

has '+type' => (
    default => 'closeddoor',
);

has is_shop => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

override debug_color => sub {
    my $self = shift;

    if ($self->is_shop) {
        return display(COLOR_ORANGE);
    }
    elsif ($self->is_locked) {
        return display(COLOR_YELLOW);
    }
    elsif ($self->is_unlocked) {
        return display(color => COLOR_GREEN, bold => 1);
    }

    return super;
};

__PACKAGE__->meta->make_immutable;

1;

