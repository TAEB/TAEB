package TAEB::VT;
use Moose;
use TAEB::OO;
use MooseX::NonMoose;
extends 'Term::VT102::ZeroBased';

has topline => (
    is  => 'rw',
    isa => 'Str',
);

has rows_changed => (
    is  => 'rw',
    isa => 'ArrayRef[Bool]',
    default => sub { [] },
);

after process => sub {
    my $self = shift;
    $self->topline($self->row_plaintext(0));
};

sub BUILD {
    my $self = shift;
    $self->callback_set('ROWCHANGE', sub {
        # The number of the row changed is the third arg to the
        # callback function.
        # XXX Term::VT102::ZeroBased appears not to change the offset to
        # zero-based here; this workaround (the -1) needs removal if and
        # when Term::VT102::ZeroBased is fixed.
        $self->rows_changed->[$_[2]-1] = 1;
    }, undef);
}

sub find_row {
    my $self = shift;
    my $cb = shift;

    for my $row (0 .. $self->rows - 1) {
        return $row if $cb->($self->row_plaintext($row), $row);
    }

    return;
}

sub contains {
    my $self = shift;
    my $text = shift;

    defined $self->find_row(sub { index($_[0], $text) >= 0 });
}

sub matches {
    my $self = shift;
    my $re = shift;

    defined $self->find_row(sub { $_[0] =~ $re });
}

sub at {
    my $self = shift;
    my $x    = shift;
    my $y    = shift;

    $self->row_plaintext($y, $x, $x);
}

sub as_string {
    my $self = shift;
    my $delimiter = shift || '';
    my $first_row = shift || 0;
    my $last_row = shift || $self->rows - 1;
    my @rows;

    for my $row ($first_row.. $last_row) {
        push @rows, $self->row_plaintext($row);
    }

    return join($delimiter, @rows);
}

sub attr_to_ansi {
    my $self = shift;
    my %args = @_;

    my $fg = 3 . ($args{fg} || 7);
    $fg =~ s/^3(3.)/$1/;

    my $bg = 4 . ($args{bg} || 0);
    $bg =~ s/^4(4.)/$1/;

    my $color = "\e[0";
    $color .= ";1" if $args{bold};
    $color .= ";2" if $args{faint};
    $color .= ";3" if $args{standout};
    $color .= ";4" if $args{underline};
    $color .= ";5" if $args{blink};
    $color .= ";7" if $args{reverse};

    $color .= ";$fg" if $fg != 37;
    $color .= ";$bg" if $bg != 40;

    return $color . 'm';
}

sub color {
    my $self = shift;
    my $x = shift;
    my $y = shift;

    # fields: fg, bg, bold, faint, standout, underline, blink, reverse
    my @attr = $self->attr_unpack($self->row_attr($y, $x, $x));

    # bold is only 0 or 1
    # this then maps into the constants from color.h (and in Util.pm)
    return $attr[0] + 8*$attr[2];
}

sub row_color {
    my $self = shift;
    my $y = shift;

    my $attrs = $self->row_attr($y);

    return map {
        # fields: fg, bg, bold, faint, standout, underline, blink, reverse
        my @attr = $self->attr_unpack($_);

        # bold is only 0 or 1
        # this then maps into the constants from color.h (and in Util.pm)
        $attr[0] + 8*$attr[2];
    } $attrs =~ m{..}g;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 find_row CODE

This is used to iterate over the virtual terminal's rows, looking for something.
The callback receives the contents of each row, and its index, in turn.

If the callback returns a true value, then the find_row method will return
the current row's index.

If the callback returns all false values, then the find_row method will
return C<undef>.

=head2 contains Str -> Bool

Returns whether the specified string is contained in the virtual terminal's
contents.

=head2 matches Regexp -> Bool

Returns whether the specified regex matches any of the VT's rows.

=head2 at Int, Int -> Char

Returns the character at the specified (row, col)

=head2 as_string [Str, Int, Int] -> Str

Will join together all of the rows in the VT with the optional delimiter
(default is the empty string).

=head2 attr_to_ansi Hash -> Str

Takes a hash with the following keys, and returns the ANSI escape code that can
be used to get those keys set.

=over 4

=item fg

=item bg

=item bold

=item faint

=item standout

=item underline

=item blink

=item reverse

=back

=head2 color Int, Int -> Int

Returns an int representing the color NetHack uses for whatever is occupying the specified tile.

=head2 row_color Int -> [Int]

Returns 80 ints representing the color of each cell of the row.

=cut

