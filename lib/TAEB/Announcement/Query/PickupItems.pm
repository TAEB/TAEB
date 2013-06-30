package TAEB::Announcement::Query::PickupItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with (
    'TAEB::Announcement::Role::SelectSubset',
    'TAEB::Announcement::Role::ItemMenu',
);

sub items_from { TAEB->current_tile->items }

__PACKAGE__->meta->make_immutable;

1;

