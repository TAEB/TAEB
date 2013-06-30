package TAEB::Display::Curses;
use Moose;
use TAEB::OO;
use Curses ();
use TAEB::Util::Colors;
use TAEB::Util qw/max refaddr/;
use TAEB::Util::World qw/tile_type_to_glyph tile_type_to_color deltas/;
use Time::HiRes 'gettimeofday';

extends 'TAEB::Display';

use constant to_screen => 1;

has color_method => (
    is      => 'rw',
    isa     => 'Str',
    clearer => 'reset_color_method',
    lazy    => 1,
    default => sub {
        TAEB->config->get_display_config->{color_method} || 'normal';
    },
);

has glyph_method => (
    is      => 'rw',
    isa     => 'Str',
    clearer => 'reset_glyph_method',
    lazy    => 1,
    default => sub {
        TAEB->config->get_display_config->{glyph_method} || 'normal';
    },
);

has time_buffer => (
    is      => 'ro',
    isa     => 'ArrayRef[Num]',
    default => sub { [] },
);

has initialized => (
    is  => 'rw',
    isa => 'Bool',
);

has requires_redraw => (
    is  => 'rw',
    isa => 'Bool',
    default => 1,
);

sub institute {
    shift->initialized(1);

    $ENV{'ESCDELAY'} ||= 50; #talk about gross argument passing conventions
    Curses::initscr;
    Curses::noecho;
    Curses::cbreak;
    Curses::meta(Curses::stdscr, 1);
    Curses::keypad(Curses::stdscr, 1);
    Curses::start_color;
    Curses::use_default_colors;
    Curses::init_pair($_, $_, 0) for 0 .. 7;
}

augment reinitialize => sub {
    my $self = shift;
    $self->initialized(1);

    Curses::initscr;

    # need to do this again for some reason
    $self->redraw(force_clear => 1);
};

sub deinitialize {
    my $self = shift;

    return unless $self->initialized;

    $self->initialized(0);

    Curses::clear();
    Curses::refresh();

    Curses::def_prog_mode();
    Curses::endwin();
}

sub notify {
    my $self  = shift;
    my $msg   = shift;
    my $color = shift;
    my $sleep = @_ ? shift : 3;

    return if !defined($msg) || !length($msg);

    # strip off extra lines, it's too distracting
    $msg =~ s/\n.*//s;

    Curses::move(1, 0);
    Curses::attron(Curses::COLOR_PAIR($color->index));
    Curses::addstr($msg);
    Curses::attroff(Curses::COLOR_PAIR($color->index));
    Curses::clrtoeol;

    # using TAEB->x and TAEB->y here could screw up horrifically if the dungeon
    # object isn't loaded yet, and loading it calls notify..
    $self->place_cursor(TAEB->vt->x, TAEB->vt->y);
    $self->requires_redraw(1);

    return if $sleep == 0;

    sleep $sleep;
    $self->redraw;
}

my %standard_modes;
my ($drawn_cursorx, $drawn_cursory) = (0,0);

# Not per-object, as there's only one screen to draw on
our $last_level_redrawn = undef;

sub redraw {
    my $self = shift;
    my %args = @_;

    if ($args{force_clear}) {
        Curses::clear;
        Curses::refresh;
        $self->requires_redraw(1);
    }
    $last_level_redrawn = undef if $self->requires_redraw;

    my $level  = $args{level} || TAEB->current_level;

    my %modes = (%standard_modes, TAEB->ai->drawing_modes);

    my $color_mode = $modes{$self->color_method} || {};
    my $glyph_mode = $modes{$self->glyph_method} || {};

    my $glyph_fun = $glyph_mode->{glyph} || sub { $_[0]->normal_glyph };
    my $color_fun = $color_mode->{color} || sub { $_[0]->normal_color };

    my $bbox_only = $color_mode->{bounding_box_only}
                 && $glyph_mode->{bounding_box_only}
                 && $last_level_redrawn
                 && $last_level_redrawn == $level;
    $last_level_redrawn = $level;
    my ($bb_l, $bb_r, $bb_t, $bb_b) = (0, 79, 1, 21);
    my $cartographer = TAEB->dungeon->cartographer;
    if ($bbox_only && $bb_t >= 1) {
        $bb_l = $cartographer->tilechange_l
            if defined $cartographer->tilechange_l;
        $bb_r = $cartographer->tilechange_r
            if defined $cartographer->tilechange_r;
        $bb_t = $cartographer->tilechange_t
            if defined $cartographer->tilechange_t;
        $bb_b = $cartographer->tilechange_b
            if defined $cartographer->tilechange_b;
    }

    $color_mode->{onframe}() if $color_mode->{onframe};
    $glyph_mode->{onframe}() if $glyph_mode->{onframe} &&
        $color_mode != $glyph_mode;

    my $curses_color;
    my $lastcolor_addr = 0;
    for my $y ($bb_t .. $bb_b) {
        Curses::move($y, $bb_l);
        for my $x ($bb_l .. $bb_r) {
            my $tile = $level->at($x, $y);
            my $color = $color_fun->($tile);
            my $glyph = $glyph_fun->($tile);
            # Note: $color and $glyph may not be mutated by this function,
            # as they may be memoized constant colours

            my $color_addr = refaddr $color;
            if ($color_addr != $lastcolor_addr) {
                $curses_color = Curses::COLOR_PAIR($color->index);
                $curses_color |= Curses::A_BOLD if $color->bold;
                $lastcolor_addr = $color_addr;
            }

            Curses::addch($curses_color | ord($glyph));
        }
        Curses::clrtoeol if $self->requires_redraw;
    }

    ($drawn_cursorx, $drawn_cursory) = (TAEB->x, TAEB->y);

    $self->draw_botl($args{botl}, $args{status});
    $self->place_cursor;
    $self->requires_redraw(0);
}

sub draw_botl {
    my $self   = shift;
    my $botl   = shift;
    my $status = shift;

    return unless TAEB->state eq 'playing';

    Curses::move(22, 0);

    if (!$botl) {
        my $command = TAEB->has_action ? TAEB->action->command : '?';
        $command =~ s/\n/\\n/g;
        $command =~ s/\e/\\e/g;
        $command =~ s/\cd/^D/g;

        $botl = TAEB->checking ? "Checking " . TAEB->checking
              : TAEB->state eq 'dying' ? "Viewing death " . TAEB->death_state
              : TAEB->currently . " ($command)";
    }

    Curses::addstr($botl);

    Curses::clrtoeol;
    Curses::move(23, 0);

    if (!$status) {
        my @pieces;
        push @pieces, 'D:' . TAEB->current_level->z;
        $pieces[-1] .= uc substr(TAEB->current_level->branch, 0, 1)
            if TAEB->current_level->known_branch;
        $pieces[-1] .= ' ('. ucfirst(TAEB->current_level->special_level) .')'
            if TAEB->current_level->special_level;

        # Avoid undef warnings
        my $hp    = TAEB->hp;
        my $maxhp = TAEB->maxhp;
        push @pieces, 'H:' . (defined $hp ? $hp : '?');
        $pieces[-1] .= '/' . (defined $maxhp ? $maxhp : '?')
            if !defined($hp) || !defined($maxhp) || $hp != $maxhp;

        if (TAEB->spells->has_spells) {
            push @pieces, 'P:' . TAEB->power;
            $pieces[-1] .= '/' . TAEB->maxpower
                if TAEB->power != TAEB->maxpower;
        }

        push @pieces, 'A:' . TAEB->ac;
        push @pieces, 'X:' . TAEB->level;
        push @pieces, 'N:' . TAEB->nutrition;
        push @pieces, 'T:' . TAEB->turn . '/' . TAEB->step;
        push @pieces, 'S:' . TAEB->score
            if TAEB->has_score;
        push @pieces, '$' . TAEB->gold;

        my $resistances = join '', map {  /^(c|f|p|d|sl|sh)\w+/ } TAEB->resistances;
        push @pieces, 'R:' . $resistances
            if $resistances;

        my $statuses = join '', map { ucfirst substr $_, 0, 2 } TAEB->statuses;
        push @pieces, '[' . $statuses . ']'
            if $statuses;

        my $timebuf = $self->time_buffer;
        if (@$timebuf > 1) {
            my $secs = $timebuf->[0] - $timebuf->[1];
            push @pieces, sprintf "%1.1fs", $secs;
        }

        $status = join ' ', @pieces;
    }

    Curses::addstr($status);
    Curses::clrtoeol;

    if (TAEB->paused) {
        Curses::move(23, 70);
        Curses::attron(Curses::A_BOLD);
        Curses::addstr(" -PAUSED-");
        Curses::attroff(Curses::A_BOLD);
        Curses::clrtoeol;
    }
}

sub place_cursor {
    my $self = shift;
    my $x    = shift || $drawn_cursorx;
    my $y    = shift || $drawn_cursory;

    return unless defined($x) && defined($y);

    Curses::move($y, $x);
    Curses::refresh;
}

sub display_topline {
    my $self = shift;

    if (@_) {
        Curses::move 0, 0;
        Curses::clrtoeol;
        Curses::addstr "@_";
        $self->place_cursor if TAEB->loaded_persistent_data;
        Curses::refresh;
        return;
    }

    my @messages = TAEB->parsed_messages;

    if (@messages == 0) {
        # we don't need to worry about the other rows, the map will
        # overwrite them
        Curses::move 0, 0;
        Curses::clrtoeol;
        $self->place_cursor if TAEB->loaded_persistent_data;
        return;
    }

    while (my @msgs = splice @messages, 0, 20) {
        my $y = 0;
        for (@msgs) {
            my ($line, $matched) = @$_;

            my $chopped = length($line) > 75;
            $line = substr($line, 0, 75);

            Curses::move $y++, 0;

            my $color = $matched
                      ? Curses::COLOR_PAIR(COLOR_GREEN->index)
                      : Curses::COLOR_PAIR(COLOR_BROWN->index);

            Curses::attron($color);
            Curses::addstr($line);
            Curses::attroff($color);

            Curses::addstr '...' if $chopped;

            Curses::clrtoeol;
        }

        if (@msgs > 1) {
            $self->requires_redraw(1);
            $self->place_cursor;
            TAEB->redraw if @messages;
        }
    }
    $self->place_cursor;
}

augment display_menu => sub {
    my $self = shift;
    my $menu = shift;

    require Data::Page;
    my $pager = Data::Page->new;
    $pager->entries_per_page(22);
    $pager->current_page(1);

    my $is_searching = 0;
    KEYSTROKE: while (1) {
        $pager->total_entries(scalar $menu->items);

        $self->draw_menu($menu, $pager, $is_searching);

        my $c = $self->get_key;
        if ($c eq "\cr") {
            $self->redraw(force_clear => 1);
        }
        elsif ($is_searching) {
            if ($c eq "\e") {
                $is_searching = 0;
                $menu->clear_search;
            }
            elsif ($c eq "\n") {
                # If we hit enter on a search with only one result, return it
                if ($pager->total_entries == 1) {
                    $menu->select(0);
                    last;
                }

                $is_searching = 0;
            }
            elsif ($c eq "\b" || ord($c) == 127) {
                if (length($menu->search) == 0) {
                    $is_searching = 0;
                    $menu->clear_search;
                }
                else {
                    chop(my $search = $menu->search);
                    $menu->search($search);
                }
            }
            else {
                $menu->search($menu->search . $c);
            }
        }
        else {
            if (($c eq '>' || $c eq ' ') && $pager->next_page) {
                $pager->current_page($pager->next_page);
            }
            elsif ($c eq '<' && $pager->previous_page) {
                $pager->current_page($pager->previous_page);
            }
            elsif ($c eq '^') {
                $pager->current_page($pager->first_page);
            }
            elsif ($c eq '|') {
                $pager->current_page($pager->last_page);
            }
            elsif ($c eq ' ' || $c eq "\n") {
                last;
            }
            elsif ($c eq "\e") {
                $menu->clear_selections;
                last;
            }
            elsif ($c eq ':') {
                $is_searching = 1;
                $menu->search('');
                $pager->current_page(1);
            }
            elsif ($pager->entries_on_this_page) {
                my @visible_items = map { $menu->item($_ - 1) }
                                    $pager->first .. $pager->last;

                no warnings 'uninitialized';
                ITEM: for my $i (0 .. $#visible_items) {
                    my $item = $visible_items[$i];

                    next unless $item->selector eq $c
                             || $item->temporary_selector eq $c;

                    $menu->select($item);
                    last KEYSTROKE if $menu->select_type eq 'single';
                    last ITEM;
                }
            }
        }
    }
};

sub draw_menu {
    my $self   = shift;
    my $menu   = shift;
    my $pager  = shift;
    my $search = shift;

    $self->redraw;

    my @rows = $menu->description;

    my $i = 0;

    if ($pager->total_entries > 0) {
        my @visible_items = map { $menu->item($_ - 1) }
                            $pager->first .. $pager->last;

        my %seen_selector;
        my $selector_length = 1;
        for my $selector (map { $_->selector } grep { $_->has_selector } @visible_items) {
            $seen_selector{$selector} = 1;
            $selector_length = length($selector)
                if length($selector) > $selector_length;
        }

        for my $item (@visible_items) {
            my $separator = $item->selected ? '+' : '-';
            my $selector  = $item->selector;

            if (!$selector) {
                do {
                    $selector = chr($i++ + ord('a'));
                } while $seen_selector{$selector};
                $item->temporary_selector($selector);
            }

            push @rows, sprintf '%*s %s %s',
                            $selector_length,
                            $selector,
                            $separator,
                            $item->title;
        }
    }

    if ($menu->has_search) {
        my $sep = $search ? ':' : '-';
        push @rows, $pager->total_entries . "$sep  " . $menu->search;
    }
    elsif ($pager->first_page == $pager->last_page) {
        push @rows, "(end) ";
    }
    else {
        push @rows, "("
                  . $pager->current_page
                  . " of "
                  . $pager->last_page
                  . ") ";
    }

    my $max_length = max map { length } @rows;

    my $x = $max_length > 50 || $pager->total_entries > 21
          ? 0
          : 78 - $max_length;

    my $row = 0;
    for (@rows) {
        Curses::move($row++, $x);
        Curses::addstr(' ' . $_);
        Curses::clrtoeol();
    };

    if ($x == 0) {
        for ($row .. 23) {
            Curses::move($_, 0);
            Curses::clrtoeol();
        }
    }

    # move to right after the (x of y) or (end) prompt
    Curses::move($row - 1, length($rows[-1]) + $x + 1);
}

my %spell_in_minimum;
my %spell_in_maximum;
my %spell_in_bounce_minimum;
my %spell_in_bounce_maximum;

%standard_modes = (
    normal =>    { description => 'Normal NetHack colors',
                   color => sub { shift->normal_color },
                   bounding_box_only => 1,},
    debug  =>    { description => 'Debug coloring',
                   color => sub { shift->debug_color } },
    engraving => { description => 'Engraving coloring',
                   color => sub { shift->engraving_color },
                   bounding_box_only => 1,},
    stepped =>   { description => 'Stepped-on coloring',
                   color => sub { shift->stepped_color },
                   bounding_box_only => 1,},
    time =>      { description => 'Time-since-stepped coloring',
                   color => sub { shift->time_color },
                   bounding_box_only => 1,},
    lit =>       { description => 'Highlight lit tiles',
                   color => sub { shift->lit_color } },
    los =>       { description => 'Highlight line-of-sight',
                   color => sub { shift->los_color } },
    floor =>     { description => 'Hide objects and monsters',
                   glyph => sub { shift->floor_glyph },
                   bounding_box_only => 1,},
    terrain =>   { description => 'Display terrain knowledge',
                   glyph => sub { tile_type_to_glyph(shift->type) },
                   color => sub { tile_type_to_color(shift->type) },
                   bounding_box_only => 1,},
    item =>      { description => 'Hide monsters',
                   glyph => sub { shift->itemly_glyph },
                   color => sub { shift->itemly_color },
                   bounding_box_only => 1,},
    reset =>     { description => 'Reset to configured settings',
                   immediate => sub {
                       my $self = shift;
                       $self->reset_color_method;
                       $self->reset_glyph_method;
                   } },

    spell => {
        description => 'Spell targets',
        color       => sub {
            my $ref = refaddr(shift);
            return $spell_in_minimum{$ref}        ? COLOR_RED
                 : $spell_in_maximum{$ref}        ? COLOR_YELLOW
                 : $spell_in_bounce_minimum{$ref} ? COLOR_BRIGHT_BLUE
                 : $spell_in_bounce_maximum{$ref} ? COLOR_CYAN
                                                  : COLOR_GRAY;
        },
        onframe     => sub {
            my $min = 6;
            my $max = 13;

            %spell_in_minimum = ();
            %spell_in_maximum = ();
            %spell_in_bounce_minimum = ();
            %spell_in_bounce_maximum = ();

            my ($x, $y) = (TAEB->x, TAEB->y);

            for (deltas) {
                my ($dx, $dy) = @$_;

                my @tile_set;
                TAEB->current_level->_beam_fly(\@tile_set, 0, $dx, $dy, $x, $y, $min);
                $spell_in_minimum{refaddr $_->[1]} = 1 for @tile_set;

                @tile_set = ();
                TAEB->current_level->_beam_fly(\@tile_set, 0, $dx, $dy, $x, $y, $max);
                $spell_in_maximum{refaddr $_->[1]} = 1 for @tile_set;

                @tile_set = ();
                TAEB->current_level->_beam_fly(\@tile_set, 1, $dx, $dy, $x, $y, $min);
                $spell_in_bounce_minimum{refaddr $_->[1]} = 1 for @tile_set;

                @tile_set = ();
                TAEB->current_level->_beam_fly(\@tile_set, 1, $dx, $dy, $x, $y, $max);
                $spell_in_bounce_maximum{refaddr $_->[1]} = 1 for @tile_set;

            }
        }
    },
);

sub change_draw_mode {
    my $self = shift;

    my %modes = (%standard_modes, TAEB->ai->drawing_modes);

    my $menu = TAEB::Display::Menu->new(
        description => "Change draw mode",
        items       => [ sort map { $_->{description} } values %modes ],
        select_type => 'single',
    );

    defined(my $item = $self->display_menu($menu))
        or return;

    my $change = $item->title;

    my ($key) = grep { $modes{$_}{description} eq $change } keys %modes;

    $self->glyph_method($key) if $modes{$key}{glyph};
    $self->color_method($key) if $modes{$key}{color};

    $modes{$key}{immediate}($self) if $modes{$key}{immediate};

    $self->requires_redraw(1);
}

subscribe step => sub {
    my $self = shift;
    my $time = gettimeofday;
    my $list = $self->time_buffer;

    unshift @$list, $time;
    splice @$list, 2 if @$list > 2;
};

sub get_key { Curses::getch }

sub try_key {
    my $self = shift;

    Curses::nodelay(Curses::stdscr, 1);
    my $c = Curses::getch;
    Curses::nodelay(Curses::stdscr, 0);

    return if $c eq -1;
    return $c;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 change_draw_mode

This is a debug command. It's expected to read another character from the
keyboard deciding how to change the draw mode.

Eventually we may want a menu interface but this is fine for now.

=cut
