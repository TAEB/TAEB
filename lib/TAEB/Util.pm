package TAEB::Util;
use strict;
use warnings;
use TAEB::Util::Pair;

use Carp 'confess';

use Scalar::Util qw(blessed isweak refaddr weaken);
use List::Util qw(first min max minstr maxstr reduce sum shuffle);
use List::MoreUtils ':all';

use Memoize;

our %colors;

BEGIN {
    %colors = (
        COLOR_BLACK          => 0,
        COLOR_RED            => 1,
        COLOR_GREEN          => 2,
        COLOR_BROWN          => 3,
        COLOR_BLUE           => 4,
        COLOR_MAGENTA        => 5,
        COLOR_CYAN           => 6,
        COLOR_GRAY           => 7,
        COLOR_NONE           => 8,
        COLOR_ORANGE         => 9,
        COLOR_BRIGHT_GREEN   => 10,
        COLOR_YELLOW         => 11,
        COLOR_BRIGHT_BLUE    => 12,
        COLOR_BRIGHT_MAGENTA => 13,
        COLOR_BRIGHT_CYAN    => 14,
        COLOR_WHITE          => 15,
    );
}

use constant \%colors;

use Sub::Exporter -setup => {
    exports => [
        qw(tile_types tile_type_to_glyph tile_type_to_color trap_types),
        qw(delta2vi vi2delta deltas dice colors crow_flies angle align2str),
        qw(display display_ro assert assert_is item_menu hashref_menu object_menu),
        qw(list_menu numeric_color string_color),
        keys %colors,
        qw(blessed isweak refaddr weaken),
        @List::Util::EXPORT_OK,
        @List::MoreUtils::EXPORT_OK,
    ],
    groups => {
        colors => [ keys %colors ],
    },
};

sub colors { %colors }

sub numeric_color {
    my ($color) = @_;
    return $color if $color =~ /\d/;
    $color = uc $color;
    $color = "COLOR_$color";
    my %colors = colors;
    return $colors{$color};
}

sub string_color {
    my ($color) = @_;
    return $color unless $color =~ /\d/;
    my %colors = colors;
    my ($string_color) = grep { $colors{$_} == $color } (keys %colors);
    $string_color = lc $string_color;
    $string_color =~ s/^color_//;
    return $string_color;
}

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

# except for traps
# miss =>? deal with it
# traps are a bit hairy. with some remapping magic could rectify..
our %feature_colors = (
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

our %trap_colors = (
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

our @types = uniq 'obscured', map { ref $_ ? @$_ : $_ } values %glyphs;

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

    for my $color (keys %feature_colors) {
        my $type  = $feature_colors{$color};
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
    return map { ref $_ ? @$_ : $_ } values %trap_colors;
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

sub align2str {
    my $val = shift;

    return 'Una' if !defined($val);
    return ($val > 0) ? 'Law' : ($val < 0) ? 'Cha' : 'Neu';
}

sub dice {
    my $dice = shift;
    my ($num, $sides, $num2, $sides2, $bonus) =
        $dice =~ /(\d+)?d(\d+)(?:\+(\d+)?d(\d+))?([+-]\d+)?/;
    $num ||= 1;
    $num2 ||= 1;
    $bonus ||= 0;
    $sides2 ||= 0;
    $bonus =~ s/\+//;

    my $average = $num * $sides / 2 + $num2 * $sides2 / 2 + $bonus;
    return $average if !wantarray;

    my $max = $num * $sides + $num2 * $sides2 + $bonus;
    my $min = $num + $num2 + $bonus;

    return ($min, $average, $max);
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

sub display {
    require TAEB::Display::Color;
    TAEB::Display::Color->new(@_)
}
# T::D::Color values are mutable, so memoizing by default is a Bad Idea.
# However, memoization gains a lot of speed, so we install a memoized
# version for use by callers who know that it's safe.
memoize 'display', INSTALL => 'display_ro', LIST_CACHE => 'MERGE';

sub _canonicalize_name_value {
    my ($name, $value) = @_;
    $value = "(undef)" if !defined($value);
    $value = "(empty)" if !length($value);

    return TAEB::Util::Pair->new(name => $name, value => $value);
}

sub _shorten_title {
    my $title = shift;
    return $title if length($title) <= 75;
    $title = substr $title, -75;
    $title = "... " . $title;
    return $title;
}

sub item_menu {
    my $title = shift;
    my $thing = shift;
    my $quiet = shift;

    if (blessed($thing) && $thing->can('meta')) {
        return object_menu($title, $thing);
    }
    elsif (ref($thing) && ref($thing) eq 'HASH') {
        return hashref_menu($title, $thing);
    }
    elsif (ref($thing) && ref($thing) eq 'ARRAY') {
        return list_menu($title, $thing);
    }
    elsif (blessed($thing) && $thing->isa('Set::Object')) {
        return list_menu($title, [$thing->members]);
    }

    die "No valid menu type for '$thing'" unless $quiet;
}

sub hashref_menu {
    my $title = shift;
    my $hash = shift;
    $title ||= "${hash}'s keys/values";

    my @hash_data = (
        map {
            _canonicalize_name_value($_, $hash->{$_});
        }
        sort keys %$hash
    );

    my $menu = TAEB::Display::Menu->new(
        description => _shorten_title($title),
        items       => \@hash_data,
        select_type => 'single',
    );
    my $item = TAEB->display_menu($menu) or return;
    my $selected = $item->user_data;
    item_menu("$title -> " . $selected->name, $selected->value, 1);
}

sub object_menu {
    my $title = shift;
    my $object = shift;
    $title ||= "${object}'s attributes";

    my @object_data = (
        sort map {
            my $name = $_->name;
            _canonicalize_name_value($name, scalar $object->$name);
        }
        $object->meta->get_all_attributes
    );

    my $menu = TAEB::Display::Menu->new(
        description => _shorten_title($title),
        items       => \@object_data,
        select_type => 'single',
    );
    my $item = TAEB->display_menu($menu) or return;
    my $selected = $item->user_data;
    item_menu("$title -> " . $selected->name, $selected->value, 1);
}

sub list_menu {
    my $title = shift || "Unknown list";
    my $items = shift;
    my $menu = TAEB::Display::Menu->new(
        description => _shorten_title($title),
        items       => $items,
        select_type => 'single',
    );
    my $item = TAEB->display_menu($menu) or return;
    my $selected = $item->user_data;
    item_menu("$title -> $selected", $selected, 1);
}

sub _add_file_line {
    my $explanation = shift;

    my (undef, $file, $line) = caller(1);
    return $explanation .= " at $file line $line";
}

sub assert {
    my ($condition, $explanation) = @_;

    return if $condition;

    my $message = _add_file_line("Assertion failed: $explanation");

    if (TAEB->config->kiosk_mode) {
        warn $message;
    }
    else {
        TAEB->debugger->console->repl($message);
    }
}

sub assert_is {
    my ($got, $expected, $explanation) = @_;

    return if !defined($got) && !defined($expected);
    return if defined($got) && defined($expected) && $got eq $expected;

    $explanation = "Assertion failed: " . _add_file_line($explanation) . "\n";
    $explanation .= "'$got' does not equal '$expected'";

    my $message = _add_file_line("Assertion failed: $explanation");

    if (TAEB->config->kiosk_mode) {
        warn $message;
    }
    else {
        TAEB->debugger->console->repl($message);
    }
}

1;

__END__

=head2 tile_types -> [str]

Returns the list of all the tile types TAEB uses.

=head2 tile_type_to_glyph str -> str

Returns the glyph for a given tile type

=head2 trap_types -> [str]

Returns the list of all the trap types TAEB uses.

=head2 delta2vi Int, Int -> Str

This will return a vi key for the given dx, dy.

=head2 vi2delta Str -> Int, Int

This will return a dx, dy key for the given vi key (also accepted is C<.>).

=head2 angle :: (Dir, Dir) -> Int

Returns the absolute angle in octants between two directions.

=head2 deltas -> [[dx, dy]]

Returns a list of arrayreferences, each a pair of delta x and delta y. Suitable
for iterating over.

=head2 align2str :: Int -> Str

Convert an alignment modifier like -5 into a Law/New/Cha.

=head2 dice spec -> avg | min avg max

Given a regular dice spec (e.g. "10d5" or "d4+2d6"), returns the average,
minimum, and maximum. In scalar context, it will return just the average. In
list context, it will return a list of (minimum, average, maximum).

=head2 crow_flies [Int, Int, ]Int, Int -> Str

Returns the vi key directions required to go from where TAEB is to the given
coordinates. If two sets of coordinates are passed in, they will be interpreted
as the "from" coordinates, instead of TAEB's current position.

=for my_sanity
    while ($x + 8 < $x1 && $y - 8 > $y1) { $dir .= 'Y'; $x += 8; $y -= 8 }
    while ($x - 8 > $x1 && $y - 8 > $y1) { $dir .= 'U'; $x -= 8; $y -= 8 }
    while ($x - 8 > $x1 && $y + 8 < $y1) { $dir .= 'B'; $x -= 8; $y += 8 }
    while ($x + 8 < $x1 && $y + 8 < $y1) { $dir .= 'N'; $x += 8; $y += 8 }
    while ($x     < $x1 && $y     > $y1) { $dir .= 'y'; $x++; $y-- }
    while ($x     > $x1 && $y     > $y1) { $dir .= 'u'; $x--; $y-- }
    while ($x     > $x1 && $y     < $y1) { $dir .= 'b'; $x--; $y++ }
    while ($x     < $x1 && $y     < $y1) { $dir .= 'n'; $x++; $y++ }
    while ($x - 8 > $x1) { $dir .= 'H'; $x -= 8 }
    while ($y + 8 < $y1) { $dir .= 'J'; $y += 8 }
    while ($y - 8 > $y1) { $dir .= 'K'; $y -= 8 }
    while ($x + 8 < $x1) { $dir .= 'L'; $x += 8 }
    while ($x     > $x1) { $dir .= 'h'; $x-- }
    while ($y     < $y1) { $dir .= 'j'; $y++ }
    while ($y     > $y1) { $dir .= 'k'; $y-- }
    while ($x     < $x1) { $dir .= 'l'; $x++ }

=cut

