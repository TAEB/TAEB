package TAEB::Announcement::Level::LevelChange;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Level';

use constant name => 'level_change';

has old_level => (
    isa => 'TAEB::World::Level',
    is => 'ro',
    required => 1,
);

has new_level => (
    isa => 'TAEB::World::Level',
    is => 'ro',
    default => sub { TAEB->dungeon->current_level },
);

__PACKAGE__->meta->make_immutable;

1;
