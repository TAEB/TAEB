package TAEB::Util::Colors;
use strict;
use warnings;
use TAEB::Display::Color;

our @colors;
BEGIN {
    @colors = qw/
        COLOR_BLACK
        COLOR_RED
        COLOR_GREEN
        COLOR_BROWN
        COLOR_BLUE
        COLOR_MAGENTA
        COLOR_CYAN
        COLOR_GRAY
        COLOR_NONE
        COLOR_ORANGE
        COLOR_BRIGHT_GREEN
        COLOR_YELLOW
        COLOR_BRIGHT_BLUE
        COLOR_BRIGHT_MAGENTA
        COLOR_BRIGHT_CYAN
        COLOR_WHITE
    /;
}

use Sub::Exporter -setup => {
    exports => [ 'color_from_index', 'string_color', @colors ],
    groups  => {
        default => [ @colors ],
        colors  => [ @colors ],
    },
};

use Memoize;
memoize '_color';

sub _color {
    my ($index, $bold, $reverse) = @_;

    TAEB::Display::Color->new(
        index   => $index,
        bold    => $bold,
        reverse => $reverse,
    );
}

sub COLOR_BLACK          { _color(0, 0, 0) }
sub COLOR_RED            { _color(1, 0, 0) }
sub COLOR_GREEN          { _color(2, 0, 0) }
sub COLOR_BROWN          { _color(3, 0, 0) }
sub COLOR_BLUE           { _color(4, 0, 0) }
sub COLOR_MAGENTA        { _color(5, 0, 0) }
sub COLOR_CYAN           { _color(6, 0, 0) }
sub COLOR_GRAY           { _color(7, 0, 0) }
sub COLOR_NONE           { _color(0, 1, 0) }
sub COLOR_ORANGE         { _color(1, 1, 0) }
sub COLOR_BRIGHT_GREEN   { _color(2, 1, 0) }
sub COLOR_YELLOW         { _color(3, 1, 0) }
sub COLOR_BRIGHT_BLUE    { _color(4, 1, 0) }
sub COLOR_BRIGHT_MAGENTA { _color(5, 1, 0) }
sub COLOR_BRIGHT_CYAN    { _color(6, 1, 0) }
sub COLOR_WHITE          { _color(7, 1, 0) }

sub string_color {
    my $index = shift;

    my $name = lc($colors[$index]);
    $name =~ s/^color_//;
    return $name;
}

sub color_from_index {
    my $index = shift;
    return $index >= 8 ? _color($index - 8, 1, 0)
                       : _color($index,     0, 0);
}

1;

