#!/usr/bin/env perl
package TAEB::AI::Brain::NhBot;
use Moose;
extends 'TAEB::AI::Brain';

=head1 NAME

TAEB::AI::Brain::NhBot - Know thy roots

=head1 VERSION

Version 0.01 released ???

=cut

our $VERSION = '0.01';

=head2 next_action TAEB -> STRING

Pray when Weak. #enhance when able.

If something is attacking TAEB, ; around the eight adjacent points to find it.
Then repeatedly attack it.

Otherwise, random walk.

=head3 State

What is the last direction we used ; in? Used as an index into the directions
array.

What monster last attacked us? That's the one we're looking for.

=cut

has last_direction => (
    is => 'rw',
    isa => 'Int',
);

has looking_for => (
    is => 'rw',
    isa => 'Str',
);

my @directions = (qw(h j k l y u b n), ' ');

sub next_action {
    my $self = shift;

    # need food. must pray
    if ($main::taeb->messages =~ /You regain consciousness/) {
        $main::taeb->info("Fainting!");
        return "#pray\n";
    }
    elsif ($main::taeb->messages =~ /You (?:are beginning to )?feal weak\.|Valkyrie needs food!/) {
        $main::taeb->info("Feeling weak.");
        return "#pray\n";
    }
    # working out is useful for those floating eyes
    elsif ($main::taeb->messages =~ /You feel more confident/) {
        $main::taeb->info("Got a 'feel more confident' message.");
        return "#enhance\na a \n";
    }
    # we just swiped at something, swing again in the same direction
    elsif ($main::taeb->messages =~ /you (?:just )?(?:hit|miss) (?:(?:the |an? )([-.a-z ]+?)|it)[.!]/i) {
        $main::taeb->info("I either bumped into a monster or just attacked one.");
        return 'F' . $directions[$self->last_direction];
    }
    # under attack! start responding
    elsif ($main::taeb->messages =~ /(?:(?:the |an? )([-.a-z ]+?)|it) (?:just )?(strikes|hits|misses|bites|grabs|stings|touches|points at you, then curses)(?:(?: at)? you(?:r displaced image)?)?[.!]/i) {
        $main::taeb->info("I'm being attacked by a $1! Looking for him..");
        $self->last_direction(-1);
        $self->looking_for($1);
        return $self->spin;
    }
    # looks like the output of ;
    elsif ($main::taeb->messages =~ /^(?:.\s*(.*)\s*\(.*\)\s*|\| a wall)$/) {
        $main::taeb->info("I spy with my little eye '$1', at ". $directions[$self->last_direction] .".");
        my $looking_for = $self->looking_for;
        if ($main::taeb->messages =~ /\Q$looking_for/) {
            # attack!
            $main::taeb->info("Found what I'm looking for at ".$directions[$self->last_direction]."!");
            return 'F' . $directions[$self->last_direction];
        }

        # ran out of directions and couldn't find it. gulp. just start moving
        # again
        if ($directions[$self->last_direction+1] eq ' ') {
            $main::taeb->info("I have no more directions to look at.");
            return $self->random;
        }

        # keep looking..
        $main::taeb->info("Still looking.");
        return $self->spin;
    }
    else {
        $main::taeb->debug("Nothing interesting about " . $main::taeb->messages)
            unless $main::taeb->messages =~ /^\s*$/;
        return $self->random;
    }
}

=head2 spin

This will look in the direction after last_direction. Make sure that
last_direction is set properly before calling this.

=cut

sub spin {
    my $self = shift;
    $self->last_direction($self->last_direction + 1);
    return ';' . $directions[$self->last_direction] . '.';
}

=head2 random

Walks in a random direction. Clears the last direction walked so that it
doesn't interfere with the combat system.

=cut

sub random {
    my $self = shift;

    $self->last_direction(-1);

    return $directions[rand @directions];
}

1;

