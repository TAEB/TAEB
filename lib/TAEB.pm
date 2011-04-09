package TAEB;
use 5.008001;
use TAEB::Util qw/:colors tile_types item_menu/;

use Moose;
use TAEB::OO;

use Log::Dispatch::Null;
use Try::Tiny;

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

our $VERSION = '0.05';

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
    handles   => [qw(want_item currently)],
    predicate => 'has_ai',
    writer    => 'set_ai', # for efficiency when TAEB->ai is in the inner loop
    lazy      => 1,
    default   => sub {
        my $ai = TAEB->config->get_ai_class->new;
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
    handles => [qw/announce send_message get_exceptional_response get_response get_location_request remove_messages menu_select single_select/],
);

class_has action => (
    is        => 'rw',
    isa       => 'TAEB::Action',
    predicate => 'has_action',
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

            my $level = $message =~ /^Interrupted\./
                      ? 'info'
                      : 'error';

            $self->log->perl($message, level => $level);

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
    $self->currently('Performing an action due to manual override');
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
        $self->senses->update($main_call);
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

    # pause for a key
    if ($c eq 'p') {
        $self->paused(! $self->paused);
        $self->redraw;
        return;
    }

    if ($c eq 'd') {
        $self->display->change_draw_mode;
        return;
    }

    if ($c eq 'i') {
        item_menu('Inventory (' . $self->inventory->weight . ' hzm)',
                  [$self->inventory]);
        return;
    }

    if ($c eq "\cP") {
        my $menu = TAEB::Display::Menu->new(
            description => "Old messages",
            items       => [ reverse $self->scraper->old_messages ],
        );
        $self->display_menu($menu);

        return;
    }

    if ($c eq "\cX") {
        item_menu("Senses", $self->senses);
        return;
    }

    if ($c eq 'e') {
        my $eq = $self->equipment;
        my @eq = (
            map { "$_: " . ($eq->$_ ? $eq->$_->debug_line : "(none)") }
            sort { ($eq->$b ? 1 : 0) <=> ($eq->$a ? 1 : 0) }
            $eq->slots
        );

        item_menu("Equipment", \@eq);
        return;
    }

    if ($c eq 'I') {
        my $menu = TAEB::Display::Menu->new(
            description => "Item spoiler data",
            items       => [ sort NetHack::Item::Spoiler->all_identities ],
            select_type => 'single',
        );
        my $item = $self->display_menu($menu)
            or return;

        my $spoiler = NetHack::Item::Spoiler->spoiler_for($item);
        item_menu("Spoiler data for $item", $spoiler);

        return;
    }

    if ($c eq 'M') {
        my $menu = TAEB::Display::Menu->new(
            description => "Monster spoiler data",
            items       => [ sort map { $_->name }
                             NetHack::Monster::Spoiler->list ],
            select_type => 'single',
        );
        my $monster = $self->display_menu($menu)
            or return;

        my @spoilers = NetHack::Monster::Spoiler->lookup($monster);
        item_menu("Spoiler data for $monster",
                  @spoilers > 1 ? \@spoilers : $spoilers[0]);

        return;
    }

    if ($c eq 't') {
        my @types = (
            grep { !$self->current_level->is_unregisterable($_) }
            sort { $a cmp $b }
            tile_types(),
        );

        my $type_menu = TAEB::Display::Menu->new(
            description => "Select a tile type",
            items       => \@types,
            select_type => 'single',
        );

        my $type = $self->display_menu($type_menu)
            or return;

        my @tiles = map { $_->level->debug_line . ': ' . $_->debug_line }
                    map { $_->tiles_of($type) }
                    map { @$_ }
                    @{ $self->dungeon->levels };

        item_menu("Tiles of type $type", \@tiles);

        return;
    }

    # user input (for emergencies only)
    if ($c eq "\e") {
        $self->write($self->get_key);
        return;
    }

    # refresh NetHack's screen
    if ($c eq 'r' || $c eq "\cr") {
        # back to normal
        $self->redraw(force_clear => 1);
        return;
    }

    # Controlled save and exit
    if ($c eq 'q' && $self->state eq 'playing') {
        $self->action(TAEB::Action::Save->new);
        $self->state('human_override');
        $self->paused(0);
        return;
    }

    # Controlled quit and exit
    if ($c eq 'Q' && $self->state eq 'playing') {
        $self->action(TAEB::Action::Quit->new);
        $self->state('human_override');
        $self->paused(0);
        return;
    }

    # space is always a noncommand
    return if $c eq ' ';

    $self->announce(keypress => key => $c);
    return;
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

sub inventory {
    my $self = shift;
    my $inventory = $self->item_pool->inventory;

    return $inventory->items if wantarray;
    return $inventory;
}

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
            my $level = $message =~ /^Interrupted\./
                      ? 'info'
                      : 'error';
            TAEB->log->perl($error, level => $level);
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

    # weaken leaks memory on 5.10, unless we hack around it
    # see also TAEB::Role::WeakenFix
    if ($] == 5.010) {
        my @nhi_classes = qw/NetHack::ItemPool::Tracker
                             NetHack::ItemPool::Trackers/;
        for my $nhi_meta (map { Class::MOP::Class->initialize($_) } @nhi_classes) {
            $nhi_meta->make_mutable;
            $nhi_meta->add_after_method_modifier(
                DEMOLISHALL => sub { %{ $_[0] } = () }
            ) unless $nhi_meta->find_method_by_name('DEMOLISHALL')->isa('Class::MOP::Method::Wrapped');
            $nhi_meta->make_immutable;
        }
    }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB - the Tactical Amulet Extraction Bot (for NetHack)

=head1 DESCRIPTION

TAEB is a framework for programmatically playing NetHack
(L<http://nethack.org>). This framework is useful for, among other things,
writing autonomous NetHack bots, or providing unconventional interfaces to
NetHack for humans.

Once installed, run the F<taeb> script to run L<TAEB::AI::Demo>. This
simplistic AI is provided so that TAEB does something out of the box, and for
didactic purposes. You should select a more robust TAEB AI (such as
L<TAEB::AI::Behavioral>) to run.

=head1 ATTRIBUTES

=over 4

=item interface

An interface for communicating with NetHack

=item ai

An agent that decides what to do each turn

=item scraper

A screen scraper to give meaning to the characters on the virtual terminal

=item config

The user's configuration for each component

=item vt

A virtual terminal that gives us an addressable screen for NetHack's output

=item state

A string representing TAEB's current state (logging_in, playing, or dying)

=item log

A message bus for tracking history for debugging and informational purposes

=item dungeon

The state of the NetHack world; levels and tiles are some of the dungeon's
domain

=item senses

The state of TAEB's character; HP, in_beartrap, and fire_resistant are some
statuses about TAEB's character that senses tracks.

=item spells

The spells that TAEB currently knows

=item publisher

A message bus for communicating information across all of TAEB's components

=item action

The L<TAEB::Action> that was taken or is about to be taken

=item new_game

A boolean indicating whether the current session started a new game or
continued a previously saved game

=item debugger

An object holding a collection of debugging tools such as
L<TAEB::Debug::Console> and L<TAEB::Debug::IRC::Bot>

=item display

An interface to communicate with the human user

=item item_pool

A pool (universe) of NetHack items; the item pool tracks inventory, artifacts,
possibilities for each appearance, and so on.

=back

=head1 CODE

TAEB is versioned using C<git>. You can get a checkout of the code with:

    git clone git://github.com/sartak/TAEB.git

=head1 BLOG

The TAEB authors maintain something resembling a blog of ideas, difficulties,
and progress at:

    http://taeb-nethack.blogspot.com

=head1 AUTHORS

The primary authors of TAEB are:

=over 4

=item Shawn M Moore C<sartak@gmail.com>

=item Jesse Luehrs C<doy@tozt.net>

=item Stefan O'Rear C<stefanor@cox.net>

=back

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

=head1 COPYRIGHT & LICENSE

Copyright 2007-2009 TAEB DevTeam.

This program is free software; you can redistribute it and/or modify it
under terms of the GNU public license version 2.

=cut

