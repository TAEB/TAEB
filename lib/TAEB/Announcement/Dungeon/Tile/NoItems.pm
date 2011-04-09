package TAEB::Announcement::Dungeon::Tile::NoItems;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon::Tile';

use constant name => 'tile_noitems';

__PACKAGE__->parse_messages(
    "There is nothing here to pick up." => {},
    qr/^You (?:see|feel) no objects here\./ => {},

    # Can this be made better in the Age of Announcements?
#    [
#        # NetHack will not send "There are no items here." if there is a
#        # terrain feature at the current location.  To work around this, we
#        # need to clear the floor on receiving notices of terrain... HOWEVER
#        # if there were a lot of items, we handle menus before messages.  To
#        # avoid a big mess, we skip the clear in that case.
#        qr/^There is (?:molten lava|ice|an? .*) here.$/,
#            [sub { TAEB->scraper->saw_floor_list_this_step ?
#                       '' : 'clear_floor' }],  # is this the best way?
#    ],
);

__PACKAGE__->meta->make_immutable;

1;

