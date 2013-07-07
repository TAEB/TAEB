package TAEB::Util::World;
use strict;
use warnings;
use TAEB::Util qw/uniq min max/;
use TAEB::Util::Colors;

use Carp 'confess';

use Sub::Exporter -setup => {
    exports => [
        qw(tile_types tile_type_to_glyph tile_type_to_color trap_types),
        qw(delta2vi vi2delta deltas crow_flies angle glyphs feature_colors trap_colors),
    ],
};

our %glyphs = (
    ' '  => [qw/rock unexplored/],
    ']'  => 'closeddoor',
    '>'  => 'stairsdown',
    '<'  => 'stairsup',
    '^'  => 'trap',
    '_'  => 'altar',
    '~'  => 'pool',

    '|'  => [qw/opendoor wall/],
    '-'  => [qw/opendoor wall/],
    '.'  => [qw/floor ice/],
    '\\' => [qw/grave throne/],
    '{'  => [qw/sink fountain/],
    '}'  => [qw/bars tree drawbridge lava underwater/],

    '#'  => 'corridor',
    #'#'  => 'air', # who cares, no difference
);
sub glyphs { \%glyphs }

# except for traps
# miss =>? deal with it
# traps are a bit hairy. with some remapping magic could rectify..
our @feature_colors = (
    COLOR_BLUE,    [qw/fountain trap pool underwater/],
    COLOR_BROWN,   [qw/opendoor closeddoor drawbridge stairsup stairsdown trap/],
    COLOR_CYAN,    [qw/bars ice trap/],
    COLOR_GRAY,    [qw/unexplored rock altar corridor floor grave sink stairsup stairsdown trap wall/],
    COLOR_GREEN,   'tree',
    COLOR_MAGENTA, 'trap',
    COLOR_ORANGE,  'trap',
    COLOR_RED,     [qw/lava trap/],
    COLOR_YELLOW,  'throne',
    COLOR_BRIGHT_BLUE,    'trap',
    COLOR_BRIGHT_GREEN,   'trap',
    COLOR_BRIGHT_MAGENTA, 'trap',
);

sub feature_colors {
    my %feature_colors = @feature_colors;
    return \%feature_colors;
}

our @trap_colors = (
    COLOR_BLUE,    ['rust trap', 'pit', 'spiked pit'],
    COLOR_BROWN,   ['squeaky board', 'hole', 'trap door'],
    COLOR_CYAN,    ['arrow trap', 'dart trap', 'bear trap'],
    COLOR_GRAY,    ['falling rock trap', 'rolling boulder trap', 'web'],
    COLOR_MAGENTA, ['teleportation trap', 'level teleporter'],
    COLOR_ORANGE,  'fire trap',
    COLOR_RED,     'land mine',
    COLOR_BRIGHT_BLUE,    ['magic trap', 'anti-magic field',
                           'sleeping gas trap'],
    COLOR_BRIGHT_GREEN,   'polymorph trap',
    COLOR_BRIGHT_MAGENTA, 'magic portal',
);

sub trap_colors {
    my %trap_colors = @trap_colors;
    return \%trap_colors;
}

our @types = uniq(
    'obscured', 'secretdoor',
    map { ref $_ ? @$_ : $_ } values %glyphs
);

sub tile_types {
    return @types;
}

do {
    my (%type_to_glyph, %type_to_color);
    for my $glyph (keys %glyphs) {
        my $type  = $glyphs{$glyph};
        my @types = @{ ref($type) eq 'ARRAY' ? $type : [$type] };

        $type_to_glyph{$_} = $glyph for @types;
    }

    for (my $i = 0; $i < @feature_colors; $i += 2) {
        my ($color, $type) = @feature_colors[$i, $i+1];
        my @types = @{ ref($type) eq 'ARRAY' ? $type : [$type] };

        $type_to_color{$_} = $color for @types;
    }

    $type_to_glyph{'obscured'} = '?';
    $type_to_color{'obscured'} = COLOR_ORANGE;

    sub tile_type_to_glyph {
        my $type = shift;
        return $type_to_glyph{$type} || confess "Unknown tile type '$type'";
    }

    sub tile_type_to_color {
        my $type = shift;
        return $type_to_color{$type} || confess "Unknown tile type '$type'";
    }
};

sub trap_types {
    return map { ref $_ ? @$_ : $_ } values %{ trap_colors() };
}

our @directions = (
    [qw/y k u/],
    [qw/h . l/],
    [qw/b j n/],
);

sub delta2vi {
    my $dx = shift;
    my $dy = shift;
    return $directions[$dy+1][$dx+1];
}

my %vi2delta = (
    '.' => [ 0,  0],
     h  => [-1,  0],
     j  => [ 0,  1],
     k  => [ 0, -1],
     l  => [ 1,  0],
     y  => [-1, -1],
     u  => [ 1, -1],
     b  => [-1,  1],
     n  => [ 1,  1],
);

sub vi2delta {
    return @{ $vi2delta{ lc $_[0] } || [] };
}

sub angle {
    my ($a, $b) = @_;

    $a = index "ykulnjbh", $a;
    $b = index "ykulnjbh", $b;

    my $ang = ($a - $b) % 8;

    $ang -= 8 if $ang > 4;

    return abs($ang);
}

sub deltas {
    # northwest northeast southwest southeast
    # north south west east
    return (
        [-1, -1], [-1,  1], [ 1, -1], [ 1,  1],
        [-1,  0], [ 1,  0], [ 0, -1], [ 0,  1],
    );

}

sub which_dir {
    my ($dx, $dy) = @_;
    my %dirs = (
        -1 => { -1 => 'y', 0 => 'h', 1 => 'b' },
        0  => { -1 => 'k',           1 => 'j' },
        1  => { -1 => 'u', 0 => 'l', 1 => 'n' },
    );

    my ($sdx, $sdy) = (0, 0);
    $sdx = $dx / abs($dx) if $dx != 0;
    $sdy = $dy / abs($dy) if $dy != 0;
    return ($dirs{$sdx}{$sdy},
            abs($dx) > abs($dy) ? $dirs{$sdx}{0} : $dirs{0}{$sdy});
}

sub crow_flies {
    my $x0 = @_ > 2 ? shift : TAEB->x;
    my $y0 = @_ > 2 ? shift : TAEB->y;
    my $x1 = shift;
    my $y1 = shift;

    my $directions = '';
    my $sub = 0;

    my $dx = $x1 - $x0;
    my $dy = $y1 - $y0;
    my ($diag_dir, $straight_dir) = which_dir($dx, $dy);

    $dx = abs $dx; $dy = abs $dy;

    use integer;
    # Get the minimum number of divisible-by-eight segments
    # to get the number of YUBN diagonal movements to get to the
    # proper vertical or horizontal line
    # This first part will get to within 7
    $sub = min($dx/8, $dy/8);
    $directions .= uc ($diag_dir x $sub);
    $dx -= 8 * $sub;
    $dy -= 8 * $sub;

    # Now move the rest of the way (0..7)
    $sub = min($dx, $dy);
    $directions .= $diag_dir x $sub;
    $dx -= $sub;
    $dy -= $sub;

    # Here we use max because one of the directionals is zero now
    # Otherwise same concept as the first part
    $sub = max($dx/8, $dy/8);
    $directions .= uc ($straight_dir x $sub);
    $dx -= 8 * $sub;
    $dy -= 8 * $sub;

    # Again max, same reason
    $sub = max($dx, $dy);
    $directions .= $straight_dir x $sub;
    # reducing dx/dy isn't needed any more ;)

    return $directions;
}


1;

