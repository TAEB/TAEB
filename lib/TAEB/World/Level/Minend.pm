package TAEB::World::Level::Minend;
#sic
use Moose;
use TAEB::OO;
extends 'TAEB::World::Level';

__PACKAGE__->meta->add_method("is_$_" => sub { 0 })
    for (grep { $_ ne 'minend' } @TAEB::World::Level::special_levels);

sub is_minend { 1 }

__PACKAGE__->meta->make_immutable;

1;


