package TAEB::Debug::Watch;
use Moose;
use TAEB::OO;
use Try::Tiny;
with 'TAEB::Role::Config';

use Scalar::Util 'weaken';

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

has watched_messages => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        watched_messages       => 'elements',
        watch_message          => 'push',
        reset_watched_messages => 'clear',
    },
);

sub watch_once {
    my $self = shift;
    my ($watchpoint) = @_;

    weaken(my $weakself = $self);
    my $wrapped;
    $wrapped = sub {
        my $ret = $watchpoint->();
        if ($ret) {
            $weakself->remove($wrapped);
            undef $wrapped;
        }
        return $ret;
    };
    $self->watch($wrapped);
}

sub remove {
    my $self = shift;
    my ($watchpoint) = @_;

    my @watchpoints = $self->watchpoints;
    $self->reset;
    for my $old (@watchpoints) {
        $self->watch($old) unless $old == $watchpoint;
    }
}

sub remove_message {
    my $self = shift;
    my ($message) = @_;

    my @messages = $self->watched_messages;
    for my $old (@messages) {
        $self->watch_message($old) unless $old eq $message;
    }
}

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

sub msg_any {
    my $self = shift;
    my ($msg, @args) = @_;

    if (grep { $msg eq $_ } $self->watched_messages) {
        TAEB->paused(1);
    }
}

subscribe any => sub {
    my $self = shift;
    my ($announcement) = @_;

    if (grep { $announcement->name eq $_ } $self->watched_messages) {
        TAEB->paused(1);
    }
};

__PACKAGE__->meta->make_immutable;

1;
