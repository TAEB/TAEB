package TAEB::Announcement::Dungeon::Trap::Trapdoor;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon::Trap';

use constant name => 'trapdoor';
use constant tile_subtype => 'trap door';

has '+type' => (
    default => 'trap door',
);

__PACKAGE__->parse_messages(
    "A trap door opens up under you!" => {},
    "There's a gaping hole under you!" => {},
    'You fall through...' => {},
);

__PACKAGE__->meta->make_immutable;

1;

