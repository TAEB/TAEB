package TAEB::Role::Item::Tool::Container;
use Moose::Role;
use TAEB::OO;
with 'TAEB::Role::Item';

has locked => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

no Moose::Role;
no TAEB::OO;

1;
