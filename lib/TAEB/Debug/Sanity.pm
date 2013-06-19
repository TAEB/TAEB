package TAEB::Debug::Sanity;
use Moose;
use TAEB::OO;
with 'TAEB::Role::Config';

TAEB->register_debug_commands(
    'S' => {
        help    => "Toggle global per-turn sanity checks",
        command => sub { TAEB->debugger->sanity->toggle },
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

sub toggle {
    my $self = shift;

    $self->enabled(!$self->enabled);

    TAEB->notify("Global per-turn sanity checks now " .
        ($self->enabled ? "en" : "dis") . "abled.");
};

subscribe step => sub {
    my $self = shift;

    TAEB->send_message('sanity') if $self->enabled;
};

__PACKAGE__->meta->make_immutable;

1;
