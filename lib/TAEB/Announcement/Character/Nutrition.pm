package TAEB::Announcement::Character::Nutrition;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Character';

use constant name => 'nutrition';

has nutrition => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

__PACKAGE__->parse_messages(
    "Your stomach feels content." => {
        'nutrition' => 900
    },
);

__PACKAGE__->meta->make_immutable;

1;
