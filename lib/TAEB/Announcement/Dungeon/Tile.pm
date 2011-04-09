package TAEB::Announcement::Dungeon::Tile;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement';

# We can't use TAEB->current_tile directly here, because when the
# screenscraper sends an announcement meaning the 'current tile',
# we don't know what the current tile is yet. We could update this
# lazily, but that's semantically incorrect; instead, the value undef
# for current_tile here means 'the current tile, once we know what it
# is', and the reader allows for this. This implementation assumes that
# we won't move between sending an announcement and receiving it, but
# avoiding that would mean that announcements would need to respond to
# other announcements.
has tile => (
    is  => 'ro',
    isa => 'TAEB::World::Tile',
);

around tile => sub {
    my $orig = shift;
    my $self = shift;
    # no need to worry about arguments, this is an ro attribute
    my $tile = $orig->();
    return $tile if $tile;
    return TAEB->current_tile;
};

__PACKAGE__->meta->make_immutable;

1;

