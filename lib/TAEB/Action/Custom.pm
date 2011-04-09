package TAEB::Action::Custom;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

has string => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    provided => 1,
);

sub command { shift->string }

__PACKAGE__->meta->make_immutable;

1;

