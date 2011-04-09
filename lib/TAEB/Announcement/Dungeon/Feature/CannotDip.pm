package TAEB::Announcement::Dungeon::Feature::CannotDip;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon';

with 'TAEB::Announcement::Dungeon::Feature' => {
    tile_type   => 'floor',
    target_type => 'local',
};

use constant name => 'cannot_dip';
use constant type => 'floor';
use constant tile_type => 'floor';
use constant tile_subtype => undef;

__PACKAGE__->parse_messages(
    qr/You don't have anything to dip (?:\b.*\b )?into./ => {
    },
);

__PACKAGE__->meta->make_immutable;

1;
