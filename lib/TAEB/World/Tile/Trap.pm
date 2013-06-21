package TAEB::World::Tile::Trap;
use Moose;
use TAEB::OO;
use TAEB::Util::Colors;
use TAEB::Util::World 'trap_colors';
extends 'TAEB::World::Tile';

our %TRAP_COLORS = %{ trap_colors() };

has trap_type => (
    is  => 'rw',
    isa => 'TAEB::Type::Trap',
);

sub debug_color { COLOR_BRIGHT_BLUE }

sub reblessed {
    my $self = shift;
    my $old_class = shift;
    my $trap_type = shift;

    if ($trap_type) {
        $self->trap_type($trap_type);
        return;
    }

    $trap_type = $TRAP_COLORS{$self->color};
    if (ref $trap_type) {
        if (defined $self->level->branch &&
            $self->level->branch eq 'sokoban') {
            $self->trap_type(grep { /^(?:pit|hole)$/ } @$trap_type);
            return;
        }
        TAEB->send_message(check => tile => $self);
    }
    else {
        $self->trap_type($trap_type);
    }
}

sub farlooked {
    my $self = shift;
    my $msg  = shift;

    if ($msg =~ /trap.*\((.*?)\)/) {
        $self->trap_type($1);
    }
}

__PACKAGE__->meta->make_immutable;

1;

