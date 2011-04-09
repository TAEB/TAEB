package TAEB::Announcement::Monster::Grabbed;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Monster';

use constant name => 'grabbed';

has grabbed => (
    is => 'ro',
    isa => 'Bool',
);

__PACKAGE__->parse_messages(
    "You are being crushed." => {
        grabbed => 1,
    },
    qr/.* (?:grabs|swings itself around) you!/ => sub {
        grabbed => 1,
    },
    qr/You cannot escape from .*!/ => sub {
        grabbed => 1,
    },

    "You get released!" => {
        grabbed => 0,
    },
    qr/.* (?:releases you!|grip relaxes\.)/ => sub {
        grabbed => 0,
    },
);

__PACKAGE__->meta->make_immutable;

1;
