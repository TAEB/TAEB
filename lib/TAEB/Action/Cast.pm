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
    my $spell = shift->spell;

    $spell->did_cast;

    # detect food doesn't make us hungry
    return if $spell->name eq 'detect food';

    my $nutrition = TAEB->nutrition;

    # in the future, let's check to see how much we actually spent (Amulet of
    # Yendor)
    my $energy = 5 * $spell->power;
    my $hunger = 2 * $energy;

    if (TAEB->role eq 'Wiz') {
           if (TAEB->int >= 17) { $hunger = 0 }
        elsif (TAEB->int == 16) { $hunger = int($hunger / 4) }
        elsif (TAEB->int == 15) { $hunger = int($hunger / 2) }
    }

    if ($hunger > $nutrition - 3) {
        $hunger = $nutrition - 3;
    }

    TAEB->nutrition($nutrition - $hunger);
}

__PACKAGE__->meta->make_immutable;

1;

