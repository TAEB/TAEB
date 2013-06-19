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
        require Carp::REPL;
        1;
    }
    catch {
        if ($_ && @_ && defined($_[0])) {
            # We're dropping into the REPL because of an error from somewhere,
            # but Carp::REPL doesn't load (not installed?).  Report the actual
            # error.
            die @_;
        } else {
            # Otherwise, Carp::REPL just didn't load, so let the user know
            # what's up.
            TAEB->complain($_);
        }
        0;
    };
    return unless $loaded;

    TAEB->display->deinitialize;

    print "\n"
        . "\e[1;37m+"
        . "\e[1;30m" . ('-' x 50)
        . "\e[1;37m[ "
        . "\e[1;36mT\e[0;36mAEB \e[1;36mC\e[0;36monsole"
        . " \e[1;37m]"
        . "\e[1;30m" . ('-' x 12)
        . "\e[1;37m+"
        . "\e[m\n";

    try {
        local $SIG{__WARN__};
        local $SIG{__DIE__};
        local $SIG{INT} = sub { die "Interrupted." };
        Carp::REPL::repl(@_);
    };

    TAEB->display->reinitialize;
}

__PACKAGE__->meta->make_immutable;

1;
