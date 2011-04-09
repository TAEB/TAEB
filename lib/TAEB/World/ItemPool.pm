package TAEB::World::ItemPool;
use Moose;
use TAEB::OO;
extends 'NetHack::ItemPool';

use constant inventory_class => 'TAEB::World::Inventory';

has '+inventory' => (
    isa => 'TAEB::World::Inventory',
);

__PACKAGE__->meta->make_immutable;

1;

