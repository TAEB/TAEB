package TAEB::Announcement::NothingHappens;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement';

use constant name => 'nothing_happens';

__PACKAGE__->parse_messages(
    "Nothing happens." => {},
);

__PACKAGE__->meta->make_immutable;

1;

