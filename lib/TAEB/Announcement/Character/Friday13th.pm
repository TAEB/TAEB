package TAEB::Announcement::Character::Friday13th;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Character';

use constant name => 'friday_13th';

__PACKAGE__->parse_messages(
    'Bad things can happen on Friday the 13th.' => {},
);

__PACKAGE__->meta->make_immutable;

1;
