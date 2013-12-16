package TAEB::AI::Demo;
use Moose;
use TAEB::OO; # like "use Moose" but with a bit more added to it
extends 'TAEB::AI';

# The framework calls this method on the AI object to determine what action to
# do next. An action is an instance of TAEB::Action, which is basically a handy
# object wrapper around a NetHack command like "s" for search. That way we
# can model the extra information actions require, like items, more deeply.
sub next_action {
    my $self = shift;

    # Try each of these behaviors (which are methods) in order...
    for my $behavior (qw/pray melee hunt descend to_stairs open_door to_door explore search/) {
        my $method = "try_$behavior";
        my $action = $self->$method
            or next;

        # "currently" is for reporting what we're doing on the second-to-last
        # line of the TAEB display. Optional but you should set it anyway.
        $self->currently($behavior);

        return $action;
    }

    # We must be trapped! Search for a secret door. This is a nice fallback
    # since you can search indefinitely.
    $self->currently('to_search');
    return $self->to_search;
}

sub try_pray {
    # This returns false if we prayed recently, or our god is angry, etc.
    return unless TAEB::Action::Pray->is_advisable;

    # Only pray if we're low on nutrition or health.
    return unless TAEB->nutrition < 0
               || TAEB->in_pray_heal_range;

    return TAEB::Action::Pray->new;
}

# Find an adjacent enemy and swing at it.
sub try_melee {
    if_adjacent(
        sub {
            my $tile = shift;
            $tile->has_enemy && $tile->monster->is_meleeable
        } => 'melee',
    );
}

# Find an enemy on the level and hunt it down.
sub try_hunt {
    path_to(sub {
        my $tile = shift;

        return $tile->has_enemy
            && $tile->monster->is_meleeable
            && !$tile->monster->is_seen_through_warning
    }, include_endpoints => 1);
}

# If we're on stairs then descend.
sub try_descend {
    return unless TAEB->current_tile->type eq 'stairsdown';

    return TAEB::Action::Move->new(direction => '>');
}

# If we see stairs, then go to them.
sub try_to_stairs {
    path_to('stairsdown');
}

# If there's an adjacent closed door, try opening it. If it's locked, kick it
# down.
sub try_open_door {
    if_adjacent(closeddoor => sub {
        return 'kick' if shift->is_locked;
        return 'open';
    });
}

# If we see a closed door, then go to it.
sub try_to_door {
    path_to('closeddoor', include_endpoints => 1);
}

# If there's an unexplored tile (tracked by the framework), go to it.
sub try_explore {
    path_to(sub { shift->unexplored });
}

# If there's an unsearched tile next to us, search.
sub try_search {
    if_adjacent(
        sub { $_[0]->is_searchable && $_[0]->searched < 30 },
        'search',
    );
}

# If there's an unsearched tile, go to it.
sub to_search {
    path_to(
        sub { $_[0]->is_searchable && $_[0]->searched < 30 },
        include_endpoints => 1,
    );
}

# These helper functions make our behavior code far more concise and
# declarative.

# find_adjacent finds and adjacent tile that satisfies some predicate. It takes
# a coderef and returns the (tile, direction) corresponding to the adjacent
# tile that returned true for the predicate.
sub find_adjacent {
    my $code = shift;

    my ($tile, $direction);
    TAEB->each_adjacent(sub {
        my ($t, $d) = @_;
        ($tile, $direction) = ($t, $d) if $code->($t, $d);
    });

    return wantarray ? ($tile, $direction) : $tile;
}

# if_adjacent takes a predicate and an action name. If the predicate returns
# true for any of the adjacent tiles, then the action will be instantiated and
# returned.
sub if_adjacent {
    my $code   = shift;
    my $action = shift;

    # Allow caller to pass in a tile type name to check for an adjacent tile
    # with that type.
    if (!ref($code)) {
        my $type = $code;
        $code = sub { shift->type eq $type };
    }

    my ($tile, $direction) = find_adjacent($code);
    return if !$tile;

    # If they pass in a coderef for action, then they need to do some additional
    # processing based on tile type. Let them decide an action name.
    $action = $action->($tile, $direction) if ref($action);

    my $action_class = "TAEB::Action::\u$action";

    # We only want to pass in a direction if the action cares about direction.
    # Actions that care about direction do the TAEB::Action::Role::Direction
    # "role". Kind of like a Java interface, but more awesome.
    my %args;
    $args{direction} = $direction
        if $action_class->does('TAEB::Action::Role::Direction');

    return $action_class->new(%args);
}

# path_to takes a predicate (and optional arguments to pass to the pathfinder)
# and finds the closest tile that satisfies that predicate. If there is such a
# tile, then a Path will be returned.
# If you need to find a path adjacent to an unwalkable tile, then pass in
# include_endpoints => 1.
sub path_to {
    my $code = shift;

    # Allow caller to pass in a tile type name to find a tile with that type.
    if (!ref($code)) {
        my $type = $code;
        $code = sub { shift->type eq $type };
    }

    # TAEB will inflate a path into a Move action for us
    return TAEB::World::Path->first_match($code, @_);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::AI::Demo - a demonstration autonomous AI

=head1 DESCRIPTION

This exists so we include have something that *plays* NetHack in the core TAEB
distro: a default AI. We could use L<TAEB::AI::Behavioral> but that is a
separate distribution, one that depends on L<TAEB> at that.

This is also an example AI for people interested in writing one.

=head1 EXERCISES

If you're interested in bot development, here are some recommended enhancements
to make to this demonstration AI. You can use these exercises to get accustomed
to the TAEB codebase.

If you get stuck, one place to look is L<TAEB::AI::Behavioral>, where we've
implemented all of these behaviors.

=over 4

=item

Have the bot write Elbereth if its HP is less than 50%.

=item

When there's an adjacent Elbereth-ignoring monster, don't write Elbereth (so
that you fall through to melee).

=item

Design a sane policy for writing Elbereth and meleeing monsters when there are
both Elbereth-respecters and Elbereth-ignorers.

Implement this policy.

=item

Pick up food (but not corpses). Is
L<TAEB::Role::Item::Food::Corpse/is_safely_edible> sufficient to
determine which food to pick up?

=item

Eat food from inventory before resorting to prayer.

Be sure to support eating inventory food while standing on a tile with food
(recall that NetHack asks you if you want to eat that floor food).

=item

Dip for Excalibur when appropriate.

=item

If you have projectiles, throw them at enemies.

=item

Retrieve projectiles you've thrown.

=item

Pick up and wear armor.

=back

=cut

