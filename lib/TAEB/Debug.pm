package TAEB::Debug;
use Moose;
use TAEB::OO;
use TAEB::Debug::Console;
use TAEB::Debug::Map;
use TAEB::Debug::Sanity;
use TAEB::Debug::Watch;

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

has map => (
    is      => 'ro',
    isa     => 'TAEB::Debug::Map',
    default => sub { TAEB::Debug::Map->new },
);

has watch => (
    is      => 'ro',
    isa     => 'TAEB::Debug::Watch',
    default => sub { TAEB::Debug::Watch->new },
);

__PACKAGE__->meta->make_immutable;

1;
