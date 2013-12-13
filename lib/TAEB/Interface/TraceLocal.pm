package TAEB::Interface::TraceLocal;
use Moose;
use TAEB::OO;
use IO::Pty::Easy;

extends 'TAEB::Interface';

my $trace_command;
BEGIN {
    use Config;
    if ($Config::Config{archname} eq 'x86_64-linux') {
        if (!-e 'bin/syscall-tracer') {
            die "Please run 'cc src/syscall-tracer -o bin/syscall-tracer' and try again";
        }
        $trace_command = qq{sudo ./bin/syscall-tracer %d};
    }
    elsif ($Config::Config{archname} eq 'darwin-2level') {
        $trace_command = qq{sudo dtrace -p %d -qn 'syscall::read_nocancel:entry { printf(".\\n") }'};
    }
    else {
        die "Platform $Config::Config{archname} not supported";
    }
}

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

has trace => (
    is     => 'ro',
    writer => '_set_trace',
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

    open my $handle, '-|', sprintf($trace_command, $pid)
        or die "unable to launch tracer ($trace_command): $!";
    $self->_set_trace($handle);

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

    # pty needs to be initialized first, since it sets the trace attribute
    my $pty = $self->pty;

    # XXX this isn't quite right - if we issue multiple commands at once (this
    # happens during check functions, for instance - '@@' checks autopickup,
    # etc), we'll queue up multiple 'read' events. we need to actually do this
    # non-blockingly.
    my $handle = $self->trace;
    chomp(my $discard = <$handle>);

    # We already waited for output to arrive; don't wait even longer if there
    # isn't any. Use an appropriate reading function depending on the class.
    # Don't just recurse, because that will make us recheck the trace status
    # every time.
    my $out = '';
    while (my $next = $pty->read(0, 1024)) {
        last if !defined $next;
        $out .= $next;
        # We specified blocks of 1024 characters above. If we got exactly 1024,
        # read more.
        last if length($next) < 1024;
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

TAEB::Interface::TraceLocal - Wait for input using DTrace or ptrace

=cut


