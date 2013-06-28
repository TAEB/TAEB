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

has existing_item => (
    is     => 'ro',
    writer => '_set_existing_item',
    isa    => 'NetHack::Item',
);

sub BUILD {
    my $self = shift;
    my $item = $self->item;

    return unless $item->slot;

    my $existing = TAEB->inventory->get($item->slot);
    return unless $existing;

    $self->_set_existing_item($existing);
}

__PACKAGE__->meta->make_immutable;

1;

