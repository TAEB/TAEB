package TAEB::Action::Loot;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

use constant command => "#loot\n";

sub respond_loot_it { "y" }

# XXX is there ever a case where we'd want to put something in? our own bag
# that we've dropped, maybe?
sub respond_take_something_out { "y" }
sub respond_put_something_in { "n" }

__PACKAGE__->meta->make_immutable;

1;
