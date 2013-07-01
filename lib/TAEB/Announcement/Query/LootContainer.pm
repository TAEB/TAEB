package TAEB::Announcement::Query::LootContainer;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with 'TAEB::Announcement::Role::SelectSubset';

__PACKAGE__->meta->make_immutable;

1;

