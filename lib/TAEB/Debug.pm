package TAEB::Debug;
use Moose;
use TAEB::OO;
use TAEB::Debug::Console;
use TAEB::Debug::Map;
use TAEB::Debug::Sanity;

has console => (
    is      => 'ro',
    isa     => 'TAEB::Debug::Console',
    default => sub { TAEB::Debug::Console->new },
);

has sanity => (
    is      => 'ro',
    isa     => 'TAEB::Debug::Sanity',
    default => sub { TAEB::Debug::Sanity->new },
);

has debug_map => (
    is      => 'ro',
    isa     => 'TAEB::Debug::Map',
    default => sub { TAEB::Debug::Map->new },
);

__PACKAGE__->meta->make_immutable;

1;
