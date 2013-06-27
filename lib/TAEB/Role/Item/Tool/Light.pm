package TAEB::Role::Item::Tool::Light;
use Moose::Role;
use TAEB::OO;
with 'TAEB::Role::Item';

has has_oil => (
    is      => 'rw',
    isa     => 'Bool',
    lazy    => 1,
    default => sub { 1 },
);

no Moose::Role;
no TAEB::OO;

1;
