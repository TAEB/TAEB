package TAEB::Announcement::Query::PickupItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Query';
with 'TAEB::Announcement::Role::SelectSubset';

sub BUILD {}
after BUILD => sub {
    my $self = shift;
    my @expected = TAEB->current_tile->items;
    my @menu_items = $self->all_menu_items;

    # XXX reconcile @expected and @menu_items
};

__PACKAGE__->meta->make_immutable;

1;

