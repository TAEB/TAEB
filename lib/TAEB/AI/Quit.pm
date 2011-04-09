package TAEB::AI::Quit;
use Moose;
use TAEB::OO;
extends 'TAEB::AI';

sub next_action { TAEB::Action::Quit->new }

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::AI::Quit - I just can't take it any more...

=cut

