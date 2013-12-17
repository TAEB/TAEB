package TAEB::Debug::Console;
use Moose;
use TAEB::OO;
use Try::Tiny;
with 'TAEB::Role::Config';

TAEB->register_debug_commands(
    '~' => {
        help    => "Debug console",
        command => sub { TAEB->debugger->console->repl(undef) },
    },
);

sub repl {
    my $self = shift;

    # Term::ReadLine seems to fall over on $ENV{PERL_RL} = undef?
    $ENV{PERL_RL} ||= $self->config->{readline}
        if $self->config && exists $self->config->{readline};

    # using require doesn't call import, so no die handler is installed
    my $loaded = try {
        local $SIG{__DIE__};
        require Carp::Reply;
        1;
    }
    catch {
        if ($_ && @_ && defined($_[0])) {
            # We're dropping into the REPL because of an error from somewhere,
            # but Carp::Reply doesn't load (not installed?).  Report the actual
            # error.
            die @_;
        } else {
            # Otherwise, Carp::Reply just didn't load, so let the user know
            # what's up.
            TAEB->complain($_);
        }
        0;
    };
    return unless $loaded;

    TAEB->display->deinitialize(no_clear => 1);

    print "\e[13;1H"
        . "\e[1;37m" . "+"
        . "\e[1;30m" . ('-' x 50)
        . "\e[1;37m" . "[ "
        . "\e[1;36m" . "T"
        . "\e[0;36m" . "AEB "
        . "\e[1;36m" . "C"
        . "\e[0;36m" . "onsole "
        . "\e[1;37m" . "]"
        . "\e[1;30m" . ('-' x 12)
        . "\e[1;37m" . "+"
        . "\e[m"
        . "\e[1;12r"
        . "\e[12;1H"
        . "\e[1J";

    try {
        local $SIG{__WARN__};
        local $SIG{__DIE__};
        local $SIG{INT} = sub { die "Interrupted." };
        Carp::Reply::repl(1);
    };

    print "\e[1;25r";

    TAEB->display->reinitialize;
}

__PACKAGE__->meta->make_immutable;

1;
