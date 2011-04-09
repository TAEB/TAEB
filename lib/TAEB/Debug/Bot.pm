package TAEB::Debug::Bot;
use Moose::Role;
use TAEB::OO;
use Set::Object;

requires 'speak', 'quit_message', 'tick';

has paused => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has step => (
    traits  => ['Counter'],
    is      => 'ro',
    default => -1,
    trigger => sub {
        my $self = shift;
        my $val = shift;
        $self->set_step(0) if $val < 0;
    }
);

has _watching_messages => (
    isa     => 'Set::Object',
    lazy    => 1,
    default => sub { Set::Object->new },
    handles => {
        watch_message     => 'insert',
        unwatch_message   => 'remove',
        watching_messages => 'elements',
        watching_message  => 'contains',
    },
);

sub msg_any {
    my $self = shift;
    my $msg = shift;

    if ($self->watching_message($msg)) {
        $self->speak("I received a $msg message with args " . join(', ', @_));
        $self->unwatch_message($msg);
    }
}

my %responses = (
    who      => sub {
        sprintf "%s (%s %s %s %s)", TAEB->name, TAEB->role, TAEB->race,
                                    TAEB->gender, TAEB->align
    },
    where    => sub {
        sprintf "%s %s", TAEB->current_tile, TAEB->current_level
    },
    inventory => sub {
        my $inv = TAEB->inventory;
        $inv =~ s/\n/, /g;
        $inv
    },
    status    => sub {
        join(', ', TAEB->statuses) || 'None'
    },
    currently => sub {
        TAEB->currently
    },
    map      => sub {
        require App::Nopaste;
        App::Nopaste::nopaste(text => TAEB->vt->as_string("\n"),
                              nick => TAEB->name);
    },
    messages => sub {
        require App::Nopaste;
        App::Nopaste::nopaste(text => join("\n", TAEB->scraper->old_messages),
                              nick => TAEB->name);
    },
    pause    => sub {
        shift->paused(1);
        TAEB->notify('Paused (IRC)', 0);
        'Paused'
    },
    unpause  => sub {
        shift->paused(0);
        'Unpaused'
    },
    step     => sub {
        my $self = shift;
        my $turns = shift || 1;
        $self->inc_step($turns);
        'Stepping ('.$self->step.')'
    },
    watch    => sub {
        my $self = shift;
        my $msg_name = shift;
        $self->watch_message($msg_name);
        "Watching message $msg_name"
    },
    unwatch  => sub {
        my $self = shift;
        my $msg_name = shift;
        $self->unwatch_message($msg_name);
        "No longer watching message $msg_name"
    },
    watching => sub {
        join(', ', shift->watching_messages) || 'None'
    },
);

sub response_to {
    my $self = shift;
    my $body = shift;

    my ($command, $args) = $body =~ /^(\w+)(?:\s+(.*))?/;

    return unless $command;
    if (exists $responses{$command}) {
        return $responses{$command}->($self, $args);
    }
    elsif (my $attr = TAEB->senses->meta->get_attribute($command)) {
        my $reader = $attr->get_read_method_ref;
        my $value = $reader->(TAEB->senses);
        $value = '(undef)' if !defined($value);
        return $value;
    }
    else {
        return "Don't know command $command";
    }
}

subscribe step => sub {
    my $self = shift;

    do {
        $self->tick;
    } while ($self->paused && $self->step == 0);

    $self->dec_step;
};

no Moose::Role;
no TAEB::OO;

1;

