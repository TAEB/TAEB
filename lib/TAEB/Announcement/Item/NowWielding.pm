package TAEB::Announcement::Item::NowWielding;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Item';

has '+item' => (
    default => sub {
        return TAEB->action->isa("TAEB::Action::Wield") ?
            TAEB->action->weapon : TAEB->action->item;
    },
);

has 'welded' => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0,
);

use constant name => 'now_wielding';

__PACKAGE__->parse_messages(
    qr/^(?:The )?(.*?) weld(?: themselves|s itself) to your .*!$/ =>
        sub { welded => 1 },
    qr/^You now wield a.*$/ => sub {},
);

__PACKAGE__->meta->make_immutable;

1;

