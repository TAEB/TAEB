package TAEB::Action::Drop;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item';

use constant command => "Da\n";

has items => (
    is  => 'ro',
    isa => 'ArrayRef',
    provided => 1,
);

# logic is elsewhere sadly

sub msg_ring {
    my $self     = shift;
    my $identity = shift;

    return unless @{ $self->items } == 1;
    my $item = $self->items->[0];
    TAEB->log->action("Identified ".$item->appearance." as $identity");
    $self->identify_as($identity);
}

__PACKAGE__->meta->make_immutable;

1;

