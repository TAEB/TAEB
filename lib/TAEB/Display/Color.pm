package TAEB::Display::Color;
use Moose;
use TAEB::OO;
use TAEB::Util ':colors';

with 'TAEB::Role::Overload';
sub debug_line {
    my $self = shift;
    my $color = $self->color;
    $color .= 'b' if $self->bold;
    $color .= 'r' if $self->reverse;
    return $color;
}

has _color => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => 'color',
    default  => COLOR_NONE,
);

has _bold => (
    is       => 'rw',
    isa      => 'Bool',
    init_arg => 'bold',
    default  => 0,
);

has reverse => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub color {
    my $self = shift;
    if (@_) {
        my $color = shift;
        if ($color > 8) {
            $color -= 8;
            $self->_bold(1);
        }
        return $self->_color($color);
    }

    my $color = $self->_color;
    return $color > 8 ? $color - 8 : $color;
}

sub bold {
    my $self = shift;
    if (@_) {
        return $self->_bold(@_);
    }

    my $color = $self->_color;
    return 1 if $color > 8 || $self->_bold;
    return 0;
}

override BUILDARGS => sub {
    my $self = shift;
    if (@_ == 1 && !ref($_[0])) {
        return { color => shift };
    }
    super;
};

__PACKAGE__->meta->make_immutable;

1;

