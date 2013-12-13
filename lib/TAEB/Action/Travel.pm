package TAEB::Action::Travel;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

use constant command => '_';

has path => (
    is       => 'ro',
    isa      => 'TAEB::World::Path',
    provided => 1,
    required => 1,
);

has intralevel_subpath => (
    is      => 'ro',
    isa     => 'TAEB::World::Path',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $intralevel_subpath = $self->path->intralevel_subpath;
        confess "Travel requires a path with components on the current level"
            if !$intralevel_subpath;
        return $intralevel_subpath;
    },
);

sub location_controlled_tele {
    my $self = shift;
    my $target = $self->location_travel;
    return $target if $target->is_walkable && !$target->has_monster;
    my @adjacent = $target->grep_adjacent(sub {
        my $t = shift;
        return $t->is_walkable && !$t->has_monster;
    });
    return unless @adjacent;
    return $adjacent[0];
}

sub location_travel {
    my $self = shift;

    my $path = $self->intralevel_subpath || $self->path;

    return $path->to;
}

sub done {
    my $self = shift;
    # NetHack doesn't show or tell us what's on the floor when we
    # travel. So we have to check manually.
    TAEB->send_message(check => 'floor')
        unless TAEB->is_blind;
}

__PACKAGE__->meta->make_immutable;

1;

