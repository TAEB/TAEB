package TAEB::Announcement::Role::HasMenu;
use Moose::Role;

has menu => (
    is       => 'ro',
    isa      => 'NetHack::Menu',
    required => 1,
);

has items => (
    traits     => ['Array'],
    isa        => 'ArrayRef',
    builder    => '_build_items',
    handles    => {
        items      => 'elements',
        item_count => 'count',
        item       => 'get',
    },
);

sub _build_items {
    my $self = shift;

    my @items;
    my $index = 0;

    $self->menu->select(sub {
        my $selector = shift;
        my $item = $_;

        push @{ $params->{items} }, {
            selector => $selector,
            item     => $item,
            index    => $index,
        };

        $index++;
        return 0;
    });

    return \@items;
}

no Moose::Role;

1;

