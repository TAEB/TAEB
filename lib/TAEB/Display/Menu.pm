package TAEB::Display::Menu;
use Moose;
use TAEB::OO;
use TAEB::Display::Menu::Item;

has description => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has items => (
    traits  => ['Array'],
    isa     => 'ArrayRef[TAEB::Display::Menu::Item]',
    handles => {
        items => 'elements',
    },
);

has select_type => (
    is      => 'ro',
    isa     => 'TAEB::Type::Menu',
    default => 'none',
);

has search => (
    is        => 'rw',
    isa       => 'Str',
    clearer   => 'clear_search',
    predicate => 'has_search',
);

sub BUILDARGS {
    my $self = shift;
    my %args = @_;

    die "Attribute (items) is required and must be an array reference"
        unless $args{items} && ref($args{items}) eq 'ARRAY';

    my @new_items;
    for my $raw_item (@{ delete $args{items} }) {
        if (blessed($raw_item) && $raw_item->isa('TAEB::Display::Menu::Item')) {
            push @new_items, $raw_item;
        }
        elsif (!ref($raw_item)) {
            push @new_items, TAEB::Display::Menu::Item->new(
                user_data => $raw_item,
                title     => $raw_item,
            );
        }
        else {
            push @new_items, TAEB::Display::Menu::Item->new(
                user_data => $raw_item,
                title     => "$raw_item",
            );
        }
    }

    $args{items} = \@new_items;

    return \%args;
}

sub select {
    my $self = shift;

    return if $self->select_type eq 'none';

    for my $index (@_) {
        my $item = blessed($index) ? $index : $self->item($index);
        $item->toggle_selected;
    }
}

sub selected {
    my $self  = shift;

    my @selected = grep { $_->selected } $self->items;

    return $selected[0] if $self->select_type eq 'single';
    return @selected;
}

sub clear_selections {
    my $self = shift;

    return if $self->select_type eq 'none';

    for my $item (grep { defined } $self->selected) {
        $item->selected(0);
    }
}

around items => sub {
    my $orig = shift;
    my $self = shift;

    return $orig->($self, @_) if @_ || !$self->has_search;

    my $search = $self->search;

    # chop so if the user begins typing a (..) we don't kick them back out to
    # all unfiltered results
    my $compiled;
    while (1) {
        eval { local @SIG{'__DIE__', '__WARN__'}; $compiled = qr/$search/ }
            and last;
        chop $search;
    }

    # case insensitive until they type a capital letter
    # this has to happen after we chop because chopping (?i:...) is not likely
    # to work
    $compiled = qr/$search/i unless $search =~ /[A-Z]/;

    my @all_items = $orig->($self);
    return grep { $_->title =~ $compiled } @all_items;
};

# can't use the native delegation since it breaks searching
sub item {
    my $self = shift;
    my $index = shift;

    my @items = $self->items;

    return $items[$index];
}

__PACKAGE__->meta->make_immutable;

1;

