package TAEB::Announcement::Query::DropItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with 'TAEB::Announcement::Role::SelectSubset';

has desired_items => (
    is       => 'ro',
    isa      => 'ArrayRef[NetHack::Item]',
    required => 1,
);

sub BUILD {
    my $self = shift;
    my %inventory = map { $_->slot => $_ } TAEB->inventory_items;
    my %menu_items = map { $_->selector => $_ } $self->all_menu_items;

    for my $slot (keys %inventory) {
        my $item = $inventory{$slot};

        if (exists($menu_items{$slot})) {
            $menu_items{$slot}->user_data($inventory{$slot});
            delete $inventory{$slot};
            delete $menu_items{$slot};
        }
    }

    TAEB->log->inventory("Inventory out of sync: inventory item $_ is not in the menu") for values %inventory;
    TAEB->log->inventory("Inventory out of sync: menu item $_ is not in inventory") for values %menu_items;
}

__PACKAGE__->meta->make_immutable;

1;

