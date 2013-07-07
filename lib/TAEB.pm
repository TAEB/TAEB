package TAEB;
use 5.008001;
# ABSTRACT: the Tactical Amulet Extraction Bot (for NetHack)
use TAEB::Util::Colors ':all';
use TAEB::Util::World 'tile_types';
use TAEB::Util::Menu;

use Moose;
use TAEB::OO;

use Log::Dispatch::Null;
use Try::Tiny;

our %debug_commands;

sub register_debug_commands {
    my $self = shift;

    while (my ($key, $command) = splice @_, 0, 2) {
        if (exists $debug_commands{$key}) {
            confess "$key is already a registered debug command";
        }

        $debug_commands{$key} = $command;
    }
}

use TAEB::Config;
use TAEB::Display::Curses;
use TAEB::VT;
use TAEB::Logger;
use TAEB::ScreenScraper;
use TAEB::Spoilers;
use TAEB::World;
use TAEB::Senses;
use TAEB::Action;
use TAEB::Publisher;
use TAEB::Debug;

with (
    'TAEB::Role::Persistency',
);

class_has persistent_data => (
    is        => 'ro',
    isa       => 'HashRef',
    lazy      => 1,
    predicate => 'loaded_persistent_data',
    default   => sub {
        my $file = TAEB->persistent_file;
        return {} unless defined $file && -r $file;

        TAEB->log->main("Loading persistency data from $file.");
        return eval { Storable::retrieve($file) } || {};
    },
);

class_has interface => (
    is       => 'rw',
    isa      => 'TAEB::Interface',
    handles  => [qw/read write/],
    lazy     => 1,
    default  => sub {
        my $interface_config = TAEB->config->get_interface_config;
        TAEB->config->get_interface_class->new($interface_config);
    },
);

class_has ai => (
    traits    => [qw/TAEB::Persistent/],
    is        => 'rw',
    isa       => 'TAEB::AI',
    handles   => [qw(currently)],
    predicate => 'has_ai',
    writer    => 'set_ai', # for efficiency when TAEB->ai is in the inner loop
    lazy      => 1,
    default   => sub {
        my $class = TAEB->config->get_ai_class;
        my $ai = $class->new;

        $ai->isa('TAEB::AI')
            or die "$class does not inherit from TAEB::AI!";

        $ai->institute; # default doesn't fire triggers
        $ai;
    },
);
after set_ai => sub {
    my (undef, $ai) = @_;
    TAEB->log->main("Now using AI $ai.");
    $ai->institute;
};

class_has scraper => (
    is       => 'ro',
    isa      => 'TAEB::ScreenScraper',
    lazy     => 1,
    default  => sub { TAEB::ScreenScraper->new },
    handles  => [qw(parsed_messages all_messages messages farlook scrape)],
);

class_has config => (
    is       => 'ro',
    isa      => 'TAEB::Config',
    default  => sub { TAEB::Config->new },
);

class_has vt => (
    is       => 'ro',
    isa      => 'TAEB::VT',
    lazy     => 1,
    default  => sub {
        my $vt = TAEB::VT->new(cols => 80, rows => 24, zerobased => 1);
        $vt->option_set(LINEWRAP => 1);
        $vt->option_set(LFTOCRLF => 1);
        return $vt;
    },
    handles  => ['topline'],
);

class_has state => (
    is      => 'rw',
    isa     => 'TAEB::Type::PlayState',
    default => 'logging_in',
    trigger => sub {
        my (undef, $state) = @_;
        TAEB->log->main("Game state has changed to $state.");
    },
);

class_has paused => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

class_has log => (
    is      => 'ro',
    isa     => 'TAEB::Logger',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $log = TAEB::Logger->new;
        $log->add_as_default(Log::Dispatch::Null->new(
            name => 'taeb-warning',
            min_level => 'warning',
            max_level => 'warning',
            callbacks => sub {
                my %args = @_;
                if (!defined TAEB->display
                 || !TAEB->display->to_screen) {
                    local $SIG{__WARN__};
                    warn $args{message};
                }
            },
        ));
        $log->add_as_default(Log::Dispatch::Null->new(
            name => 'taeb-error',
            min_level => 'error',
            callbacks => sub {
                my %args = @_;
                if (!defined TAEB->display
                 || !TAEB->display->to_screen) {
                    local $SIG{__WARN__};
                    confess $args{message};
                }
                else {
                    TAEB->complain(Carp::shortmess($args{message}));
                }
            },
        ));
        TAEB->setup_handlers;
        return $log;
    },
);

class_has dungeon => (
    traits  => [qw/TAEB::Persistent/],
    is      => 'ro',
    isa     => 'TAEB::World::Dungeon',
    default => sub { TAEB::World::Dungeon->new },
    handles => sub {
        my ($attr, $dungeon) = @_;

        my %delegate = map { $_ => $_ }
                       qw{current_level current_tile
                          nearest_level_to nearest_level shallowest_level
                          farthest_level_from farthest_level deepest_level
                          map_like x y z fov};

        for ($dungeon->get_all_method_names) {
            $delegate{$_} = $_
                if m{
                    ^
                    (?: each | any | all | grep ) _
                    (?: orthogonal | diagonal | adjacent )
                    (?: _inclusive )?
                    $
                }x;
        }

        return %delegate;
    },
);

class_has senses => (
    traits    => [qw/TAEB::Persistent/],
    is        => 'ro',
    isa       => 'TAEB::Senses',
    default   => sub { TAEB::Senses->new },
    handles   => qr/^(?!_check_|msg_|subscription_|update|initialize|config)/,
    predicate => 'has_senses',
);

class_has spells => (
    traits  => [qw/TAEB::Persistent/],
    is      => 'ro',
    isa     => 'TAEB::World::Spells',
    default => sub { TAEB::World::Spells->new },
    handles => {
        find_spell    => 'find',
        find_castable => 'find_castable',
        knows_spell   => 'knows_spell',
    },
);

class_has publisher => (
    is      => 'ro',
    isa     => 'TAEB::Publisher',
    lazy    => 1,
    default => sub { TAEB::Publisher->new },
    handles => [qw/announce send_message get_exceptional_response get_response get_location_request remove_messages/],
);

class_has action => (
    is        => 'rw',
    isa       => 'TAEB::Action',
    predicate => 'has_action',
    trigger   => sub {
        my ($self, $new_value) = @_;
        $self->previous_action($new_value) if $new_value;
        $self->_add_old_action($new_value);
    },
);

class_has previous_action => (
    is        => 'rw',
    isa       => 'TAEB::Action',
    predicate => 'has_previous_action',
);

class_has old_actions => (
    traits  => ['Array'],
    isa     => 'ArrayRef[TAEB::Action]',
    default => sub { [] },
    handles => {
        _old_actions => 'elements',
        _add_old_action => 'push',
    },
    documentation => "Not meant for general consumption, just debugging (command: a)",
);


class_has new_game => (
    is  => 'rw',
    isa => 'Bool',
    trigger => sub {
        my $self = shift;
        my $new = shift;

        # just in case we missed doing this last time we died
        # we might want some way to prevent all loading from the state file
        # before new_game is called to make this a bit more correct
        $self->destroy_saved_state if $new;

        # by the time we have called new_game, we know whether or not we want
        # to load the class from a state file or from defaults. so, do
        # initialization here that should be done each time the app starts.
        $self->log->main("calling initialize");
        $self->initialize;
    },
);

class_has debugger => (
    is      => 'ro',
    isa     => 'TAEB::Debug',
    default => sub { TAEB::Debug->new },
    handles => ['add_category_time'],
);

class_has display => (
    is      => 'ro',
    isa     => 'TAEB::Display',
    trigger => sub { shift->display->institute },
    lazy    => 1,
    default   => sub {
        my $display = TAEB->config->get_display_class->new;
        $display->institute; # default doesn't fire triggers
        $display;
    },
    handles => [qw/notify redraw display_topline get_key try_key place_cursor
                   display_menu/],
);

class_has item_pool => (
    traits  => [qw/TAEB::Persistent/],
    is      => 'ro',
    isa     => 'TAEB::World::ItemPool',
    default => sub { TAEB::World::ItemPool->new },
    handles => {
        get_artifact  => 'get_artifact',
        seen_artifact => 'get_artifact',
    },
);

around action => sub {
    my $orig = shift;
    my $self = shift;
    return $orig->($self) unless @_;
    $self->publisher->unsubscribe($self->action) if $self->action;
    my $ret = $orig->($self, @_);
    $self->publisher->subscribe($self->action);
    return $ret;
};

sub next_action {
    my $self = shift;

    my $action = $self->ai->next_action(@_)
        or confess $self->ai . " did not return a next_action!";

    # Canonicalize action-like things into the action
    if ($action->does('TAEB::Role::Actionable')) {
        $action = $action->as_action;
    }

    confess $self->ai . "'s next_action returned a non-action!"
        unless $action->isa('TAEB::Action');

    confess $self->ai . " returned an action ($action) that is currently impossible!"
        if $action->is_impossible;

    return $action;
}

sub iterate {
    my $self = shift;

    my $report;

    # We're about to prevent normal Perl handling of errors.  Make absolutely
    # sure our replacement handler is loaded.

    TAEB->log;

    try {
        $self->human_input;

        unless ($self->paused) {
            $self->log->main("Starting a new step.");

            $self->full_input(1);

            $self->redraw;
            $self->display_topline;

            my $method = "handle_" . $self->state;
            $self->$method;
        } else {
            $self->redraw;
            $self->display_topline;
        }
    }
    catch {
        $self->display->deinitialize;

        warn $_ unless $_ =~ /^The\ game\ has\ ended\.
                             |The\ game\ has\ been\ saved\.
                             |The\ game\ could\ not\ start\./x;

        $report = $self->state eq 'unable_to_login'
                ? TAEB::Announcement::Report::CouldNotStart->new
                : $self->state eq 'dying'
                ? $self->death_report
                : TAEB::Announcement::Report::Saved->new;
    };

    return $report;
}

# Runs our action in $self->action, cleanly.
sub run_action {
    my $self = shift;
    $self->log->main("Current action: " . $self->action);
    $self->write($self->action->run);
}

sub handle_playing {
    my $self = shift;

    $self->action->done
        if $self->has_action
        && !$self->action->aborted;

    $self->currently('?');

    # In non-kiosk mode, we want AI croaks to be recoverable
    if (defined TAEB->config && defined TAEB->config->contents &&
        TAEB->config->contents->{'kiosk_mode'}) {
        $self->action($self->next_action);
        $self->run_action;
        return;
    }

    my $run_action = try {
        local $SIG{__DIE__} = sub {
            my ($message) = @_;

            if ($message =~ /^Interrupted\./) {
                $self->log->perl($message, level => 'info');
            }
            else {
                $self->log->perl(Carp::longmess($message), level => 'error');
            }

            $self->paused(1);
            $self->redraw;

            $self->complain("Press any key to continue -- $message", 0);
            $self->get_key;

            die;
        };

        $self->action($self->next_action);

        1;
    };

    $self->run_action if $run_action;
}

sub handle_human_override {
    my $self = shift;
    $self->currently('Performing an action due to human override');
    $self->run_action;
    # The override only lasts one turn, although that turn may end
    # the game (quit and save are common overrides).
    $self->state('playing') if $self->state eq 'human_override';
}

sub handle_logging_in {
    my $self = shift;

    if ($self->vt->contains("Hit space to continue: ") ||
        $self->vt->contains("Hit return to continue: ")) {
        # This message is sent by NetHack if it itself encounters an error
        # during the login process. If NetHack can't run, we can't play it,
        # so bail out.
        $self->log->main("NetHack itself has errored out, we can't continue.",
                        level => 'info');
        $self->state('unable_to_login');
        die "The game could not start";
    }
    elsif ($self->vt->contains("Shall I pick a character's ")) {
        $self->log->main("We are now in NetHack, starting a new character.");
        $self->write('n');
    }
    elsif ($self->topline =~ qr/Choosing Character's Role/) {
        $self->write($self->config->get_role);
    }
    elsif ($self->topline =~ qr/Choosing Race/) {
        $self->write($self->config->get_race);
    }
    elsif ($self->topline =~ qr/Choosing Gender/) {
        $self->write($self->config->get_gender);
    }
    elsif ($self->topline =~ qr/Choosing Alignment/) {
        $self->write($self->config->get_align);
    }
    elsif ($self->topline =~ qr/Restoring save file\.\./) {
        $self->log->main("We are now in NetHack, restoring a save file.");
        $self->write(' ');
    }
    elsif ($self->topline =~ qr/, welcome( back)? to NetHack!/) {
        $self->new_game($1 ? 0 : 1);
        # XXX Reset here since it shouldn't really be persisted
        $self->senses->is_friday_13th(0);
        $self->senses->is_new_moon(0);
        $self->senses->is_full_moon(0);
        $self->write(' ') if $self->vt->contains("--More--");
        $self->state('playing');
        $self->paused(1) if $self->config->contents->{start_paused};
        $self->send_message('check');
        $self->send_message('game_started');
    }
    elsif ($self->topline =~ /^\s*It is written in the Book of /) {
        $self->log->main("Using TAEB's nethackrc is MANDATORY. Use $0 --rc.",
                        level => 'error');
        die "Using TAEB's nethackrc is MANDATORY";
    }
}

sub full_input {
    my $self = shift;
    my $main_call = shift;

    $self->scraper->clear;

    $self->publisher->pause;
    $self->process_input;

    unless ($self->state eq 'logging_in') {
        $self->dungeon->update($main_call);

        $self->senses->inc_step;
        $self->send_message(step => TAEB::Announcement::Step->new);
    }
    $self->publisher->unpause;
}

sub process_input {
    my $self = shift;
    my $scrape = @_ ? shift : 1;

    my $input = $self->read;

    $self->vt->process($input);

    $self->scrape
        if $scrape && $self->state ne 'logging_in';

    return $input;
}

sub human_input {
    my $self = shift;

    my $method = $self->paused ? 'get_key' : 'try_key';

    my $c;
    $c = $self->$method unless $self->ai->is_human_controlled && !$self->paused;

    if (defined $c) {
        my $out = $self->keypress($c);
        if (defined $out) {
            $self->notify($out);
        }
    }
}

sub keypress {
    my $self = shift;
    my $c = shift;

    # don't accept debug commands before TAEB is ready
    return if $self->state eq 'logging_in';

    if ($debug_commands{$c}) {
        my $command = $debug_commands{$c};
        $command = $command->{command} if ref($command) eq 'HASH';
        $command->();
        return;
    }

    $self->announce(keypress => key => $c);
}

around notify => sub {
    my $orig = shift;
    my $self = shift;
    my $msg  = shift;

    unshift @_, COLOR_CYAN if !@_;

    $orig->($self, $msg, @_);
};

sub complain {
    my $self = shift;
    my $msg  = shift;

    $self->notify($msg, COLOR_RED, @_);
}

# allow the user to say TAEB->ai("human") and have it DTRT
around set_ai => sub {
    my $orig = shift;
    my $self = shift;

    $self->ai->deinstitute
        if $self->has_ai;

    if ($_[0] =~ /^\w+$/) {
        my $name = shift;

        # guess the case unless they tell us what it is (because of
        # ScoreWhore)
        $name = "\L\u$name" if $name eq lc $name;

        $name = "TAEB::AI::$name";

        (my $file = "$name.pm") =~ s{::}{/}g;
        require $file;

        return $self->$orig($name->new);
    }

    return $self->$orig(@_);
};

sub new_item {
    my $self = shift;
    my $item = $self->item_pool->new_item(@_);
    my $class = $item->meta->name;
    (my $taeb_class = $class) =~ s/^NetHack::Item/TAEB::World::Item/;
    $taeb_class->meta->rebless_instance($item);
    return $item;
}

sub inventory { shift->item_pool->inventory }

sub inventory_items { shift->item_pool->inventory->items }

sub has_item {
    my $self = shift;
    $self->inventory->find(@_);
}

sub has_identified {
    my $self     = shift;
    my $identity = shift;

    my @appearances = $self->item_pool->possible_appearances_of($identity);
    return $appearances[0] if @appearances == 1;
    return;
}

sub new_monster {
    my $self = shift;
    TAEB::World::Monster->new(@_);
}

sub equipment {
    my $self = shift;
    $self->inventory->equipment(@_);
}

# Does an emergency save and exit. This should be used only in
# situations where the state of the game is unknown (e.g. in response
# to an exception); otherwise, use TAEB::Action::Save instead. During
# or after running this, TAEB must exit via exception; this sub does
# not throw the exception itself, however, on the basis that it will
# usually be called inside exception handling. Seriously, any call to
# this outside the signal handler for die() should be considered
# highly suspect.
sub save {
    my $self = shift;
    $self->log->main("Doing an emergency save...", level => 'info');
    $self->write("   \e   \e     Sy");
    $self->interface->flush;
}
# The same above, but for quitting. Again, this is an uncontrolled
# exit, designed to work from any state; to exit in a controlled
# manner, use TAEB::Action::Quit. Only use this function inside an
# exception handler or other situation where the gamestate is unknown.
sub quit {
    my $self = shift;
    $self->log->main("Doing an emergency quit...", level => 'info');
    $self->write("   \e   \e     #quit\nyq");
    $self->interface->flush;
}

sub persistent_file {
    my $self = shift;

    my $interface = $self->config->interface;
    my $state_file = $self->config->taebdir_file("$interface.state");
}

sub play {
    my $self = shift;

    while (1) {
        my $report = $self->iterate;
        return $report if $report;
    }
}

sub reset_state {
    my $self = shift;
    my $meta = $self->meta;

    $self->remove_handlers;
    for my $attr ($meta->get_all_class_attributes) {
        $attr->clear_value($meta);
        $attr->set_value($meta, $attr->default($meta))
            if !$attr->is_lazy && $attr->has_default;
    }
}

sub setup_handlers {
    $SIG{__WARN__} = sub {
        my $method = $_[0] =~ /^Use of uninitialized / ? 'undef' : 'perl';
        TAEB->log->$method($_[0], level => 'warning');
    };

    $SIG{__DIE__} = sub {
        my $error = shift;

        # We want only the first line
        (my $message = $error) =~ s/\n.*//s;

        if ($message =~ /^The game has (ended|been saved)\./) {
            TAEB->log->main($message, level => 'info');

            if ($message =~ /ended/) {
                TAEB->destroy_saved_state;
            }
            else {
                TAEB->save_state;
            }
        }
        else {
            if ($message =~ /^Interrupted\./) {
                TAEB->log->perl($message, level => 'info');
            }
            else {
                TAEB->log->perl(Carp::longmess($error), level => 'error');
            }

            # Use the emergency versions of quit/save here, not the actions.
            if (defined TAEB->config && defined TAEB->config->contents &&
                TAEB->config->contents->{'kiosk_mode'}) {
                TAEB->quit;
                TAEB->destroy_saved_state;
            } else {
                TAEB->save;
                TAEB->save_state;
            }
        }
        # A failsafe function that handles all the weird things that might
        # happen during NetHack exiting, e.g. unavailable lockfile.
        TAEB->interface->wait_for_termination;
        die $error;
    };
    TAEB->monkey_patch;
}

sub remove_handlers {
    $SIG{__WARN__} = 'DEFAULT';
    $SIG{__DIE__}  = 'DEFAULT';
}

sub monkey_patch {
    # need to localize $SIG{__DIE__} in places where people call it inside of
    # evals without protection... this is ugly, but the cleanest way i can
    # think of
    my $yaml_any_meta = Class::MOP::Class->initialize('YAML::Any');
    $yaml_any_meta->add_around_method_modifier(implementation => sub {
        my $orig = shift;
        local $SIG{__DIE__};
        $orig->(@_);
    }) unless $yaml_any_meta->get_method('implementation')->isa('Class::MOP::Method::Wrapped');
}

TAEB->register_debug_commands(
    'p' => {
        help    => "Pause or unpause",
        command => sub {
            TAEB->paused(! TAEB->paused);
            TAEB->redraw;
        },
    },
    'd' => {
        help    => 'Change debug draw mode',
        command => sub {
            TAEB->display->change_draw_mode;
        },
    },
    'i' => {
        help    => "Display TAEB's inventory",
        command => sub {
            my @menu_items;

            if (TAEB->senses->gold) {
                push @menu_items, TAEB::Display::Menu::Item->new(
                    user_data => TAEB->senses,
                    title     => '$' . TAEB->senses->gold,
                    selector  => '$',
                );
            }

            for my $item (TAEB->inventory_items) {
                push @menu_items, TAEB::Display::Menu::Item->new(
                    user_data => $item,
                    title     => $item->debug_line,
                    selector  => $item->slot,
                );
            }

            item_menu(
                'Inventory (' . TAEB->inventory->weight . ' hzm)',
                \@menu_items,
            );
        },
    },
    'Z' => {
        help    => "Display TAEB's spells",
        command => sub {
            my @menu_items;

            for my $spell (TAEB->spells->spells) {
                push @menu_items, TAEB::Display::Menu::Item->new(
                    user_data => $spell,
                    title     => $spell->debug_line_noslot,
                    selector  => $spell->slot,
                );
            }

            item_menu(
                "TAEB's spells",
                \@menu_items,
            );
        },
    },
    'a' => {
        help     => "Display actions",
        command  => sub {
            my @menu_items;
            for my $action (reverse TAEB->_old_actions) {
                push @menu_items, TAEB::Display::Menu::Item->new(
                    user_data => $action,
                    title     => $action->debug_line,
                );
            }

            item_menu(
                "Previous actions",
                \@menu_items,
            );
        },
    },
    'A' => {
        help     => "Display actions (excluding Move)",
        command  => sub {
            my @menu_items;
            for my $action (reverse TAEB->_old_actions) {
                # we don't use isa here because we want to capture subclasses etc
                next if $action->name eq 'Move';

                push @menu_items, TAEB::Display::Menu::Item->new(
                    user_data => $action,
                    title     => $action->debug_line,
                );
            }

            item_menu(
                "Previous actions (excluding Move)",
                \@menu_items,
            );
        },
    },
    "\cP" => {
        help     => "Display old messages",
        selector => '^P',
        command  => sub {
            item_menu(
                "Old messages",
                [ reverse TAEB->scraper->old_messages ],
                { select_type => 'none' },
            );
        },
    },
    "\cX" => {
        help     => "Display senses (TAEB's character stats)",
        selector => '^X',
        command  => sub {
            item_menu("Senses", TAEB->senses);
        },
    },
    "e" => {
        help    => "Display TAEB's equipment",
        command => sub {
            my $equipment = TAEB->equipment;
            my @menu_items;

            for my $slot ($equipment->slots) {
                my $item = $equipment->$slot;
                my $title = "$slot: " . ($item ? $item->debug_line : "(none)");

                my $menu_item = TAEB::Display::Menu::Item->new(
                    title     => $title,
                    user_data => $item,
                    ($item ? (selector => $item->slot) : ()),
                );

                # put slots with items at the top, empty slots at the bottom
                if ($item) {
                    unshift @menu_items, $menu_item;
                }
                else {
                    push @menu_items, $menu_item;
                }
            }

            item_menu("Equipment", \@menu_items);
        },
    },
    "E" => {
        help    => "Display TAEB's skills (#enhance)",
        command => sub {
            item_menu("Skill levels", TAEB->senses->skill_levels);
        },
    },
    "I" => {
        help    => "Display item spoilers",
        command => sub {
            my $item = item_menu(
                "Item spoiler data",
                [ sort NetHack::Item::Spoiler->all_identities ],
                { no_recurse => 1 },
            ) or return;

            my $spoiler = NetHack::Item::Spoiler->spoiler_for($item);
            item_menu("Spoiler data for $item", $spoiler);
        },
    },
    "M" => {
        help    => "Display monster spoilers",
        command => sub {
            my $monster = item_menu(
                "Monster spoiler data",
                [ sort map { $_->name } NetHack::Monster::Spoiler->list ],
                { no_recurse => 1 },
            ) or return;

            my @spoilers = NetHack::Monster::Spoiler->lookup($monster);
            item_menu("Spoiler data for $monster",
                    @spoilers > 1 ? \@spoilers : $spoilers[0]);
        },
    },
    "t" => {
        help    => "Display map tile information by tile type",
        command => sub {
            my @types = (
                grep { !TAEB->current_level->is_unregisterable($_) }
                sort { $a cmp $b }
                tile_types(),
            );

            my $type = item_menu(
                "Select a tile type",
                \@types,
                { no_recurse => 1 },
            );

            my @tiles = map { $_->level->debug_line . ': ' . $_->debug_line }
                        TAEB->dungeon->tiles_of_type($type);

            item_menu("Tiles of type $type", \@tiles);
        },
    },
    "\e" => {
        help     => "Echo next keystroke directly to NetHack (for emergencies only)",
        selector => "\\e",
        command  => sub {
            TAEB->write(TAEB->get_key);
        },
    },
    "r" => {
        help    => "Redraw the screen",
        command => sub {
            TAEB->redraw(force_clear => 1);
        },
    },
    "\cr" => sub { TAEB->redraw(force_clear => 1) },
    "q" => {
        help    => "Controlled save and exit",
        command => sub {
            if (TAEB->state eq 'playing') {
                TAEB->action(TAEB::Action::Save->new);
                TAEB->state('human_override');
                TAEB->paused(0);
            }
        },
    },
    "Q" => {
        help    => "Controlled quit and exit",
        command => sub {
            if (TAEB->state eq 'playing') {
                TAEB->action(TAEB::Action::Quit->new);
                TAEB->state('human_override');
                TAEB->paused(0);
            }
        },
    },
    "?" => {
        help    => "List TAEB's debug commands",
        command => sub {
            my @commands;
            for my $key (sort { lc($a) cmp lc($b) } keys %debug_commands) {
                my $command = $debug_commands{$key};
                next unless ref($command) eq 'HASH';

                push @commands, TAEB::Display::Menu::Item->new(
                    title    => $command->{help},
                    selector => $command->{selector} || $key,
                );
            }

            item_menu(
                "TAEB's debug commands",
                \@commands,
                { select_type => 'none' },
            );
        },
    },
    " " => sub { }, # no-op
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DESCRIPTION

TAEB is a framework for programmatically playing NetHack
(L<http://nethack.org>). This framework is useful for, among other things,
writing autonomous NetHack bots, or providing unconventional interfaces to
NetHack for humans.

Once installed, run the F<taeb> script to run L<TAEB::AI::Demo>. This
simplistic AI is provided so that TAEB does something out of the box, and for
didactic purposes. You should select a more robust TAEB AI (such as
L<TAEB::AI::Behavioral>) to run.

=head1 CODE

TAEB is versioned using C<git>. You can get a checkout of the code with:

    git clone git://github.com/TAEB/TAEB.git

=head1 SITE

    http://taeb.github.io

=head1 CONTRIBUTORS

TAEB has also had features, fixes, and improvements from:

=over 4

=item Sebbe

=item arcanehl

=item sawtooth

=item Jerub

=item ais523

=item dho

=item futilius

=item bd

=item Zaba

=item toft

=item HanClinto

=back

=cut

