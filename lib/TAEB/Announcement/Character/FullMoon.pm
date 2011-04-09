package TAEB::Announcement::Character::FullMoon;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Character';

use constant name => 'full_moon';

__PACKAGE__->parse_messages(
    'Full moon tonight.' => {},
);

__PACKAGE__->meta->make_immutable;

1;
