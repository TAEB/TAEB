package TAEB::Announcement::Query::CastSpell;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with (
    'TAEB::Announcement::Role::HasMenu',
    'TAEB::Announcement::Role::SelectSingle',
);

__PACKAGE__->meta->make_immutable;

1;

