package TAEB::Announcement::Item::ContainerNoItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Item';

has '+item' => (
    isa => 'NetHack::Item::Tool::Container',
);

use constant name => 'container_noitems';

__PACKAGE__->parse_messages(
    qr/The (.*) is empty\./ => {},
);

__PACKAGE__->meta->make_immutable;
no Moose;

1;
