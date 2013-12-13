package TAEB::Action::Engrave;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item' => { items => [qw/engraver/] };

use constant command => 'E';

has '+engraver' => (
    isa     => 'NetHack::Item | Str',
    default => '-',
);

has '+current_item' => (
    isa => 'NetHack::Item | Str',
);

has text => (
    is       => 'ro',
    isa      => 'Str',
    default  => 'Elbereth',
    provided => 1,
);

has add_engraving => (
    is       => 'ro',
    isa      => 'Bool',
    default  => 1,
    provided => 1,
);

has got_identifying_message => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub engrave_slot {
    my $self = shift;
    my $engraver = $self->engraver;

    return $engraver->slot if blessed $engraver;
    return $engraver;
}

sub respond_write_with    { shift->engrave_slot }
sub respond_write_what    { shift->text . "\n" }
sub respond_add_engraving { shift->add_engraving ? 'y' : 'n' }

sub msg_will_respond_wish {
    my $self = shift;
    TAEB->log->debug("Engrave netted us a wish... :)");
    if ($self->engraver->match(type => 'wand')) {
        $self->engraver->tracker->identify_as('wand of wishing');
        $self->got_identifying_message(1);
    }
}

sub msg_wand {
    my $self = shift;
    $self->got_identifying_message(1);
    $self->engraver->tracker->rule_out_all_but(@_);
}

sub done {
    my $self = shift;
    TAEB->current_tile->engraving(TAEB->current_tile->engraving . $self->text);
    TAEB->current_tile->player_engraving(1);
    return unless blessed $self->engraver;

    if ($self->engraver->match(type => 'wand')) {
        $self->engraver->spend_charge;
    }
    elsif ($self->engraver->match(identity => 'magic marker')) {
        $self->engraver->spend_charge(int(length($self->text) / 2));
    }

    return if $self->got_identifying_message;
    return if $self->engraver->identity; # perhaps we identified it?
    $self->engraver->tracker->no_engrave_message
        if $self->engraver->has_tracker;
}

sub is_impossible {
    return TAEB->is_polymorphed
        || TAEB->is_engulfed
        || !TAEB->current_tile->is_engravable;
}

sub is_advisable {
    my $self = shift;
    return not ($self->is_impossible
             || TAEB->is_blind
             || TAEB->is_confused
             || TAEB->is_stunned
             || TAEB->is_hallucinating);
}

__PACKAGE__->meta->make_immutable;

1;

