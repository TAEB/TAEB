package TAEB::Announcement::Dungeon::Door;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Dungeon';

use constant name => 'door';

# Need to distinguish between opendoor and closeddoor for tile_type
#with 'TAEB::Announcement::Dungeon::Feature' => {
#    tile_type   => 'door',
#    target_type => 'direction',
#};

has state => (
    is       => 'ro',
    isa      => 'Str', # more general than DoorState
    required => 1,
);

has tile => (
    is        => 'ro',
    writer    => '_set_tile',
    isa       => 'TAEB::World::Tile',
    predicate => 'has_tile',
);

sub BUILD {
    my $self = shift;

    my $action = TAEB->action;
    return unless $action->does('TAEB::Action::Role::Direction');

    if (my $tile = $action->target_tile) {
        $self->_set_tile($tile);
    }
);

__PACKAGE__->parse_messages(
    "This door is locked." => {
        state => 'locked',
    },
    "This door resists!" => {
        state => 'resists',
    },
    "The door resists!" => {
        state => 'resists',
    },
    "WHAMMM!!!" => {
        state => 'resists',
    },
    "The door opens." => {
        state => 'just_opened',
    },
    "You succeed in unlocking the door." => {
        state => 'just_unlocked',
    },
    "You succeed in picking the lock." => {
        state => 'just_unlocked',
    },
    "You stop locking the door." => {
        state => 'interrupted_locking',
    },
    "You stop picking the lock." => {
        state => 'interrupted_unlocking',
    },
    "You stop unlocking the door." => {
        state => 'interrupted_unlocking',
    },
);

__PACKAGE__->meta->make_immutable;

1;

