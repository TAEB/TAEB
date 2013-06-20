package TAEB::Spoilers::Map;

use strict;
use warnings;

my %terrain2taeb = (
    # TAEB doesn't care about the stair/ladder distinction; an exit is an exit
    (map { $_ => $_ } qw/floor stairsup stairsdown fountain bars ice lava
        sink pool tree corridor throne/),

    # close enough
    air => 'floor',
    cloud => 'corridor',
    water => 'pool',

    # XXX TAEB has no concept of secret foos yet, so if we know about a
    # secret, we mark it as being searchable.  Good enough for now.
    rock => sub {
        my ($tile, $minor) = @_;
        $tile->change_type(rock => $tile->floor_glyph);
        $tile->inc_searched($minor ? 0 : 50);
    },
    wall => sub {
        my ($tile, $minor) = @_;
        $tile->change_type(wall => $tile->floor_glyph);
        $tile->inc_searched($minor ? 0 : 50);
    },
    door => sub {
        my ($tile, $minor) = @_;
        return if $minor eq 'random'; #not enough to go on

        if ($minor eq 'nodoor' || $minor eq 'broken') {
            # These aren't real doors in TAEB
            $tile->change_type(floor => $tile->floor_glyph);
            return;
        }

        $tile->change_type(($minor eq 'open' ? 'opendoor' : 'closeddoor'), ' ');

        $tile->door_state(($minor eq 'closed') ? 'unlocked' : 'locked');
    },
);

my %rtypes = (
    lit      => sub { shift->is_lit(1);      },
    unlit    => sub { shift->is_lit(0);      },
    nondig   => sub { shift->nondiggable(1); },
    shop     => sub { shift->in_shop(1);     },
    temple   => sub { shift->in_temple(1);   },
);

sub apply_to_level {
    my ($fmap, $level) = @_;

    $level->branch($fmap->branch);

    $level->special_level($fmap->basename);

    # The normal TAEB special room recognizer is not designed to handle
    # irregular and partially overlapping rooms, and it probably made
    # a mess before we get here.  Fix that now.
    $level->each_tile(sub {
        my $tile = shift;
        $tile->in_shop(0);
        $tile->in_temple(0);
    });

    for my $feat (@{ $fmap->features }) {
        my ($major, $x, $y, $minor) = @$feat;
        my $tile = $level->at($x,$y);
        next if $tile->type ne 'unexplored';

        if (ref $terrain2taeb{$major}) {
            $terrain2taeb{$major}->($tile, $minor);
        } else {
            $tile->change_type($terrain2taeb{$major} => $tile->floor_glyph);
        }
    }

    for my $rtype (keys %rtypes) {
        for my $pt (@{ $fmap->region($rtype) }) {
            $rtypes{$rtype}->($level->at(@$pt));
        }
    }

    for my $engr (@{ $fmap->engravings }) {
        my ($x, $y, $type, $text) = @$engr;

        $level->at($x,$y)->engraving($text);
        $level->at($x,$y)->engraving_type($type);
    }

    for my $item (@{ $fmap->items }) {
        my ($name, $x, $y) = @$item;

        # XXX This isn't quite right; if we've partially explored levels it
        # can cause doubled items and other not nice stuff.  Really, we want
        # to only add the item if we haven't observed the tile in question,
        # but TAEB doesn't really have a concept of that yet.

        $level->at($x,$y)->add_item(TAEB->new_item($name));
    }
}

1;
