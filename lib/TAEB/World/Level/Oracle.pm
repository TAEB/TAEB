package TAEB::World::Level::Oracle;
use Moose;
use TAEB::OO;
extends 'TAEB::World::Level';

__PACKAGE__->meta->add_method("is_$_" => sub { 0 })
    for (grep { $_ ne 'oracle' } @TAEB::World::Level::special_levels);

sub is_oracle { 1 }

__PACKAGE__->meta->make_immutable;

1;


