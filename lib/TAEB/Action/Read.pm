package TAEB::Action::Read;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item';

use constant command => "r";

has '+item' => (
    required => 1,
);

has charge => (
    is       => 'ro',
    isa      => 'NetHack::Item',
    provided => 1,
);

has did_charge => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub respond_read_what { shift->item->slot }

sub respond_charge_what { shift->charge->slot }

sub msg_charging_scroll { shift->did_charge(1) }

sub msg_will_respond_difficult_spell {
    my $item = shift->item;
    $item->difficult_for_level(TAEB->level);
    $item->difficult_for_int(TAEB->senses->int);
    $item->is_uncursed(1);
}

sub done {
    my $self = shift;
    my $item = $self->item;

    if ($item->match(type => 'scroll')) {
        TAEB->inventory->decrease_quantity($item->slot)
    }
}

sub msg_learned_spell {
    my $self = shift;
    my $name = shift;

    $self->item->tracker->identify_as("spellbook of $name")
        if $self->item->has_tracker;
}

sub msg_knew_spell {
    my $self = shift;
    my $name = shift;

    $self->item->tracker->identify_as("spellbook of $name")
        if $self->item->has_tracker;

    TAEB->log->spell("Read spellbook of $name even though we knew the spell.");
}

sub can_read {
    my $self = shift;
    my $item = shift;

    return 0 unless $item->match(type => [qw/scroll spellbook/]);
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;

