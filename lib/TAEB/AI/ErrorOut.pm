package TAEB::AI::ErrorOut;
use Moose;
use TAEB::OO;
extends 'TAEB::AI';

# When asked for an action, throw an error to see how well the rest of
# the framework handles it.
sub next_action { die 'TAEB::AI::ErrorOut intentionally threw an error' }

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::AI::ErrorOut - An AI that can't possibly work, for testing

=cut

