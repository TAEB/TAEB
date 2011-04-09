package TAEB::Announcement::Character::ProtectionGone;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Character';

use constant name => 'protection_gone';

__PACKAGE__->parse_messages(
    'The golden haze around you disappears.' => {},
);

__PACKAGE__->meta->make_immutable;

1;
