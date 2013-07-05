package TAEB::Action::Cast;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Direction';

use constant command => 'Z';

has spell => (
    is       => 'ro',
    isa      => 'TAEB::World::Spell',
    required => 1,
    provided => 1,
);

subscribe query_castspell => sub {
    my $self = shift;
    my $event = shift;

    my $spell_name = $self->spell->name;

    for my $item ($event->all_menu_items) {
        if ($item->user_data->name eq $spell_name) {
            $item->selected(1);
            return;
        }
    }

    TAEB->log->spells("Spell $spell_name did not appear in menu!", level => "error");
};

sub exception_hunger_cast {
    my $self = shift;

    if (TAEB->nutrition > 10) {
        TAEB->nutrition(10);
        TAEB->log->action("Adjusting our nutrition to 10 because we're too hungry to cast spells");
        $self->aborted(1);
    }
    else {
        TAEB->log->action("Our nutrition is known to be <= 10 and we got a 'too hungry to cast' message. Why did you cast?", level => 'error');
    }

    return "\e\e\e";
}

sub msg_remove_curse {
    my $self = shift;
    return unless $self->spell->name eq 'remove curse';

    my @items;

    my $level = TAEB->senses->level_for_skill('clerical');
    if ($level eq 'Skilled' || $level eq 'Expert') {
        @items = TAEB->inventory_items;
    }
    else {
        my $eq = TAEB->equipment;
        @items = grep { defined } (
            $eq->weapon,
            $eq->offhand,
            $eq->helmet,
            $eq->gloves,
            $eq->boots,
            $eq->bodyarmor,
            $eq->cloak,
            $eq->shirt,
            $eq->shield,
            $eq->left_ring,
            $eq->right_ring,
            $eq->amulet,
            $eq->blindfold,
        );
    }

    for my $item (@items) {
        if ($item->is_cursed) {
            $item->is_uncursed(1);
        }
        elsif (!defined($item->buc)) {
            $item->is_cursed(0);
        }
    }
}

sub done {
    my $self = shift;

    my $spell = $self->spell;

    $spell->did_cast;

    my $nutrition = $spell->nutrition;
    TAEB->nutrition(TAEB->nutrition - $nutrition);

    # force bolt might bust some items up
    if ($spell->name eq 'force bolt' && $self->direction eq '>') {
        TAEB->send_message(check => 'floor');
    }
}

__PACKAGE__->meta->make_immutable;

1;

