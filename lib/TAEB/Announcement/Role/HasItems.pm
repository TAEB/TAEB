package TAEB::Announcement::Role::HasItems;
use Moose::Role;

has items => (
    traits     => ['Array'],
    isa        => 'ArrayRef',
    required   => 1,
    handles    => {
        items      => 'elements',
        item_count => 'count',
        item       => 'get',
    },
);

no Moose::Role;

1;

