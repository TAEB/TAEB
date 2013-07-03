package TAEB::Announcement::Query::DropItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with 'TAEB::Announcement::Role::SelectSubset';

sub BUILD {}
after BUILD => sub {
    my $self = shift;
    my %missing_slots = map { $_->slot => $_ } TAEB->inventory_items;

    for my $item ($self->all_menu_items) {
        my $slot = $menu_item->selector;
        my $new_item = TAEB->new_item($menu_item->description);

        TAEB->inventory->update($slot => $new_item);
        $menu_item->user_data(TAEB->inventory->get($slot));
        delete $missing_slots{$slot};
    }

    for my $slot (keys %missing_slots) {
        my $item = $missing_slots{$slot};
        TAEB->log->scraper("Expected inventory item in slot $slot missing! Was $item");
    }

    TAEB->clear_checking if TAEB->is_checking('inventory');
};

__PACKAGE__->meta->make_immutable;

1;

