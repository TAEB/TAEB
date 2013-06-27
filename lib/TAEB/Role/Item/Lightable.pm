package TAEB::Role::Item::Lightable;
use Moose::Role;
use TAEB::OO;

has has_oil => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

no Moose::Role;
no TAEB::OO;

1;
