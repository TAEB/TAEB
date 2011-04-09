package TAEB::Announcement::Debt;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement';

has amount => (
    is       => 'ro',
    isa      => 'Maybe[Int]',
    required => 1,
);

__PACKAGE__->parse_messages(
    '"You bit it, you bought it!"' => {
        amount => undef,
    },
    qr/ \(unpaid, \d+ zorkmids?\)/ => sub {
        amount => undef,
    },

    "You have no credit or debt in here." => {
        amount => 0,
    },
    "You don't owe any money here." => {
        amount => 0,
    },
    "There appears to be no shopkeeper here to receive your payment." => {
        amount => 0,
    },
    qr/^You do not owe .* anything\./ => {
        amount => 0,
    },

    qr/^You owe .*? (\d+) zorkmids?\./ => sub {
        amount => $1,
    },
    qr/^"Usage fee, (\d+) zorkmids?\."/ => sub {
        amount => $1,
    },
);

__PACKAGE__->meta->make_immutable;

1;


