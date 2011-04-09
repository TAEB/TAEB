package TAEB::Action::Rub;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item' => { items => [qw/item against/] };

use constant command => "#rub\n";

has '+item' => (
    required => 1,
);

sub respond_rub_what {
    my $self = shift;
    $self->current_item($self->item);
    return $self->item->slot;
}

sub respond_rub_on_what {
    my $self = shift;
    $self->current_item($self->against);
    return $self->against->slot;
}

__PACKAGE__->meta->make_immutable;

1;

