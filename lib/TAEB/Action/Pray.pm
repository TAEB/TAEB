package TAEB::Action::Pray;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

use constant command => "#pray\n";

sub done {
    TAEB->last_prayed(TAEB->turn);
}

sub is_advisable {
    my $self = shift;
    return !$self->is_impossible
        && TAEB->max_god_anger == 0
        && TAEB->turn > TAEB->last_prayed + 500
        && TAEB->luck >= 0;
}

__PACKAGE__->meta->make_immutable;

1;

