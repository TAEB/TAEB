package TAEB::Debug::IRC::Bot;
use Moose;
use TAEB::OO;
use MooseX::NonMoose;
use Time::HiRes qw/time/;
# POE::Kernel and POE::Component::IRC use eval/die a bunch without
# localizing it
BEGIN {
    local $SIG{__DIE__};
    require POE::Kernel;
    POE::Kernel->import;
}
{
    local $SIG{__DIE__};
    extends 'Bot::BasicBot';
}

with 'TAEB::Debug::Bot';

sub speak {
    my $self = shift;
    my $msg  = shift;

    $self->say(
        channel => $self->channels,
        body    => $msg,
    );
}

# XXX: we use this instead of calling run, and poe whines loudly if run is
# never called, assuming it's a bug. the standard fix is to call
# $poe_kernel->run before starting any sessions; the poe docs say it should
# just return immediately. this used to work, but now just hangs inside the
# call to ->run and i have no idea why, so i just removed it - so now we get an
# annoying warning when taeb exits. if anyone wants to look into this, that
# would be sweet. -doy
sub tick {
    my $self = shift;

    TAEB->log->irc("Iterating the IRC component");

    do {
        TAEB->log->irc("IRC: running a timeslice at ".time);
        local $SIG{__DIE__};
        $self->schedule_tick(0.05);
        $poe_kernel->run_one_timeslice;
    } while ($poe_kernel->get_next_event_time - time < 0);
}

sub said {
    my $self = shift;
    my %args = %{ $_[0] };
    return unless $args{address};

    TAEB->log->irc("Somebody is talking to us! ($args{who}, $args{body})");
    return $self->response_to($args{body});
}

sub log { ## no critic (ProhibitBuiltinHomonyms)
    my $self = shift;
    for (@_) {
        chomp;
        TAEB->log->irc($_);
    }
}

__PACKAGE__->meta->make_immutable;

1;
