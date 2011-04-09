package TAEB::Debug::Sanity;
use Moose;
use TAEB::OO;
with 'TAEB::Role::Config';

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

subscribe step => sub {
    my $self = shift;

    TAEB->send_message('sanity') if $self->enabled;
};

subscribe keypress => sub {
    my $self  = shift;
    my $event  = shift;

    return if $event->key ne 'S';

    $self->enabled(!$self->enabled);

    TAEB->notify("Global per-turn sanity checks now " .
        ($self->enabled ? "en" : "dis") . "abled.");
};

__PACKAGE__->meta->make_immutable;

1;
