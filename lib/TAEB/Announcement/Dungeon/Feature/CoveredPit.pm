package TAEB::Announcement::Dungeon::Feature::CoveredPit;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon';

with 'TAEB::Announcement::Dungeon::Feature' => {
    tile_type   => 'trap',
    target_type => 'next',
};

use constant name => 'covered_pit';
use constant type => 'floor';
use constant tile_type => 'floor';
use constant tile_subtype => undef;

__PACKAGE__->parse_messages(
    "You hear the boulder fall." => {
    },
    qr/^The boulder (?:triggers and )?(?:plugs a (?:trap door|hole)|fills a pit)./ => {
    },
    # Ah, the joys of NetHack; two possible messages, in very different parts of
    # the code, for essentially the same thing. Incidentally, the NetHack code
    # allows for more than one boulder falling into the pit at once; weird,
    # because there's no way that can happen. The regex ends short due to the
    # range of possible surfaces (ground, ice, etc.).
    qr/^The boulder (?:triggers|falls into) and plugs a (?:trap door|hole)/ => {
    },
);

__PACKAGE__->meta->make_immutable;

1;
