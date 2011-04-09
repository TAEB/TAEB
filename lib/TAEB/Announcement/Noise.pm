package TAEB::Announcement::Noise;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement';

use constant name => 'noise';

__PACKAGE__->parse_messages(
    'You strain a muscle.' => {},
    'You kick at empty space.' => {},
    'That hurts!' => {},
);

__PACKAGE__->meta->make_immutable;

1;
