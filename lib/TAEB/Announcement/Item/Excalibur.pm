package TAEB::Announcement::Item::Excalibur;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Item';

use constant name => 'excalibur';

has '+item' => (
    default => sub { TAEB->action->item },
);

__PACKAGE__->parse_messages(
    "From the murky depths, a hand reaches up to bless the sword." => {}
);

__PACKAGE__->meta->make_immutable;

1;
