package TAEB::Action::Apply;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with (
    'TAEB::Action::Role::Direction',
    'TAEB::Action::Role::Item',
);

use constant command => "a";

has '+item' => (
    required => 1,
);

sub respond_apply_what { shift->item->slot }

subscribe nothing_happens => sub {
    my $self = shift;
    my $item = $self->item;

    # nothing happens is good! we know we don't have these status effects
    if ($item->match(identity => 'unicorn horn')) {
        for (qw/blindness confusion stunning hallucination/) {
            TAEB->send_message(status_change => $_ => 0);
        }
    }
};

sub msg_status_change {
    my $self = shift;
    my $status = shift;
    my $have = shift;

    # we lost the effect, so we don't care
    return if !$have;

    my $item = $self->item;
    if ($item->identity eq 'unicorn horn') {
        TAEB->log->action("We seem to have gained the '$status' effect and we rubbed $item this turn. Marking it as cursed.");
        $item->buc("cursed");
    }
}

sub msg_negative_stethoscope {
    my $self = shift;

    $self->target_tile->inc_searched(50); # should be infinity
}

sub msg_lamp_on {
    my $self = shift;
    my $item = $self->item;

    if ($item->can('is_lit')) {
        $item->is_lit(1);
    }
}

sub msg_lamp_off {
    my $self = shift;
    my $item = $self->item;

    if ($item->can('is_lit')) {
        $item->is_lit(0);
    }
}

# falling into a pit makes the new level the same branch as the old level
# this can trigger when applying a pickaxe downward
subscribe trapdoor => sub {
    my $self  = shift;
    my $event = shift;

    TAEB->current_level->branch($self->starting_tile->branch)
        if $self->starting_tile->known_branch;
};

__PACKAGE__->meta->make_immutable;

1;

