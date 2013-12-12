package TAEB::Interface::DTraceLocal;
use Moose;
use TAEB::OO;
use IO::Pty::Easy;

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
    isa     => 'IO::Pty::Easy',
    lazy    => 1,
    handles => ['is_active'],
    builder => '_build_pty',
);

has dtrace => (
    is     => 'ro',
    writer => '_set_dtrace',
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
    my $pty = IO::Pty::Easy->new(handle_pty_size => 0);
    $pty->spawn($self->name, $self->args);

    my $pid = $pty->pid;

    open my $handle, qq{sudo dtrace -p $pid -qn 'syscall::read_nocancel:entry { printf(".\\n") }' |}
        or die "unable to launch DTrace: $!";
    $self->_set_dtrace($handle);

    return $pty;
}

sub wait_for_termination {
    my $self = shift;
    my $pty = $self->pty;
    $pty->read(2); # give it time to save
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
    $pty->read(3);
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
        $pty->read(3);
        return unless $pty->is_active;
        $wait -= 3;
    }
    TAEB->log->input("Killing a hanging process...");
    print "The NetHack process appears to be hanging, killing it...\n";
    $pty->close;
}

augment read => sub {
    my $self = shift;

    my $handle = $self->dtrace;
    my $discard = <$handle>;

    # We already waited for output to arrive; don't wait even longer if there
    # isn't any. Use an appropriate reading function depending on the class.
    my $out = $self->pty->read(0,1024);
    return '' if !defined($out);

    # We specified blocks of 1024 characters above. If we got exactly 1024,
    # read more.
    if (length($out) == 1024) {
        return $out . $self->read(@_);
    }

    return $out;
};

augment write => sub {
    my $self = shift;

    my $chars = $self->pty->write((join '', @_), 1);
    return if !defined($chars);

    # An IPE counts the number of chars written; an IPH doesn't,
    # because writes are delayed-action in such a case.
    die "Pty closed" if $chars == 0;
    return $chars;
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::Interface::DTraceLocal - Wait for input using DTrace

=cut


