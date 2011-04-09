package TAEB::Announcement::Monster::VaultGuard;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Monster';

use constant name => 'vault_guard';

has following => (
    is  => 'ro',
    isa => 'Bool',
);

__PACKAGE__->parse_messages(
    "Suddenly, the guard disappears." => {},
    "\"You've been warned, knave!\"" => {},

    "Suddenly one of the Vault's guards enters!" => {
        following => 1,
    },
    qr/"Please (?:drop that gold and )?follow me\."/ => {
        following => 1,
    },
    qr/"I repeat, (?:drop that gold and )?follow me!"/ => {
        following => 1,
    },
);

__PACKAGE__->meta->make_immutable;

1;


