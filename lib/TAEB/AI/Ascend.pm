package TAEB::AI::Ascend;
use Moose;
use TAEB::OO;
extends 'TAEB::AI';

# This is actually useful for testing the end-of-game sequence, but it's also
# here because, well, ascend
sub next_action { TAEB::Action::Move->new(direction => '<') }

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::AI::Ascend - Ascend in one line of code

=cut

