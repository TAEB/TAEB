package TAEB::Action::Write;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item' => { items => [qw/marker onto/] };

use constant command => "a";

has '+marker' => (
    isa      => 'NetHack::Item',
    required => 1,
);

has '+onto' => (
    isa      => 'NetHack::Item',
    required => 1,
);

has identity => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    provided => 1,
);

sub respond_apply_what    { shift->marker->slot }
sub respond_write_on_what { shift->onto->slot }
sub respond_write_what    { shift->identity . "\n" }

1;

