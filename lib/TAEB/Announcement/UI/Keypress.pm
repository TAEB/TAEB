package TAEB::Announcement::UI::Keypress;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::UI';

use constant name => 'keypress';

has key => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

__PACKAGE__->meta->make_immutable;

1;

