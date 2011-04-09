package TAEB::Announcement::Character::NewMoon;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Character';

use constant name => 'new_moon';

__PACKAGE__->parse_messages(
    'New moon tonight.' => {},
);

__PACKAGE__->meta->make_immutable;

1;
