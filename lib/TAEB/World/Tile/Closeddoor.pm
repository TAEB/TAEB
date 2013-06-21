package TAEB::World::Tile::Closeddoor;
use Moose;
use TAEB::OO;
use TAEB::Util::Colors;
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
        return COLOR_ORANGE;
    }
    elsif ($self->is_locked) {
        return COLOR_YELLOW;
    }
    elsif ($self->is_unlocked) {
        return COLOR_BRIGHT_GREEN;
    }

    return super;
};

__PACKAGE__->meta->make_immutable;

1;

