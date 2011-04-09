package TAEB::Spoilers::Sokoban;
use Moose;
use Tie::RefHash;

has level_maps => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        my %sokolevels = (
            "soko4-1" => {
                map_text => q(
------  -----
|....|  |...|
|.Ah.----.C.|
|.Bb.....Da.|
|..|-|>|-|E.|
---------|.---
|.g678<|.....|
|..----|F.c..|
--5|   |.G...|
 |4|---|dH...|
 |f.3210IeJ..|
 |..|---------
 ----
                ),
                solution_text => [
                    [qw(Da ab Ec Hd I0)],
                    [qw(J1)],
                    [qw(Ge e2)],
                    [qw(dI I3)],
                    [qw(cJ Jf f4)],
                    [qw(FI If f5)],
                    [qw(CJ Jf fg g6)],
                    [qw(Ah BA ba aJ Jf fg g7)],
                    [qw(hb ba aJ Jf fg g8)],
                ],
            },
            "soko4-2" => {
                map_text => q(
-------- ------
|<|>...|-|....|
|9|-.ABm.nbG..|
|8||.aCD|kFgH.|
|7||....|ihlj.|
|6|-----|E-----
|5|    |......|
|4-----|dce...|
|f.3210IJKL...|
|..|---|......|
----   --------
                ),
                solution_text => [
                    [qw(Aa Bb Ec Jd I0)],
                    [qw(Le K1)],
                    [qw(dJ J2)],
                    [qw(eL L3)],
                    [qw(cK Kf f4)],
                    [qw(Gg bG Fh hi iK Kf f5)],
                    [qw(Hj ji iK Kf f6)],
                    [qw(gk kK Kf f7)],
                    [qw(Gl li iK Kf f8)],
                    [qw(Dm mb bh hi iK Kf f9)],
                ],
            },
            "soko3-1" => {
                map_text => q(
-----------       -----------
|....|....|--     |.........|
|.bAB|CE...>|     |.........|
|.jk..D.l.|--     |.........|
|....|....|       |....<....|
|-.---------      |.........|
|.iF.|.....|      |.........|
|.GH.|M.OeS|      |.........|
|.gIh...cQ.|      |.........|
|.JKL|N..Rd|---------------+|
|....|..PfT.0123456789!":$%.|
-----------------------------
                ),
                solution_text => [
                    [qw(Dk kl Gb Ic Rd T0)],
                    [qw(P1)],
                    [qw(Qe dT T2)],
                    [qw(ST T3)],
                    [qw(ef f4)],
                    [qw(OS ST T5)],
                    [qw(cP P6)],
                    [qw(Jg gc cP P7)],
                    [qw(KI Ic cP P8)],
                    [qw(Lh hc cP P9)],
                    [qw(HG Gg gc cP P!)],
                    [qw(bg gc cP P")],
                    [qw(Fi ij jg gc cP P:)],
                    [qw(Ak kj jg gc cP P$)],
                    [qw(lj jg gc cP P%)],
                ],
            },
            "soko3-2" => {
                map_text => q(
 ----          -----------
-|.>|-------   |.........|
|.m........|   |.........|
|.A-----B-.|   |.........|
|.n|...|hC.|   |....<....|
|.D.Eoi.gF-|   |.........|
|.Gl.H.p|..|   |.........|
|.----Ic--.|   |.........|
|..J..aK.|.--  |.........|
|.---L-j.eM.------------+|
|...|..N-.O.0123456789!".|
|.dP.b.f.k----------------
----|..|..|
    -------
                ),
                solution_text => [
                    [qw(Bg Ch Ja Lb O0)],
                    [qw(Kc aJ bL Pd Nf Me FC gi cj eM MO O1)],
                    [qw(Lb fk ke eM MO O2)],
                    [qw(jf fk ke eM MO O3)],
                    [qw(Ia aK Kf fk ke eM MO O4)],
                    [qw(bL dk ke eM MO O5)],
                    [qw(JK Kf fk ke eM MO O6)],
                    [qw(Lb bk ke eM MO O7)],
                    [qw(Gl hg Ch Am Dn Eo ia aK Kf fk ke gi eM MO O8)],
                    [qw(ia aK Kf fk ke eM MO O9)],
                    [qw(oi ia aK Kf fk ke eM MO O!)],
                    [qw(Hp pf fk ke eM MO O")],
                ],
            },
            "soko2-1" => {
                map_text => q(
--------------------
|........|...|.....|
|.ABfc-EF|.-.|.....|
|..|eC.D.|GH.|.....|
|-.|..-.d|.-.|..<..|
|...--.......|.....|
|...|.M.-...-|.....|
|.Ib|L.|...--|.....|
|-J.|..|----------+|
|.aK.gh.0123456789.|
|...|.>|------------
--------
                ),
                solution_text => [
                    [qw(Ka a0)],
                    [qw(Ib Ja a1)],
                    [qw(bK K2)],
                    [qw(Aa a3)],
                    [qw(BA Aa a4)],
                    [qw(Cc Fd De ef cC fA Aa a5)],
                    [qw(Ce ef fA Aa a6)],
                    [qw(ED De ef fA Aa a7)],
                    [qw(Mh h8)],
                    [qw(Lg g9)],
                ],
            },
            "soko2-2" => {
                map_text => q(
  --------
--|.|....|
|...Ajf..|----------
|.-iBC-DE|.|.......|
|.FG-......|.......|
|.-h.H.|g..|.......|
|....-I--J-|...<...|
|..KL..M...|.......|
|.--...|...|.......|
|..ce-N|---|.......|
--|abO.|----------+|
  |.dP>0123456789!.|
  ------------------
                ),
                solution_text => [
                    [qw(Oa P0)],
                    [qw(N> >1)],
                    [qw(Lb ac bd d2)],
                    [qw(ce ed d3)],
                    [qw(KL Ld d4)],
                    [qw(GK KL Ld d5)],
                    [qw(FG GK KL Ld d6)],
                    [qw(Af Eg Hh hK KL Ld d7)],
                    [qw(CH Hh hK KL Ld d8)],
                    [qw(Bi iK KL Ld d9)],
                    [qw(fj jH Hh hK KL Ld d!)],
                ],
            },
            "soko1-1" => {
                map_text => q(
--------------------------
|>.....q0123456789!":$%&.|
|.......|---------------.|
-------.------         |.|
 |.....po....|         |.|
 |.A.B.ClD.E.|         |.|
--------.-----         |.|
|.i.FsHknI.J.|         |.|
|...Gj..m....|         |.|
-----.--------   ------|.|
 |..LrNuP...|  --|.....|.|
 |...v.O.ba.|  |*+.....|.|
 |.K.M.c.Q.|-  |-|.....|.|
-------.----   |*+.....+.|
|.gRh.ft.|     |-|.....|--
|.e....d.|     |*+.....|
|...|-----     --|.....|
-----            -------
                ),
                solution_text => [
                    [qw(Oa ab Qc cd de Rf eg gh Mc cd de eg Fi Gj jM MQ HF Ik
                        Cl lm mj jM Mc Dl lm mj kn no op pq q0)],
                    [qw(jM Fn no op pq q1)],
                    [qw(in no op pq q2)],
                    [qw(Jn no op pq q3)],
                    [qw(Lr rs sn no op pq q4)],
                    [qw(Nr rs sn no op pq q5)],
                    [qw(ba Pr rs sn no op pq q6)],
                    [qw(cd de ft tu ur rs sn no op pq q7)],
                    [qw(ht tu ur rs sn no op pq q8)],
                    [qw(gt tu ur rs sn no op pq q9)],
                    [qw(eg gt tu ur rs sn no op pq q!)],
                    [qw(aO Ou ur rs sn no op pq q")],
                    [qw(Mc cd de eg gt tu ur rs sn no op pq q:)],
                    [qw(Qc cd de eg gt tu ur rs sn no op pq q$)],
                    [qw(Kc cd de eg gt tu ur rs sn no op pq q%)],
                    [qw(Bl lm mj jv vs sn no op pq q&)],
                ],
            },
            "soko1-2" => {
                map_text => q(
  ------------------------
  |.j0123456789!":$%&'~..|
  |..-------------------.|
----.|    -----        |.|
|..|A--  --...|        |.|
|.i.k.|--|.Nr.|        |.|
|.BCh.|..|.eO.|        |.|
--..DE|f..PQd--        |.|
 |FgmG.n.|R..|   ------|.|
 |.HI.|..|scS| --|.....|.|
 |.JlK|--|bT.| |*+.....|.|
 |...q.p.|..-- |-|.....|.|
 ----.Lo.|.--  |*+.....+.|
    ---.--.|   |-|.....|--
     |.M..a|   |*+.....|
     |>.|..|   --|.....|
     -------     -------
                ),
                solution_text => [
                    [qw(Ma ab Tc Sd Qe Pf Gg Dh Bi iB Aj j0)],
                    [qw(EG hj j1)],
                    [qw(Bi ik kj j2)],
                    [qw(Ch hj j3)],
                    [qw(Il GE lj j4)],
                    [qw(Jl lj j5)],
                    [qw(HI Ij j6)],
                    [qw(Fi ik kj j7)],
                    [qw(gm mj j8)],
                    [qw(EG Gm mj j9)],
                    [qw(KG Gm mj j!)],
                    [qw(fn nm mj j")],
                    [qw(Lo op pq qG Gm mj j:)],
                    [qw(cT RP Pf fn nm mj j$)],
                    [qw(bP Pf fn nm mj j%)],
                    [qw(Tb bP Pf fn nm mj j&)],
                    [qw(Nr ec cs sP Pf fn nm mj j')],
                    [qw(rN Nc cs sP Pf fn nm mj j~)],
                ],
            },
        );

        for my $levelname (keys %sokolevels) {
            my $level = $sokolevels{$levelname};

            # Unpack the map from the human-readable representation above
            # into a true in-memory representation.
            my $map_text = $level->{'map_text'};
            chomp $map_text;

            my @map;
            my %locations;
            my $x = 0;
            my $y = -1; # there's an initial newline
            my $pitcount = 0;

            while (length($map_text)) {
                # Remove first character destructively
                my $char = substr($map_text, 0, 1, "");

                if ($char eq "\n") {
                    $y++;
                    $x = 0;
                    next;
                }

                $map[$y][$x] = $char;
                $locations{$char} = [$x, $y];
                $x++;
                $pitcount++ if $char =~ /[0-9!\"\:\$\%\&\'\~]/;
            }
            # There's a blank line at the bottom of the text maps for
            # formatting reasons.
            splice @map, -1, 1, ();

            $level->{'map'} = \@map;
            $level->{'locations'} = \%locations;
            $level->{'pitcount'} = $pitcount;

            # Likewise for the solution.
            $level->{'solution'} = [map {
                [map {/(.)(.)/ and [$1, $2]} @$_];
            } @{$level->{'solution_text'}}];
        }
        return \%sokolevels;
    },
);

sub _lists_sort_equal {
    my @list1 = sort @{(shift)};
    my @list2 = sort @{(shift)};
    return 0 if scalar @list1 != scalar @list2;
    (shift @list1) eq (shift @list2) or return 0 while scalar @list1;
    return 1;
}

# This is rather slow, but luckily memoizing the results is entirely
# possible, due to Sokoban-ness of a level never changing. Memoization
# here is rolled by hand due to Memoize wanting to store arguments
# as strings.
has _recognition_cache => (
    isa     => 'HashRef[Maybe[ArrayRef]]',
    is      => 'rw',
    default => sub { my %h = (); tie %h, 'Tie::RefHash'; \%h }, 
);
sub recognize_sokoban_variant {
    my $self = shift;
    my $level = shift;
    $level = TAEB->current_level unless defined $level;

    my $cache = $self->_recognition_cache->{$level};
    if ($cache) {
        return $cache->[0] unless wantarray;
        return @$cache;
    }

    my $left = 99;
    my $top = 99;

    # Find out where the Sokoban map is on the screen.
    $level->each_tile(sub {
        my $t = shift;
        if ($t->type eq 'wall') {
            $left = $t->x if $t->x < $left;
            $top  = $t->y if $t->y < $top;
        }
    });

    my $variant = undef;

    # Find out which variant this is, by comparing wall locations.
    FINDVARIANT:
    for my $variant_check (keys %{$self->level_maps}) {
        my $map = $self->level_maps->{$variant_check}->{'map'};
        my $x = $left;
        my $y = $top;

        for my $mapline (@$map) {
            for my $mapchar (@$mapline) {
                my $tile = $level->at($x, $y);

                next FINDVARIANT
                    if ($tile->type eq 'wall' && $mapchar !~ /[-|]/)
                    || ($tile->type ne 'wall' && $mapchar =~ /[-|]/);

                $x++;
            }

            $x = $left;
            $y++;
        }

        $variant = $variant_check;
        last;
    }
    $self->_recognition_cache->{$level} = [$variant, $left, $top];
    return ($variant, $left, $top) if wantarray;
    return $variant;
}

sub remaining_pits {
    my $self = shift;
    my $level = shift || TAEB->current_level;
    my $variant = shift || scalar $self->recognize_sokoban_variant($level);
    return $self->level_maps->{$variant}->{'pitcount'} -
           $level->pit_and_hole_traps_untrapped;
}

sub first_unsolved_sokoban_level {
    my $self = shift;
    return TAEB->dungeon->shallowest_level(sub {
        my $level = shift;
        return $level->known_branch
            && $level->branch eq 'sokoban'
            && $self->remaining_pits($level) > 0;
    });
}
sub last_solved_sokoban_level {
    my $self = shift;
    return TAEB->dungeon->deepest_level(sub {
        my $level = shift;
        return $level->known_branch
            && $level->branch eq 'sokoban'
            && $self->remaining_pits($level) == 0;
    });
}

sub first_solvable_sokoban_level {
    my $self = shift;
    my $pathable = shift;
    return TAEB->dungeon->shallowest_level(sub {
        my $level = shift;
        return $level->known_branch
            && $level->branch eq 'sokoban'
            && defined $self->next_sokoban_step($level,$pathable);
    });
}

sub number_of_solved_sokoban_levels {
    my $self = shift;
    my $count = 0;
    TAEB->dungeon->shallowest_level(sub {
        my $level = shift;
        $level->known_branch
            and $level->branch eq 'sokoban'
            and $self->remaining_pits($level) == 0
            and $count++;
        0;
    });
    return $count;
}

sub probably_has_genuine_boulder {
    my $self = shift;
    my $tile = shift;
    return 0 unless $tile->has_boulder;
    if ($tile->type eq 'obscured') {
        my ($variant, $left, $top) =
            $self->recognize_sokoban_variant($tile->level);
        if ($variant) {
            my $map = $self->level_maps->{$variant}->{'map'};
            my $y = $tile->y - $top;
            my $x = $tile->x - $left;
            if ($tile->level->pit_and_hole_traps_untrapped == 0 &&
                $map->[$y]->[$x] =~ /[0-9!"\$\%\&'~:]/) {
                # inject info into the map
                $tile->change_type(trap => '^');
            }
            # The tile might be obscured due to having had a door there that's
            # now been opened; however, it makes no sense to have a boulder on
            # a door, in Sokoban.
            return 0 if $map->[$y]->[$x] eq '+';
        }
    }
    return 1 if $tile->type eq 'obscured' || $tile->type eq 'rock';
    return 1 if $tile->known_genuine_boulder;
    return 0; # probably a mimic
}

sub is_sokoban_reward_tile {
    my $self = shift;
    my $tile = shift;
    my ($variant, $left, $top) = $self->recognize_sokoban_variant($tile->level);
    return 0 unless $variant;
    my $map = $self->level_maps->{$variant}->{'map'};
    my $y = $tile->y - $top;
    my $x = $tile->x - $left;
    return $map->[$y]->[$x] eq '*';
}

sub next_sokoban_step {
    my $self = shift;
    my $level = shift;
    my $pathable = shift;

    # TAEB is where it is if it's on the level; otherwise, it'll
    # arrive at the nearest exit.
    my $tile_from = TAEB->current_tile;
    if ($tile_from->level != $level) {
        $tile_from = $level->exit_towards(TAEB->current_level);
        return unless $tile_from; # can't path to Sokoban
    }

    my ($variant, $left, $top) = $self->recognize_sokoban_variant($level);

    if (!$variant) {
        TAEB->log->spoiler(
            "Could not determine Sokoban variant",
            level => 'error',
        );
        return;
    }

    my $map = $self->level_maps->{$variant}->{'map'};
    my $locations = $self->level_maps->{$variant}->{'locations'};
    my $solution = $self->level_maps->{$variant}->{'solution'};

    # Find out how many pits have been filled already.
    my $remaining_pits = $self->remaining_pits($level, $variant);

    return if $remaining_pits == 0; # already solved

    my @steps = @$solution;

    # Work out where the boulders will be after the pits that we've
    # seen missing have been eliminated.
    my @sofar = splice @steps, 0, -$remaining_pits;

    my @boulder_locations;
    for (@$map) {
        for (@$_) {
            push @boulder_locations, $_
                if /[A-Z]/;
        }
    }

    for my $steplist (@sofar) {
        for my $step (@$steplist) {
            @boulder_locations = map {
                $_ eq $step->[0] ? $step->[1] : $_
            } @boulder_locations;
        }
    }
    @boulder_locations = map { /[0-9!"\$\%\&'~:]/ ? () : ($_) } @boulder_locations;

    my $origboulder_locations = join '-', @boulder_locations;

    # Find out where the boulders actually are.
    my @current_boulder_locations;
    my $misplaced_x;
    my $misplaced_y;

    $level->each_tile(sub {
        my $t = shift;
        if ($self->probably_has_genuine_boulder($t)) {
            my $y = $t->y - $top;
            my $x = $t->x - $left;
            my $char = $map->[$y]->[$x];

            push @current_boulder_locations, $char;

            $misplaced_x = $x if $char eq '.';
            $misplaced_y = $y if $char eq '.';
        }
    });

    @current_boulder_locations = sort @current_boulder_locations;

    if ((grep { /\./ } @current_boulder_locations) > 1) {
        TAEB->log->spoiler(
            "This Sokoban puzzle has deviated from spoilers.",
            level => 'warning',
        );
        return;
    }

    # Find out how far we are with this strategy already.
    # Sometimes there will be more than one possibility; we find out
    # which by attempting to path from TAEB's current location to the
    # location it should be aiming to next (which will be impossible
    # if this is the wrong possibility).
    my @plan = @{$steps[0]};
    my ($working_x, $working_y);
    for my $movement (@plan) {
        my $nextmovef = $movement->[0];
        my $nextmovet = $movement->[1];

        # Bare block that iterates once for each boulder step movement
        {
            my ($xf, $yf) = (
                $nextmovef eq '.' ? ($working_x, $working_y)
                                  : @{$locations->{$nextmovef}},
            );

            my ($xt, $yt) = @{$locations->{$nextmovet}};

            if (_lists_sort_equal(\@boulder_locations, \@current_boulder_locations) &&
               (!defined($misplaced_x) ||
                ($misplaced_x == $working_x && $misplaced_y == $working_y))) {
                # This is a potential match for the plan.
                my ($x, $y);
                if ($xf == $xt) {
                    # Moving up or down
                    $x = $xf;
                    $y = ($yf > $yt ? $yf+1 : $yf-1);
                }
                elsif ($yf == $yt) {
                    # Moving left or right
                    $y = $yf;
                    $x = ($xf > $xt ? $xf+1 : $xf-1);
                }
                else {
                    TAEB->log->spoiler(
                        "Sokoban spoilers move a boulder diagonally",
                        level => 'error',
                    );
                    return;
                }

                if ($tile_from->x - $left == $x && $tile_from->y - $top  == $y) {
                    # We're in the right location, push the boulder.
                    return $level->at($xf + $left, $yf + $top);
                }

                my $temptile = $level->at($x + $left, $y + $top);
                if ($pathable) {
                    if ($pathable->($temptile)) {
                        return $temptile;
                    }
                }
                else {
                    my $path = TAEB::World::Path->calculate_path(
                        $tile_from => $temptile,
                        through_unknown => 1,
                    );
                    if (length $path->path) {
                        # We can path to the right location, so do so.
                        return $temptile;
                    }
                }
                TAEB->log->spoilers("Sokoban: Skipped a move to $temptile due ".
                                    "to pathing problems (pathable=$pathable).");
            }

            # Move one step through the plan.
            $xf += ($xt <=> $xf) if $xf != $xt;
            $yf += ($yt <=> $yf) if $yf != $yt;
            ($working_x, $working_y) = ($xf, $yf);

            my $letterto = $map->[$yf]->[$xf];

            @boulder_locations = map {
                $_ eq $nextmovef ? $letterto : $_
            } @boulder_locations;

            $nextmovef = $letterto;

            redo if $nextmovef ne $nextmovet;
        }
    }

    TAEB->log->spoiler("This Sokoban puzzle has deviated from spoilers. " .
                       "(expected $origboulder_locations, got " .
                       (join '-',@current_boulder_locations) . "), misplaced " .
                       (defined($misplaced_x) ? $misplaced_x : "undef"),
                       level => 'info');
    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=head2 recognize_sokoban_variant [Level] -> Maybe Str [Int Int]

Returns the variant of Sokoban that Level is, or undef if it isn't a
Sokoban level. This is a string giving NetHack's internal name for the
level. If called in list context, also gives the x and y offset of the
map from the spoiler. If no level is given, defaults to TAEB's current
level.

=head2 first_unsolved_sokoban_level -> Level

Returns the lowest level in Sokoban that is not yet completely solved
but that TAEB has encountered in the past.

=head2 last_solved_sokoban_level -> Level

Returns the highest level in Sokoban that is now completely solved.

=head2 first_solvable_sokoban_level [Pathable] -> Level

Returns the lowest level in Sokoban that can be solved from here
(i.e. is not yet completely solved and has not been fatally messed up)
but that TAEB has encountered in the past. Pathable has the same
meaning as with next_sokoban_step.

=head2 number_of_solved_sokoban_levels -> Level

Returns the number of Sokoban levels that have been solved.

=head2 remaining_pits [Level] [Str] -> Int

Returns the number of pits/holes remaining on level Level (defaulting
to the current level). When this is 0, the level is solved. The second
argument is a string giving the variant, which can be added to avoid
recalculating the variant if it's already known; if omitted, the
variant will be calculated by looking ath the level map.

=head2 probably_has_genuine_boulder Tile -> Bool

Returns true if the tile appears to have a boulder on, and it probably
is a genuine boulder, rather than a mimic pretending. To be precise,
this returns true if we've pushed a boulder onto the square and
haven't pushed it off again, or if the tile is obscured and appears to
have a boulder; this handles all cases but that of a mimic visible
when we arrive on the level, and a search should detect that. This
routine will also mark pits on the map where they exist underneath
boulder-mimics, in order to be able to detect the mimics, if no pits
or traps have been closed on the level.

=head2 is_sokoban_reward_tile Tile -> Bool

Returns true if the tile is one on which the reward item for Sokoban
(the bag of holding or amulet of reflection) could be generated.

=head2 next_sokoban_step Level [Pathable] -> Maybe Tile

Return the tile that we need to head to next to solve the Sokoban
puzzle on Level. If the tile is a boulder, we're standing in the right
place and should push the boulder; if it's a floor tile, we should go
there; and if it's undef, either we're finished or we've deviated from
the spoilers. The optional second argument is a coderef which takes a
tile as argument and returns whether it's possible to path to that tile
by walking; if not given, it uses the built-in TAEB pathing routines.
(This is needed because the solution from a given configuration can
depend on which side of the boulders TAEB is standing; out of the
several possible moves, only one will be routable, and it returns that
move.)

This routine errors out if the level given is not a Sokoban level (in
that it doesn't match any of the maps it has spoilers for); it exits
silently with undef if the level is already solved, and gives a
warning and exits with undef if the level cannot be solved from here
based on its current knowledge. Note that this routine merely
specifies what the next move is; it does not guarantee that the move
is possible (for instance, there might be a monster behind the
boulder).

This routine does not make any assumptions about the behavior of the
AI, and is stateless (it is based entirely on current information,
rather than anything memorized).

=cut
