package TAEB::Action::Dip;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item' => { items => [qw/item into/] };

use constant command => "#dip\n";

has '+item' => (
    required => 1,
);

has '+into' => (
    isa     => 'NetHack::Item | Str',
    default => 'fountain',
);

has dipped_into_item => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub respond_dip_what {
    my $self = shift;
    $self->current_item($self->item);
    return $self->item->slot;
}

sub respond_dip_into_water {
    my $self  = shift;
    my $item  = shift;
    my $water = shift;

    # fountains are very much a special case - if water we want moat, pool, etc
    return 'y' if $self->into eq 'water' && $water ne 'fountain';

    return 'y' if $self->into eq $water;

    return 'n';
}

sub respond_dip_into_what {
    my $self = shift;
    $self->current_item($self->into);
    if (blessed($self->into)) {
        $self->dipped_into_item(1);
        return $self->into->slot;
    }

    TAEB->log->action("Unable to dip into '" . $self->into . "'. Sending escape, but I doubt this will work.", level => 'error');
    return "\e";
}

subscribe excalibur => sub {
    my $self = shift;
    my $excalibur = $self->item;

    $excalibur->buc('blessed');
    $excalibur->proof;
    $excalibur->remove_damage;
    $excalibur->specific_name('Excalibur');
};

sub done {
    my $self = shift;

    if ($self->dipped_into_item) {
        TAEB->inventory->decrease_quantity($self->into->slot);
    }
}

subscribe got_item => sub {
    my $self = shift;
    my $event = shift;

    my $new_item = $event->item;

    return unless $self->dipped_into_item;

    my $into_item = $self->into;
    my $identity = $into_item->identity
        or return;

    my $dipped_item = $self->item;

    if ($identity eq 'potion of polymorph') {
        $new_item->did_polymorph_from($dipped_item);
    }
};

sub msg_blessed {
    my $self = shift;
    $self->item->is_blessed(1);
}

sub msg_diluted {
    my $self = shift;
    $self->item->did_dilute_partially;
}

sub msg_diluted_completely {
    my $self = shift;
    $self->item->did_dilute_into_water;
}

__PACKAGE__->meta->make_immutable;

1;

