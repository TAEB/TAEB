package TAEB::Announcement::Item::Obtained;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Item';

use constant name => 'got_item';

__PACKAGE__->parse_messages(
    qr/^(?:You have a little trouble lifting )?(. - .*?|\d+ gold pieces?)\.$/ => sub {
        item => TAEB->new_item($1),
    },
);

__PACKAGE__->meta->make_immutable;

1;

