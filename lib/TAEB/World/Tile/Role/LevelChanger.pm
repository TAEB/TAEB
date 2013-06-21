package TAEB::World::Tile::Role::LevelChanger;
use Moose::Role;
use TAEB::Util::Colors;

has other_side => (
    is        => 'rw',
    isa       => 'TAEB::World::Tile',
    predicate => 'other_side_known',
    clearer   => 'clear_other_side',
    weak_ref  => 1,
);

override debug_color => sub {
    my $self = shift;

    my $different_branch = $self->known_branch
                        && $self->other_side_known
                        && $self->other_side->known_branch
                        && $self->branch ne $self->other_side->branch;

    return $different_branch
         ? COLOR_YELLOW
         : super;
};

1;

