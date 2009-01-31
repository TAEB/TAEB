#!/usr/bin/env perl
package TAEB::AI;
use TAEB::OO;

has currently => (
    isa => 'Str',
    default => "?",
    trigger => sub {
        my ($self, $currently) = @_;
        TAEB->log->ai("Currently: $currently.") unless $currently eq '?';
    },
);

=head1 NAME

TAEB::AI - how TAEB tactically extracts its amulets

=head2 next_action -> Action

This is the method called by the main TAEB code to get individual commands. It
will be called with a C<$self> which will be your TAEB::AI object,
and a TAEB object for interacting with the rest of the system (such as for
looking at the map).

It should return the L<TAEB::Action> object to send to NetHack.

Your subclass B<must> override this method.

=cut

sub next_action {
    my $class = blessed($_[0]) || $_[0];
    die "You must override the 'next_action' method in $class.";
}

=head2 institute

This is the method called when TAEB begins using this AI. This is
guaranteed to be called before any calls to next_action.

=cut

sub institute {
    TAEB->publisher->subscribe(shift);
}

=head2 deinstitute

This is the method called when TAEB finishes using this AI.

This will not be called when TAEB is ending, but only when the AI is
replaced by a different one.

=cut

sub deinstitute {
    TAEB->publisher->unsubscribe(shift);
}

=head2 want_item Item -> Bool or Ref[Int]

Does TAEB want this item?

=cut

sub want_item {
    my $self = shift;

    $self->pickup(@_);
}

=head2 pickup Item -> Bool or Ref[Int]

Will TAEB pick up this item? Not by default, no.

=cut

sub pickup { 0 }

=head2 drop Item -> Bool

Will TAEB drop this item? Not by default, no.

=cut

sub drop { 0 }

=head2 msg_powerup Str, *

Received when we've got a powerup-like message. Currently handles C<enhance>.

=cut

sub msg_powerup {
    my $self = shift;
    my $type = shift;

    if ($type eq 'enhance') {
        return "#enhance\n";
    }
}

=head2 enhance Str, Str -> Bool

Callback for enhancing. Receives skill type and current level. Returns whether
we should enhance it or not. Default: YES.

=cut

sub enhance {
    my $self  = shift;
    my $skill = shift;
    my $level = shift;

    TAEB->log->ai("Enhancing $skill up from $level");

    return 1;
}

sub respond_really_attack { "y" }
sub respond_name          { "\n" }
sub respond_save_file     { "n" }
sub respond_vault_guard   { TAEB->name."\n" }
sub respond_advance_without_practice { "n" }
sub respond_dump_core { "n" }
sub respond_die { "n" }

sub respond_wish {
    # We all know how much TAEB loves Elbereth. Let's give it Elbereth's best buddy.
    return "blessed fixed +3 Magicbane\n" unless TAEB->knowledge->artifacts->was_seen("Magicbane");

    # Half physical damage? Don't mind if I do! (Now with added grease for Eidolos!)
    return "blessed fixed greased Master Key of Thievery\n"
        if TAEB->align eq 'Cha'
        && !TAEB->knowledge->artifacts->was_seen('Master Key of Thievery');

    # We can always use more AC.
    return "blessed fixed greased +3 dwarvish mithril-coat\n" unless TAEB->find_item(qr/mithril/);

    # Healing sounds good, too.
    return "2 blessed potions of full healing\n" if TAEB->knowledge->appearance_of->{"potion of full healing"};

    # Curing status effects sounds good, too.
    return "blessed fixed greased +3 unicorn horn" unless TAEB->find_item('unicorn horn');

    # When in doubt, ask for more shit to throw at people.
    return "3 blessed fixed +3 silver daggers";
}

sub select_enhance {
    my $self = shift;
    my ($skill, $level) = /^\s*(.*?)\s*\[(.*)\]/
        or warn "Unable to parse $_ as an #enhance item.";
    $self->enhance($skill, $level);
}

sub select_identify {
    my $self = shift;
    my $item = shift;

    # only identify stuff we don't know about, that's not cursed.
    return $item->match(identity => undef, '!buc' => 'cursed');
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
