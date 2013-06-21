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

# XXX this is just a temporary debugging measure while I convert the code to sane color usage :)
use Scalar::Util 'refaddr';
use overload (
    fallback => 1,
    q{==} => sub {
        my ($a, $b) = @_;
        return 0 if !defined($a) || !defined($b);

        confess unless ref($a) && ref($b) && $a->isa(__PACKAGE__) && $b->isa(__PACKAGE__);
        return refaddr($a) == refaddr($b);
    },
);

__PACKAGE__->meta->make_immutable;

1;

