package TAEB::Announcement::Query::IdentifyItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with (
    'TAEB::Announcement::Role::SelectSubset',
    'TAEB::Announcement::Role::ItemMenu',
);

sub items_from { TAEB->inventory_items }

__PACKAGE__->meta->make_immutable;

1;

