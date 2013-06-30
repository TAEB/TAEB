package TAEB::Announcement::Role::ItemMenu;
use Moose::Role;

requires 'items_from', 'all_menu_items';

sub BUILD {}
after BUILD => sub {
    my $self = shift;
    my %expected = map { $_->slot => $_ } $self->items_from;
    my %menu_items = map { $_->selector => $_ } $self->all_menu_items;

    for my $slot (keys %expected) {
        my $item = $expected{$slot};

        if (exists($menu_items{$slot})) {
            $menu_items{$slot}->user_data($expected{$slot});
            delete $expected{$slot};
            delete $menu_items{$slot};
        }
    }

    TAEB->log->scraper("Out of sync: expected item $_ is not in the menu") for values %expected;
    TAEB->log->scraper("Out of sync: menu item $_ is missing") for values %menu_items;
};

1;

