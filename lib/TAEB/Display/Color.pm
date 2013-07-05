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

use overload (
    q{==} => sub {
        my ($self, $other) = @_;
        return $self->index == $other->index
            && $self->bold == $other->bold
            && $self->reverse == $other->reverse;
    },
    q{!=} => sub {
        my ($self, $other) = @_;
        return $self->index != $other->index
            || $self->bold != $other->bold
            || $self->reverse != $other->reverse;
    },
    q{""} => sub {
        my ($self) = @_;
        return "[Color: index=".$self->index." bold=".$self->bold." reverse=".$self->reverse."]";
    },
    fallback => 1,
);

__PACKAGE__->meta->make_immutable;

1;

