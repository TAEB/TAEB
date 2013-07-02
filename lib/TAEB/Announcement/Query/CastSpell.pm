package TAEB::Announcement::Query::CastSpell;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with 'TAEB::Announcement::Role::SelectSingle';

sub BUILD {}
after BUILD => sub {
    my $self = shift;
    my %expected = map { $_->slot => $_ } TAEB->spells->spells;
    my %menu_items = map { $_->selector => $_ } $self->all_menu_items;

    for my $slot (keys %expected) {
        my $spell = $expected{$slot};

        if (exists($menu_items{$slot})) {
            $menu_items{$slot}->user_data($spell);
            delete $expected{$slot};
            delete $menu_items{$slot};
        }
    }

    TAEB->log->scraper("Out of sync: expected spell $_ is not in the menu") for values %expected;
    TAEB->log->scraper("Out of sync: menu spell $_ is missing") for values %menu_items;
};

__PACKAGE__->meta->make_immutable;

1;

