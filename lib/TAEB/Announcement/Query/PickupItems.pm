package TAEB::Announcement::Query::PickupItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with 'TAEB::Announcement::Role::SelectSubset';

__PACKAGE__->meta->make_immutable;

1;

