package TAEB::Announcement::Role::SelectSubset;
use Moose::Role;

has items => (
    traits     => ['Array'],
    isa        => 'ArrayRef',
    required   => 1,
    handles    => {
        items      => 'elements',
        item_count => 'count',
        item       => 'get',
    },
);

has _is_selected => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [ 0 x shift->item_count ] },
);

sub select { ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;

    SELECTION: for my $selection (@_) {
        for my $index (0 .. $self->item_count - 1) {
            my $item = $self->item($index);
            if ($item eq $selection) {
                $self->_is_selected->[$index] = 1;
                next SELECTION;
            }
        }
    }
}

sub selected_items {
    my $self = shift;

    return map  { $self->item($_) }
           grep { $self->_selected->[$_] }
           0 .. $self->item_count - 1;
}

no Moose::Role;

1;

