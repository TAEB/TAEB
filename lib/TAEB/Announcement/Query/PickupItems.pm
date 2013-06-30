package TAEB::Announcement::Query::PickupItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with (
    'TAEB::Announcement::Role::SelectSubset',
    'TAEB::Announcement::Role::ItemMenu',
);

sub items_from { TAEB->current_tile->items }
sub missing_ok { 1 }

__PACKAGE__->meta->make_immutable;

1;

