package TAEB::Action::Melee;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

# This is not a role summation because Monster requires victim_tile, which is
# provided *in an attribute* by Direction. requirements and attributes do not
# play well at all.
with 'TAEB::Action::Role::Direction';
with 'TAEB::Action::Role::Monster';

has '+direction' => (
    required => 1,
);

# sadly, Melee doesn't give an "In what direction?" message
sub command { 'F' . shift->direction }

__PACKAGE__->meta->make_immutable;

1;


