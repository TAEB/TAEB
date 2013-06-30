package TAEB::Announcement::Role::SelectSingle;
use Moose::Role;
with (
    'TAEB::Announcement::Role::HasItems',
    'TAEB::Announcement::Role::HasMenu',
);

has selection => (
    is        => 'rw',
    isa       => 'Any',
    predicate => 'has_selection',
);

no Moose::Role;

1;


