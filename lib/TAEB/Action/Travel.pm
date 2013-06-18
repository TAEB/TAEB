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
    is  => 'ro',
    isa => 'TAEB::World::Path',
);

# if the first movement is < or >, then just use the Ascend or Descend actions
# if the path spans multiple levels, just go until the level change action
around new => sub {
    my $orig  = shift;
    my $class = shift;
    my %args  = @_;

    # we only want to change Travel
    return $class->$orig(@_) if $class ne 'TAEB::Action::Travel';

    my $start;

    if ($args{path}) {
        $start = substr($args{path}->path, 0, 1);
    }
    else {
        confess "You must specify a path to the Travel action.";
    }

    if ($start eq '<') {
        return TAEB::Action::Ascend->new(%args);
    }
    elsif ($start eq '>') {
        return TAEB::Action::Descend->new(%args);
    }

    my $intralevel_subpath = $args{path}->intralevel_subpath;
    if ($intralevel_subpath) {
        return $class->$orig(
            %args,
            path               => $intralevel_subpath,
            intralevel_subpath => $intralevel_subpath,
        );
    }

    $class->$orig(%args);
};

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

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

