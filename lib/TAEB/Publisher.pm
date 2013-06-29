package TAEB::Publisher;
use Moose;
use TAEB::OO;
use Set::Object;
use TAEB::Util qw(natatime);

has _subscribers => (
    isa     => 'Set::Object',
    default => sub { Set::Object->new },
    handles => {
        subscribe        => 'insert',
        unsubscribe      => 'remove',
        subscribers      => 'elements',
        subscriber_count => 'size',
    },
);

has queued_messages => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        _push_queued_messages  => 'push',
        _shift_queued_messages => 'shift',
    },
);

has is_paused => (
    traits  => ['Bool'],
    is      => 'rw',
    isa     => 'Bool',
    handles => {
        pause   => 'set',
        unpause => 'unset',
    },
);

before subscribe => sub {
    my $self = shift;
    my $class = shift;
    TAEB->log->publisher("Subscribe: $class");
};

before unsubscribe => sub {
    my $self = shift;
    my $class = shift;
    TAEB->log->publisher("Unsubscribe: $class");
};

before pause => sub {
    TAEB->log->publisher("Pausing all subscriptions.");
};

before unpause => sub {
    TAEB->log->publisher("Unpausing all subscriptions.");
};

after unpause => sub {
    shift->send_queued_messages;
};

sub _enqueue_message {
    my $self = shift;
    my $name = shift;

    TAEB->log->publisher("Queued message $name.");

    $self->_push_queued_messages([$name, @_]);
}

sub announce {
    my $self = shift;
    my $announcement;

    if (blessed($_[0])) {
        $announcement = shift;
    }
    else {
        my $class = TAEB::Announcement->name_to_class(shift);
        $announcement = $class->new(@_);
    }

    # XXX: this will improve
    $self->send_message($announcement->name => $announcement);
}

sub send_message {
    my $self = shift;

    if ($self->is_paused) {
        # Some announcements (like queries) cannot be delayed
        unless (@_ == 1 && blessed($_[0]) && $_[0]->isa('TAEB::Announcement') && $_[0]->is_immediate) {
            return $self->_enqueue_message(@_);
        }
    }

    my $name = shift;
    my @args = @_;

    if (@args) {
        TAEB->log->publisher("Announcing $name with arguments @args.");
    }
    else {
        TAEB->log->publisher("Announcing $name with no arguments.");
    }

    my $method = "msg_$name";

    my $announcement = 0;
    if (@args == 1 && blessed($args[0]) && $args[0]->isa('TAEB::Announcement')) {
        $announcement = 1;
        $method = "subscription_" . $args[0]->name;
    }

    for my $recipient ($self->subscribers) {
        next unless $recipient;

        for ($method, ($announcement ? 'subscription_any' : 'msg_any')) {
            if (ref($recipient) eq 'CODE') {
                $recipient->($name, $_, @args);
            }
            elsif ($recipient->can($_)) {
                if ($_ eq 'msg_any') {
                    $recipient->$_($name, @args);
                }
                else {
                    $recipient->$_(@args);
                }

                last;
            }
        }
    }
}

sub send_queued_messages {
    my $self = shift;

    while (my $msg = $self->_shift_queued_messages) {
        $self->send_message(@$msg);
    }
}

sub _get_generic_response {
    my $self = shift;
    my %args = (
        responders => [ $self->responders ],
        @_,
    );

    my $it = natatime(2, @{ $args{sets} });
    while (my ($re, $name) = $it->()) {
        my $matched = 0;
        my @captures;
        my $sent_will = 0;

        for my $responder (@{ $args{responders} }) {
            if (my $code = $responder->can("$args{method}_$name")) {
                if ($matched ||= @captures = $args{msg} =~ $re) {
                    TAEB->send_message("will_$args{method}_$name")
                        unless $sent_will++;

                    my $response = $responder->$code(
                        @captures,
                        $args{msg},
                    );

                    if (!defined $response) {
                        TAEB->log->publisher(blessed($responder) . " explicitly refrained from responding to $name.");
                    }
                    else {
                        TAEB->log->publisher(blessed($responder) . " is responding to $name with $response.");
                        TAEB->send_message("did_$args{method}_$name" => $response);
                        return $response;
                    }
                }
            }
        }
    }

    for my $responder (grep { defined } @{ $args{responders} }) {
        if (my $code = $responder->can($args{method})) {
            my $response = $responder->$code($args{msg});
            next unless defined $response;

            TAEB->log->publisher("$responder is generically responding to $args{msg}.");
            return $response;
        }
    }

    return;
}

sub get_exceptional_response {
    my $self = shift;
    my $msg  = shift;

    return $self->_get_generic_response(
        msg    => $msg,
        sets   => \@TAEB::ScreenScraper::exceptions,
        method => "exception",
    );
}

sub get_response {
    my $self = shift;
    my $line = shift;

    return $self->_get_generic_response(
        msg    => $line,
        sets   => \@TAEB::ScreenScraper::prompts,
        method => "respond",
    );
}

sub get_location_request {
    my $self = shift;
    my $line = shift;

    return $self->_get_generic_response(
        msg    => $line,
        sets   => \@TAEB::ScreenScraper::location_requests,
        method => "location",
    );
}

sub menu_select {
    my $self = shift;
    my $name = shift;
    my @args = @_;
    my $num  = 0;

    return sub {
        my $slot = shift;
        my $item = $_;

        if ($num++ == 0) {
            for my $responder ($self->responders) {
                if (my $method = $responder->can("begin_select_$name")) {
                    $method->($responder, @args);
                }
            }
        }

        for my $responder ($self->responders) {
            if (my $method = $responder->can("select_$name")) {
                my $rt = $method->($responder, $slot, $item, @args);

                return ref($rt) ? $$rt : $rt ? 'all' : undef;
            }
        }

        return;
    };
}

sub single_select {
    my $self = shift;
    my $name = shift;

    for my $responder ($self->responders) {
        if (my $method = $responder->can("single_$name")) {
            return $method->($responder, $name);
        }
    }

    return;
}

sub responders { grep { defined } TAEB->ai, TAEB->action }

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 get_exceptional_response Str -> Maybe Str

This is used to check all messages for exceptions. Such as not having an item
we expected to have.

If no response is given, C<undef> is returned.

=head2 get_response Str -> Maybe Str

This is used to check for and get a response to any known prompt on the top
line. Consulted are the AI and action.

If no response is given, C<undef> is returned.

=head2 get_location_response Str -> Maybe Tile

This is used to respond to requests to choose a tile (controlled teleport, targeting of ball spells, etc).

If no response is given, C<undef> is returned.

=cut

