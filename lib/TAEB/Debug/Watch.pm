package TAEB::Debug::Watch;
use Moose;
use TAEB::OO;
use Try::Tiny;
with 'TAEB::Role::Config';

TAEB->register_debug_commands(
    'w' => {
        help    => "Toggle watchpoints",
        command => sub { TAEB->debugger->watch->toggle },
    },
);

has enabled => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub {
        my $self = shift;
        return 0 if !$self->config;
        return $self->config->{enabled}
    },
    lazy    => 1,
);

has watchpoints => (
    traits  => ['Array'],
    isa     => 'ArrayRef[CodeRef]',
    default => sub { [] },
    handles => {
        watchpoints => 'elements',
        watch       => 'push',
        reset       => 'clear',
    },
);

sub toggle {
    my $self = shift;

    $self->enabled(!$self->enabled);

    TAEB->notify("Watchpoints " .
        ($self->enabled ? "en" : "dis") . "abled.");
};

subscribe step => sub {
    my $self = shift;

    return unless $self->enabled;

    for my $watchpoint ($self->watchpoints) {
        if ($watchpoint->()) {
            TAEB->paused(1);
            last;
        }
    }
};

__PACKAGE__->meta->make_immutable;

1;
