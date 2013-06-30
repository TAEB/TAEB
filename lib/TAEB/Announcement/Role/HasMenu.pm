package TAEB::Announcement::Role::HasMenu;
use Moose::Role;
with 'TAEB::Announcement::Role::HasItems';

has menu => (
    is       => 'ro',
    isa      => 'NetHack::Menu',
    required => 1,
);

# XXX populate items with menu information

no Moose::Role;

1;

