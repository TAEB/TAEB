package TAEB::Display::Menu::Item;
use Moose;
use TAEB::OO;

has user_data => (
    is  => 'ro',
    isa => 'Any',
);

has title => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has selector => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_selector',
);

has selected => (
    is      => 'rw',
    isa     => 'Str',
    default => 0,
);

sub toggle_selected {
    my $self = shift;
    $self->selected(!$self->selected);
}

__PACKAGE__->meta->make_immutable;

1;

