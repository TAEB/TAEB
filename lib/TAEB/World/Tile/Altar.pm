package TAEB::World::Tile::Altar;
use Moose;
use TAEB::OO;
use TAEB::Util::Colors;
extends 'TAEB::World::Tile';

has align => (
    is        => 'rw',
    isa       => 'TAEB::Type::Align',
    predicate => 'has_align',
);

sub debug_color {
    my $self = shift;
    my $align = $self->align;

    if (defined $align) {
        return COLOR_RED   if $align eq 'Cha';
        return COLOR_GREEN if $align eq 'Neu';
        return COLOR_CYAN  if $align eq 'Law';
    }

    return COLOR_MAGENTA;
}

sub reblessed {
    my $self = shift;
    my ($old_class, $align) = @_;

    if ($align) {
        $self->align($align);
        return;
    }

    TAEB->send_message(check => tile => $self);
}

sub farlooked {
    my $self = shift;
    my $msg  = shift;

    if ($msg =~ /altar.*(chaotic|neutral|lawful)/) {
        $self->align(ucfirst(substr($1, 0, 3)));
    }
}

around debug_line => sub {
    my $orig = shift;
    my $self = shift;
    my $line = $self->$orig(@_);

    $line .= " " . $self->align if $self->align;
    return $line;
};

__PACKAGE__->meta->make_immutable;

1;

