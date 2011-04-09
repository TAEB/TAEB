package TAEB::Interface::SSH;
use Moose;
use TAEB::OO;
use Try::Tiny;

use constant ping_wait => .3;

extends 'TAEB::Interface::OldLocal';

has server => (
    is      => 'ro',
    isa     => 'Str',
    default => 'devnull.kraln.com',
);

has account => (
    is  => 'ro',
    isa => 'Str',
);

has password => (
    is  => 'ro',
    isa => 'Str',
);

sub _build_pty {
    my $self = shift;

    TAEB->log->interface("Connecting to " . $self->server . ".");

    my $pty = IO::Pty::Easy->new;
    $pty->spawn('ssh', $self->server, '-l', $self->account);

    alarm 20;
    try {
        local $SIG{ALRM} = sub { die "timeout" };

        my $output = '';
        while (1) {
            $output .= $pty->read(0) || '';
            if ($output =~ /password/) {
                alarm 0;
                last;
            }
        }
    }
    catch {
        die "Died while waiting for password prompt: $_\n";
    };

    $pty->write($self->password . "\n\n", 0);

    TAEB->log->interface("Connected to " . $self->server . ".");

    return $pty;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::Interface::SSH - how TAEB talks to /dev/null

=cut

