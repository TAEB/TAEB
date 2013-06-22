package TAEB::Interface::Local;
use Moose;
use TAEB::OO;
use IO::Pty::HalfDuplex;

extends 'TAEB::Interface';

has name => (
    is      => 'ro',
    isa     => 'Str',
    default => 'nethack',
);

has args => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        args => 'elements',
    },
);

has pty => (
    traits  => [qw/TAEB::Meta::Trait::DontInitialize/],
    is      => 'ro',
    isa     => 'IO::Pty::HalfDuplex',
    lazy    => 1,
    handles => ['is_active'],
    builder => '_build_pty',
);

sub _build_pty {
    my $self = shift;

    chomp(my $pwd = `pwd`);

    my $rcfile = TAEB->config->taebdir_file('nethackrc');

    # Always rewrite the rcfile, in case we've updated it. We may want to
    # compare checksums instead, but whatever, we can worry about that later.
    open my $fh, '>', $rcfile or die "Unable to open $rcfile for writing: $!";
    $fh->write(TAEB->config->nethackrc_contents);
    close $fh;

    local $ENV{NETHACKOPTIONS} = '@' . $rcfile;
    local $ENV{TERM} = 'xterm-color';

    # TAEB requires 80x24
    local $ENV{LINES} = 24;
    local $ENV{COLUMNS} = 80;

    # set Pty to ignore SIGWINCH so that we don't confuse nethack if
    # controlling terminal is not set to 80x24
    my $pty = IO::Pty::HalfDuplex->new(handle_pty_size => 0);

    $pty->spawn($self->name, $self->args);
    return $pty;
}

augment read => sub {
    my $self = shift;

    die "Pty inactive" unless $self->is_active;

    # We already waited for output to arrive; don't wait even longer if there
    # isn't any. Use an appropriate reading function depending on the class.
    return $self->pty->recv;
};

sub flush { shift->pty->recv(2); }

sub wait_for_termination {
    my $self = shift;
    my $pty = $self->pty;
    $pty->recv(2); # give it time to save
    return unless $pty->is_active;
    TAEB->log->input("Trying to handle unclean NetHack shutdown...");
    # Send NetHack a SIGHUP first in case we turn out not to have sent a
    # save/quit command after all; this is just sanity, really. NetHack
    # puts up a confirm message on SIGINT, but exits immediately on SIGHUP.
    $pty->kill(HUP => 0);
    # Failing that, it may be stuck in a lockfile loop, in which case we
    # don't want to kill it until it's found the lock it needs. (This could
    # theoretically happen on a heavy-traffic computer, and could also
    # happen trying to save high-scores if there are incorrectly-terminated
    # NetHack process around. The trick here is that NetHack will print a
    # message every second, /without waiting for input/, if the lockfile
    # is stuck; and in such cases, we don't want to kill the process
    # because the dumpfile is halfway through being written. So how do
    # we distinguish between the possible cases? Well, either NetHack's
    # finished a SIGHUP save already, or was just being slow saving
    # beforehand, or is in a record_lock loop. We ask for a read with a
    # 3-second timeout, then see if the process has ended; if it's
    # ended, then it's finished saving, and otherwise it's waiting for
    # its record file.
    $pty->recv(3);
    return unless $pty->is_active;
    # NetHack will wait for up to a minute to get its lockfile. We've
    # waited 5 seconds already; let's wait another 66 just to be sure,
    # notifying the user as to why there's such an unusually long wait.
    TAEB->display->deinitialize if defined TAEB->display;
    my $wait = 66;
    while($wait > 0) {
        TAEB->log->input("Waiting for termination ($wait seconds remaining)...");
        print "Something went wrong when NetHack tried to save.\n";
        print "Waiting up to another $wait seconds...   \n";
        $pty->recv(3);
        return unless $pty->is_active;
        $wait -= 3;
    }
    TAEB->log->input("Killing a hanging process...");
    print "The NetHack process appears to be hanging, killing it...\n";
    $pty->close;
}

augment write => sub {
    my $self = shift;

    die "Pty inactive" unless $self->is_active;

    return $self->pty->write((join '', @_), 1);
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::Interface::Local - how TAEB talks to a local nethack

=head1 METHODS

=head2 read -> STRING

This will read from the pty. It will die if an error occurs.

It will return the input read from the pty.

=head2 flush

When using HalfDuplex, we have to do a recv in order to send data.
If flush is being called, it means that the return value can be
safely ignored.

=head2 write STRING

This will write to the pty. It will die if an error occurs.

=head1 SEE ALSO

L<http://taeb-blog.sartak.org/2009/06/synchronizing-with-nethack.html>

=cut

