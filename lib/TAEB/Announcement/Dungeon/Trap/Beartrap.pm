package TAEB::Announcement::Dungeon::Trap::Beartrap;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon::Trap';

use constant name => 'beartrap';
use constant tile_subtype => 'bear trap';

has '+type' => (
    default => 'bear trap',
);

has now_stuck => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

__PACKAGE__->parse_messages(
    "You are caught in a bear trap." => {
    },
    "You can't move your leg!" => {
    },
    qr/^(?:A|Your) bear trap closes on your/ => {
    },
    qr/\w+ bear trap closes harmlessly (?:through|over) you\./ => {
        now_stuck => 0,
    },
);

__PACKAGE__->meta->make_immutable;

1;

