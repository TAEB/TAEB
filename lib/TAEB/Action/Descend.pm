package TAEB::Action::Descend;
use Moose;
use TAEB::OO;
extends 'TAEB::Action::Ascend';

use constant command => '>';
use constant complement_type => 'stairsup' => '<';

after done => sub {
    my $self    = shift;
    my $start   = $self->starting_tile;
    my $current = TAEB->current_tile;

    return unless $self->command eq '>';

    if (my $branch = $start->branch) {
        $current->branch($branch)
            if $branch eq 'mines'
            || $branch eq 'quest'
            || $branch eq 'gehennom'
            || ($branch eq 'dungeons' && $start->z > 4);
    }
};

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

