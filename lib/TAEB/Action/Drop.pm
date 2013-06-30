package TAEB::Action::Drop;
use Moose;
use TAEB::OO;
use TAEB::Util 'refaddr';
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item';

use constant command => "D";

has items => (
    is       => 'ro',
    isa      => 'ArrayRef[NetHack::Item]',
    provided => 1,
);

subscribe query_dropitems => sub {
    my $self = shift;
    my $event = shift;

    my %drop;
    for my $item (@{ $self->items }) {
        $drop{refaddr $item} = $item;
    }

    for my $menu_item ($event->all_menu_items) {
        my $item = $menu_item->user_data;
        if ($drop{refaddr $item}) {
            $menu_item->selected(1);
            $menu_item->selected_quantity('all');
            delete $drop{refaddr $item};
        }
    }

    TAEB->log->inventory("Tried to drop item I don't have: $_")
        for values %drop;
};

__PACKAGE__->meta->make_immutable;

1;

