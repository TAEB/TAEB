package TAEB::Action::Zap;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with (
    'TAEB::Action::Role::Direction',
    'TAEB::Action::Role::Item' => { items => [qw/wand/] },
);

use constant command => 'z';

has '+wand' => (
    isa      => 'NetHack::Item::Wand',
    required => 1,
);

sub respond_zap_what    { shift->wand->slot }
sub msg_wrest_wand      { TAEB->inventory->remove(shift->wand->slot) }
sub done                { shift->wand->spend_charge }

subscribe nothing_happens => sub { shift->wand->charges(0) };

__PACKAGE__->meta->make_immutable;

1;

