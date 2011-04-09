package TAEB::World::Tile::Sink;
use Moose;
use TAEB::OO;
extends 'TAEB::World::Tile';

has got_ring => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has got_foocubus => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has got_pudding => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has kicked => (
    is            => 'rw',
    isa           => 'Int',
    default       => 0,
    documentation => "How many times has this sink been kicked?",
);

has '+type' => (
    default => 'sink',
);

has '+glyph' => (
    default => '{',
);

__PACKAGE__->meta->make_immutable;

1;

