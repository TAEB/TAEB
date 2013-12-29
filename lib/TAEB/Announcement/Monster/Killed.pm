package TAEB::Announcement::Monster::Killed;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Monster';

use constant name => 'killed';

has monster_name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

__PACKAGE__->parse_messages(
    qr/^You (?:kill|destroy) (?:the|an?)(?: poor)?(?: invisible)? (.*)(?:\.|!)/ => sub {
        monster_name => $1
    },
);

__PACKAGE__->meta->make_immutable;

1;
