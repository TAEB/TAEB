package TAEB::Action::Kick;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Direction';

has '+direction' => (
    required => 1,
);

# ctrl-D
use constant command => "\cd";

# sorry sir!
sub respond_buy_door { 'y' }

sub msg_dishwasher { shift->target_tile('sink')->got_foocubus(1) }
sub msg_pudding    { shift->target_tile('sink')->got_pudding(1) }
sub msg_ring_sink  { shift->target_tile('sink')->got_ring(1) }

sub done {
    my $self = shift;
    my $target = $self->target_tile;
    $target->kicked($target->kicked + 1) if $target->can('kicked');
}

sub is_impossible {
    return TAEB->in_beartrap
        || TAEB->in_pit
        || TAEB->in_web
        || TAEB->is_wounded_legs
        || TAEB->is_levitating
        || TAEB->burden_mod <= 0.5; # Stressed or worse
}

__PACKAGE__->meta->make_immutable;

1;

