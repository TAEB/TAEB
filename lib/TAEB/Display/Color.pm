package TAEB::Display::Color;
use Moose;
use Moose::Util::TypeConstraints 'enum';

has index => (
    is      => 'ro',
    isa     => (enum [0..8]),
    default => 0,
);

has bold => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has reverse => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

sub standard_index {
    my $self = shift;
    return $self->index + 8 * $self->bold;
}

__PACKAGE__->meta->make_immutable;

1;

