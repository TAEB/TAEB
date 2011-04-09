package TAEB::Action::Search;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

has started => (
    is      => 'ro',
    isa     => 'Int',
    default => sub { TAEB->turn },
);

has iterations => (
    is       => 'ro',
    isa      => 'Int',
    default  => 20,
    provided => 1,
);

sub command { shift->iterations . 's' }

sub done {
    my $self = shift;
    my $diff = TAEB->turn - $self->started;

    TAEB->each_adjacent_inclusive(sub {
        my $self = shift;
        $self->inc_searched($diff);

        # Searching when blind gives us more information.
        # If a tile's next to 'floor' but not to 'corridor',
        # and still shows up as a 'unexplored' after searching,
        # it's probably not rock; set it to floor, while
        # maintaining the ' ' glyph (the '.' is a floor_glyph).
        # If it is rock, and we didn't see the corridor for some
        # reason (say there was a monster on it), we'll notice
        # when we try to move onto it via handle_items_in_rock.
        if ($self->type eq 'unexplored' && TAEB->is_blind &&
            ! $self->any_adjacent(sub {shift->type eq 'corridor'})) {
            $self->change_type('floor' => '.');
        }
    });
}

__PACKAGE__->meta->make_immutable;

1;

