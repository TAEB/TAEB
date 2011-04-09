package TAEB::Action::Wait;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

has iterations => (
    is       => 'ro',
    isa      => 'Int',
    default  => 1,
    provided => 1,
);

sub command { shift->iterations . '.' }

__PACKAGE__->meta->make_immutable;

1;

