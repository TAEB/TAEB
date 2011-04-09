package TAEB::Announcement::Dungeon::Feature::Tunneled;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon';

with 'TAEB::Announcement::Dungeon::Feature' => {
    tile_type   => 'floor',
    target_type => 'direction',
};

use constant name => 'tunneled';
use constant type => 'floor';
use constant tile_type => 'floor';
use constant tile_subtype => undef;

__PACKAGE__->parse_messages(
    "You succeed in cutting away some rock." => {
    },
    qr/You swing your .* through thin air./ => {
    },
);

__PACKAGE__->meta->make_immutable;

1;
