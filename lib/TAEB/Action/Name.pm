package TAEB::Action::Name;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item';

use constant command => "#name\n";

has '+item' => (
    required => 1,
);

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    provided => 1,
);

has specific => (
    is       => 'ro',
    isa      => 'Bool',
    default  => 0,
    provided => 1,
);

sub respond_name_specific {
    return 'y' if shift->specific;
    return 'n';
}

sub respond_name_what {
    return shift->item->slot;
}

sub respond_name {
    return shift->name . "\n";
}

__PACKAGE__->meta->make_immutable;

1;

