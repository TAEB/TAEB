package TAEB::Debug::Map;
use Moose;
use TAEB::OO;
use TAEB::Util::World 'vi2delta';
use TAEB::Util::Menu 'item_menu';

TAEB->register_debug_commands(
    ';' => {
        help    => "Debug map",
        command => sub { TAEB->debugger->map->activate },
    },
);

for my $name (qw/x y z z_index/) {
    has $name => (
        traits  => ['Counter'],
        isa     => 'Int',
        is      => 'rw',
        default => 0,
        handles => { "inc_$name" => 'inc' },
    );
}

has topline => (
    isa        => 'Str',
    is         => 'rw',
    lazy_build => 1,
);

sub _build_topline {
    my $self = shift;
    return $self->tile->debug_line;
}

sub levels_here {
    my $self = shift;
    my $z = shift;
    $z = $self->z unless defined $z;
    return grep { $_->turns_spent_on != 0 } TAEB->dungeon->get_levels($z);
}

sub z_with_branch {
    my $self = shift;
    my $z = shift;
    my $align = shift || TAEB->current_level;

    my @here = $self->levels_here($z);

    if (! @here) {
        $self->topline("No levels at that depth.");
        return;
    }

    $self->z($z);
    $self->z_index(0);

    for my $z_index (0 .. $#here) {
        if ($here[$z_index] == $align ||
                ($here[$z_index]->branch || '') eq ($align->branch || '')) {
            $self->z_index($z_index);
            last;
        }
    }

    if (@here > 1) {
        $self->topline("Note: there are " . @here . " levels at this depth. Use v to see the next.");
    }

    1;
}

sub level {
    my $self = shift;
    my @here = $self->levels_here;

    return $here[$self->z_index % @here];
}

sub tile {
    my $self = shift;

    return $self->level->at($self->x, $self->y);
}

sub _change_level_command {
    my $self      = shift;
    my $direction = shift;

    if ($self->tile->does('TAEB::World::Tile::Role::LevelChanger') && $self->tile->other_side_known) {
        my $other_tile = $self->tile->other_side;
        my $other_level = $other_tile->level;
        $self->z_with_branch($other_level->z, $other_level);
        $self->x($other_tile->x);
        $self->y($other_tile->y);
    }
    else {
        $self->z_with_branch($self->z + $direction);
    }
}

# Commands should return true if they need to force a redraw, or undef
# if they are a terminator.

my %normal_commands;

%normal_commands = (
    (map { my ($dx, $dy) = vi2delta $_;
           $_    => sub { my $self = shift;
                          $self->inc_x($dx); $self->inc_y($dy); 0; },
           uc $_ => sub { my $self = shift;
                          $self->inc_x(8*$dx); $self->inc_y(8*$dy); 0; } }
         qw/h j k l y u b n/),

    (map { $_ => sub { undef } } "\e", "\n", ";", ".", " ", "Q"),

    '?' => {
        help    => 'List map debugger commands',
        command => sub {
            my @commands;
            for my $key (sort { lc($a) cmp lc($b) } keys %normal_commands) {
                my $command = $normal_commands{$key};
                next unless ref($command) eq 'HASH';

                push @commands, TAEB::Display::Menu::Item->new(
                    title    => $command->{help},
                    selector => $key,
                );
            }

            item_menu(
                'Map debugger commands',
                \@commands,
                { select_type => 'none' },
            );

            1;
        },
    },
    'q' => {
        help    => 'Return to play',
        command => sub { undef },
    },
    '<' => {
        help    => 'Up one level',
        command => sub { shift->_change_level_command(-1); 1 },
    },
    '>' => {
        help    => 'Down one level',
        command => sub { shift->_change_level_command(+1); 1 },
    },
    'v' => {
        help    => 'Browse other branch levels at this depth',
        command => sub { shift->inc_z_index(+1); 1 },
    },
    'i' => {
        help    => 'View items on the selected tile',
        command => sub {
            my $tile = shift->tile;
            my @items = $tile->items;
            item_menu (@items ? ("The items on $tile", \@items)
                    : ("The items on " . $tile->level, [ $tile->level->items ]));
            1;
        },
    },
    't' => {
        help    => 'Browse metadata associated with selected tile',
        command => sub {
            my $t = shift->tile;
            item_menu("Tile data for (" . $t->x . "," . $t->y . ")", $t);
            1;
        },
    },
    'T' => {
        help    => 'Browse metadata associated with selected level',
        command => sub {
            my $level = shift->level;
            item_menu("Level data for " . $level, $level);
            1;
        },
    },
    'm' => {
        help    => 'Browse metadata associated with monster on selected tile',
        command => sub {
            if (my $monster = shift->tile->monster) {
                item_menu("Monster data for $monster", $monster);
                return 1;
            }
            return 0;
        },
    },
    'd' => {
        help    => 'Change draw mode',
        command => sub { TAEB->display->change_draw_mode; 1; },
    },
);

sub activate {
    my $self = shift;
    my $redraw = 1;
    my %commands = (%normal_commands, TAEB->ai->map_commands);

    $self->x(TAEB->x);
    $self->y(TAEB->y);

    $self->z_with_branch(TAEB->z, TAEB->current_level);

    COMMAND: while (1) {
        TAEB->display_topline($self->topline);
        $self->clear_topline;

        TAEB->redraw(level => $self->level,
            botl => "Displaying " . $self->level) if $redraw;

        TAEB->place_cursor($self->x, $self->y);

        my $c = TAEB->get_key;

        if ($commands{$c}) {
            my $command = $commands{$c};
            if (ref($command) eq 'HASH') {
                $command = $command->{command};
            }

            $redraw = $command->($self);
            last if !defined($redraw);
        } else {
            $self->topline("Unknown command '$c'. See ? for help.");
            $redraw = 0;
        }

        $self->x($self->x % 80);
        $self->y(($self->y-1)%21+1);
    }

    TAEB->redraw;
}

__PACKAGE__->meta->make_immutable;

1;
