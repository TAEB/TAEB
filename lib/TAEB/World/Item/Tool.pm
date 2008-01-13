#!/usr/bin/env perl
package TAEB::World::Item::Tool;
use Moose;
extends 'TAEB::World::Item';
with 'TAEB::World::Item::Role::Chargeable';

has class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tool',
);

1;

