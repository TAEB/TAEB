package TAEB::Interface::Telnet;
use Moose;
use TAEB::OO;
use IO::Socket::Telnet::HalfDuplex;

extends 'TAEB::Interface';

has server => (
    is      => 'ro',
    isa     => 'Str',
    default => 'nethack.alt.org',
);

has port => (
    is      => 'ro',
    isa     => 'Int',
    default => 23,
);

has account => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has password => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has email => (
    is  => 'ro',
    isa => 'Str',
);

has register => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has socket => (
    is      => 'rw',
    isa     => 'IO::Socket::Telnet::HalfDuplex',
    lazy    => 1,
    default => sub {
        my $self = shift;

        TAEB->log->interface("Connecting to " . $self->server . ".");

        my $socket = IO::Socket::Telnet::HalfDuplex->new(
            PeerAddr => $self->server,
            PeerPort => $self->port,
        );

        die "Unable to connect to " . $self->server . ": $!"
            if !defined($socket);

        TAEB->log->interface("Connected to " . $self->server . ".");

        $socket->telnet_simple_callback(\&telnet_negotiation);

        return $socket;
    },
);

has send_rcfile => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

has sent_login => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

augment read => sub {
    my $self = shift;

    my $buffer = $self->socket->read;

    if (!$self->sent_login && $buffer =~ /Not logged in\./) {
        if ($self->register) {
            $self->create_account;
        }
        else {
            $self->login;
        }

        # Now we need to eat up all the input so far, so that later when we
        # wait for the options menu, we can be sure we've left the options menu
        # We use a scratch buffer on the off-chance the text is split across
        # two packets.
        my $scratch = '';

        1 until ($scratch .= $self->read) =~ /Logged in as:/;
        # We need to grab the whole menu so we can look at it.
        1 until ($scratch .= $self->read) =~ /q\) Quit/;

        # We need to select which game to play on some servers,
        # but not on others.
        if ($scratch =~ m/p\) Play NetHack/) {
            # NetHack played from the main menu
            TAEB->log->interface("This server seems to play NetHack from ".
                                 "the main menu.");
            $self->sent_login(1);
            $self->send_options;

            # Play the game
            $self->write('p');
        } elsif ($scratch =~ /(\d)\) Go to NetHack/) {
            # NetHack played from a submenu
            # TODO: pick a particular version of NetHack if more than one is
            # offered by the server in question
            my $submenu = $1;
            TAEB->log->interface("This server seems to play NetHack from ".
                                 "submenu $submenu.");
            $self->sent_login(1);

            # Select submenu
            $self->write($submenu);
            # Absorb input until the submenu comes up. In particular, we need
            # to absorb the "Logged in as:" so that send_options can tell
            # that virus has quit.
            $scratch = '';
            1 until ($scratch .= $self->read) =~ /Edit options for/;

            $self->send_options;

            # Play the game. We're back on the game submenu now.
            $self->write('p');
        } else {
            my $server = $self->server;
            die "Could not figure out how server $server plays NetHack";
        }
    }

    return $buffer;
};

augment write => sub {
    my $self = shift;
    print {$self->socket} join '', @_;
};

sub telnet_negotiation {
    my $self = shift;
    my $option = shift;

    if ($option =~ / 99$/) {
        return '';
    }

    TAEB->log->interface("Telnet negotiation: received $option");

    if ($option =~ /DO TTYPE/) {
        return join '',
               chr(255), # IAC
               chr(251), # WILL
               chr(24),  # TTYPE

               chr(255), # IAC
               chr(250), # SB
               chr(24),  # TTYPE
               chr(0),   # IS
               "xterm-color",
               chr(255), # IAC
               chr(240), # SE
    }

    if ($option =~ /DO NAWS/) {
        return join '',
               chr(255), # IAC
               chr(251), # WILL
               chr(31),  # NAWS

               chr(255), # IAC
               chr(250), # SB
               chr(31),  # NAWS
               chr(0),   # IS
               chr(80),  # 80
               chr(0),   # x
               chr(24),  # 24
               chr(255), # IAC
               chr(240), # SE
    }

    return;
}

sub send_options {
    my $self = shift;

    if ($self->send_rcfile) {
        # Clear existing options
        $self->write(
            'o',
            ":0,\$d\n",
            "i",
        );

        # Send nethackrc
        $self->write(TAEB::Config->nethackrc_contents);

        # Exit virus
        $self->write(
            "\e",
            ":wq\n",
        );

        # Now we need to wait until we're back on the dgamelaunch menu.
        # virus eats the "p" key to start the game if we don't wait.
        # We use a scratch buffer on the off-chance the text is split across
        # two packets.
        my $scratch = '';
        1 until ($scratch .= $self->read) =~ /Logged in as:/;
    }
}

sub login {
    my $self = shift;
    TAEB->log->interface("Logging in as " . $self->account);

    # Initiate login, send account name
    $self->write(
        'l',
        $self->account, "\n",
    );

    # We don't want the password in the logs, so we don't send it to
    # TAEB-level methods (which log)
    TAEB->log->log_to_channel(output => "Sending password to NetHack.");
    print { $self->socket } $self->password, "\n";
}

sub create_account {
    my $self = shift;

    $self->write(
        'r',
        $self->account, "\n",
    );

    # We don't want the password in the logs, so we don't send it to
    # TAEB-level methods (which log)
    TAEB->log->log_to_channel(output => "Sending password to NetHack.");
    print { $self->socket } $self->password, "\n";
    print { $self->socket } $self->password, "\n";

    $self->write(
        $self->email, "\n",
    );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::Interface::Telnet - how TAEB talks to nethack.alt.org

=head1 METHODS

=head2 read -> STRING

This will read from the socket. It will die if an error occurs.

It will return the input read from the socket.

This uses a method developed for nhbot that ensures that we've received all
output for our command before returning. Just before reading, it sends the
telnet equivalent of a PING. It then reads all input until it gets a PONG. the
idea is that the PING comes after all NH commands, so the PONG must come after
all the output of all the NH commands. The code looking for the PONG is in
the telnet complex callback.

The actual ping it uses is to send IAC DO chr(99), which is a nonexistent
option. Some servers may stop responding after the first IAC DO chr(99), so
it's kind of a bad hack. It used to be IAC SB STATUS SEND IAC SE but NAO
stopped paying attention to that. That last sentence was discovered over a few
hours of debugging. Yay.

=head2 write STRING

This will write to the socket.

=head2 telnet_negotiation OPTION

This is a helper function used in conjunction with IO::Socket::Telnet. In
short, all nethack.alt.org expects us to answer affirmatively is TTYPE (to
which we respond xterm-color) and NAWS (to which we respond 80x24). Everything
else gets a response of DONT or WONT.

=cut

