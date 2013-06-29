package TAEB::Announcement::Report::Death;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Report';

has conducts => (
    traits     => ['Array'],
    isa        => 'ArrayRef',
    lazy       => 1,
    default    => sub { [] },
    handles    => {
        conducts    => 'elements',
        add_conduct => 'push',
    },
);

has ['score', 'turns'] => (
    is  => 'rw',
    isa => 'Int',
);

has 'max_dlvl' => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    default => sub { TAEB->dungeon->max_dlvl },
);

augment as_string => sub {
    my $self = shift;

    my $conducts = join ', ', $self->conducts;
    my $score    = $self->score;
    my $turns    = $self->turns;
    my $max_dlvl = $self->max_dlvl;

    return << "REPORT";
Conducts: $conducts
Score:    $score
Turns:    $turns
Deepest:  Level $max_dlvl
REPORT
};

__PACKAGE__->meta->make_immutable;

1;

