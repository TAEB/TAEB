package TAEB::Announcement::Character::ProtectionDecreased;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Character';

use constant name => 'protection_dec';

__PACKAGE__->parse_messages(
    'The golden haze around you becomes less dense.' => {},
);

__PACKAGE__->meta->make_immutable;

1;
