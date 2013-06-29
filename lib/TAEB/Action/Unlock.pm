package TAEB::Action::Unlock;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with (
    'TAEB::Action::Role::Direction',
    'TAEB::Action::Role::Item' => { items => [qw/implement/] },
);

use constant command => 'a';

has '+implement' => (
    required => 1,
);

has '+direction' => (
    required => 1,
);

sub respond_apply_what { shift->implement->slot }

sub respond_lock {
    shift->target_tile('closeddoor')->state('unlocked');
    'n';
}

sub respond_unlock { 'y' }

subscribe door => sub {
    my $self  = shift;
    my $event = shift;

    my $door = $event->tile;

    # if the door explodes as we're unlocking it, it's not a door any more
    return unless $door && $door->isa('TAEB::World::Tile::Door');

    my $state = $event->state;

    if ($state eq 'just_unlocked') {
        $door->door_state('unlocked');
    }
    elsif ($state eq 'interrupted_locking') {
        $door->door_state('locked');
    }
};

__PACKAGE__->meta->make_immutable;

1;

