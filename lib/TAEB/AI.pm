package TAEB::AI;
use Moose;
use TAEB::OO;

use constant is_human_controlled => 0;

sub next_action { confess shift . " must implement ->next_action" }

sub institute {
    TAEB->publisher->subscribe(shift);
}

sub deinstitute {
    TAEB->publisher->unsubscribe(shift);
}

has currently => (
    is      => 'rw',
    isa     => 'Str',
    default => "?",
    trigger => sub {
        my ($self, $currently) = @_;
        TAEB->log->ai("Currently: $currently.") unless $currently eq '?';
    },
);

sub respond_really_attack { "y" }
sub respond_name          { "\n" }
sub respond_save_file     { "n" }
sub respond_vault_guard   { TAEB->name."\n" }
sub respond_advance_without_practice { "n" }
sub respond_continue_lifting { "y" }

sub respond_wish {
    # We all know how much TAEB loves Elbereth. Let's give it Elbereth's best buddy.
    return "blessed fixed +3 Magicbane\n"
        unless TAEB->seen_artifact("Magicbane");

    # Half physical damage? Don't mind if I do! (Now with added grease for Eidolos!)
    return "blessed fixed greased Master Key of Thievery\n"
        if TAEB->align eq 'Cha'
        && !TAEB->role eq 'Rog'
        && !TAEB->seen_artifact('Master Key of Thievery');

    return "blessed fixed greased +3 silver dragon scale mail"
        unless TAEB->has_item(qr/silver dragon scale mail/)
            || TAEB->role eq 'Mon';

    # Healing sounds good, too.
    return "2 blessed potions of full healing\n"
        if TAEB->has_identified("potion of full healing");

    # Curing status effects sounds good, too.
    return "blessed fixed greased +3 unicorn horn"
        unless TAEB->has_item('unicorn horn');

    # When in doubt, ask for more shit to throw at people.
    return "3 blessed fixed +3 silver daggers";
}

sub select_identify {
    my $self = shift;
    my $item = shift;

    # only identify stuff we don't know about, that's not cursed.
    return $item->match(identity => undef, '!buc' => 'cursed');
}

sub drawing_modes {}

sub botl_modes {}

sub map_commands {}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::AI - how TAEB tactically extracts its amulets

=head2 next_action -> Action

This is the method called by the main TAEB code to get individual commands. It
will be called with a C<$self> which will be your TAEB::AI object,
and a TAEB object for interacting with the rest of the system (such as for
looking at the map).

It should return the L<TAEB::Action> object to send to NetHack.

Your subclass B<must> override this method.

=head2 institute

This is the method called when TAEB begins using this AI. This is
guaranteed to be called before any calls to next_action.

=head2 deinstitute

This is the method called when TAEB finishes using this AI.

This will not be called when TAEB is ending, but only when the AI is
replaced by a different one.

=head2 enhance Str, Str -> Bool

Callback for enhancing. Receives skill type and current level. Returns whether
we should enhance it or not. Default: YES.

=head2 currently

A string that states what the AI is currently doing.

=head2 drawing_modes

Hook for AI-specific drawing modes. Example:

    use TAEB::Util::Colors;
    
    sub drawing_modes {
        white => {
            description => "All white",
            color => sub { COLOR_WHITE },
        },
        rot13 => {
            description => "Rot-13",
            glyph => sub {
                local $_ = shift->normal_glyph;
                tr/A-Za-z/M-ZA-Lm-za-l/;
                $_
            },
        },
    }

Also available are 'immediate', which is run by the select menu,
and 'onframe', which is run before each colorized frame.

=head2 map_commands

Hook for the ';'-mode; example:

    sub map_commands {
        g => sub {
            my $map = shift; # a TAEB::Debug::Map object
            TAEB->ai->set_goal($map->tile);
            $map->topline("Goal set.");
            0; # or 1 to force a redraw, or undef to exit ;-mode
        };
    }

=cut

