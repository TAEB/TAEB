package TAEB::Action::Open;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Direction';

use constant command => 'o';

has '+direction' => (
    required => 1,
);

subscribe door => sub {
    my $self  = shift;
    my $event = shift;

    my $state = $event->state;
    my $door  = $event->tile;

    # The tile may have been changed between the announcement's origin and now
    return unless $door && $door->isa('TAEB::World::Tile::Door');

    if ($state eq 'locked') {
        $door->door_state('locked');
    }
    elsif ($state eq 'resists') {
        $door->door_state('unlocked');
    }
};

sub is_impossible {
    return TAEB->is_polymorphed
        || TAEB->in_pit;
}

__PACKAGE__->meta->make_immutable;

1;

