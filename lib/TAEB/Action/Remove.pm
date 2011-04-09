package TAEB::Action::Remove;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item';

has '+item' => (
    required => 1,
);

sub command {
    my $self = shift;
    my $item = $self->item;

    return 'T' if $item->type eq 'armor';
    return 'R';
}

sub respond_remove_what { shift->item->slot }

sub done {
    my $self = shift;
    $self->item->is_worn(0);
    $self->item->is_cursed(0);
}

sub msg_cursed {
    my $self = shift;
    $self->item->buc('cursed');
    $self->aborted(1);
}

sub exception_not_wearing {
    my $self = shift;

    $self->item->is_worn(0);

    my $slot;
    $slot = $self->item->subtype if $self->item->type eq 'armor';
    if (defined ($slot)) {
        my $clearer = "clear_$slot";
        TAEB->equipment->$clearer;
    }

    TAEB->log->action("We are not wearing item " . $self->item);
    $self->aborted(1);
    return "\e";
}

__PACKAGE__->meta->make_immutable;

1;

