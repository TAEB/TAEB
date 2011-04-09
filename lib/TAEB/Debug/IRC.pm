package TAEB::Debug::IRC;
use Moose;
use TAEB::OO;
with 'TAEB::Role::Config';

has bot => (
    traits => [qw/TAEB::DontInitialize/],
    isa => 'Maybe[TAEB::Debug::IRC::Bot]',
    is  => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
        return unless defined $self->config;
        my $server  = $self->config->{server}  || 'irc.freenode.net';
        my $port    = $self->config->{port}    || 6667;
        my $channel = $self->config->{channel} || '#interhack';
        my $name    = $self->config->{name}    || TAEB->name;

        TAEB->log->irc("Connecting to $channel on $server:$port with nick $name");
        TAEB::Debug::IRC::Bot->new(
            # Bot::BasicBot settings
            server   => $server,
            port     => $port,
            channels => [$channel],
            nick     => $name,
            no_run   => 1,
        );
    },
);

sub msg_character {
    my $self = shift;
    $self->bot->run if $self->bot;
}

# XXX: hack around initialization order stuff until i restructure TAEB::Debug
before initialize => sub {
    my $self = shift;
    require TAEB::Debug::IRC::Bot if defined $self->config;
};

__PACKAGE__->meta->make_immutable;

1;
