package TAEB::Display::Menu;
use Moose;
use TAEB::OO;

has description => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has _item_metadata => (
    is  => 'ro',
    isa => 'ArrayRef',
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
    $args{_item_metadata} = [ map { [$_] } @{ delete $args{items} } ];

    return \%args;
}

sub item {
    my $self = shift;
    my $index = shift;

    return $self->_item_metadata->[$index][0];
}

sub items {
    my $self = shift;

    return map { $_->[0] } @{ $self->_item_metadata };
}

sub select { ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;

    return if $self->select_type eq 'none';

    for my $index (@_) {
        $self->_item_metadata->[$index][1] ^= 1;
    }
}

sub is_selected {
    my $self  = shift;
    my $index = shift;

    return $self->_item_metadata->[$index][1];
}

sub selected {
    my $self  = shift;

    my @selected = map { $_->[0] }
                   grep { $_->[1] }
                   @{ $self->_item_metadata };

    return $selected[0] if $self->select_type eq 'single';
    return @selected;
}

sub clear_selections {
    my $self = shift;

    return if $self->select_type eq 'none';

    for my $index (0 .. @{ $self->_item_metadata } - 1) {
        $self->_item_metadata->[$index][1] = 0;
    }
}

around _item_metadata => sub {
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

    return [ grep { $_->[0] =~ $compiled } @{ $orig->($self) } ];
};

__PACKAGE__->meta->make_immutable;

1;

