package TAEB::AI::SteadyState;
use Moose;
use TAEB::OO;
extends 'TAEB::AI';

sub next_action { TAEB::Action::Search->new(iterations => 1) }

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::AI::SteadyState - Sit there doing nothing, for benchmarking purposes

=cut

