package TAEB::Announcement::Dungeon::Tile::BoulderChange;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon::Tile';

use constant name => 'boulder_change';

has '+tile' => (
    default => sub { die "You must provide a tile for BoulderChange" },
    lazy => 1,
);

__PACKAGE__->meta->make_immutable;

1;
