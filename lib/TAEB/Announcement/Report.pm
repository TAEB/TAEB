package TAEB::Announcement::Report;
use Moose;
use TAEB::OO;
use TAEB::Util 'max';
extends 'TAEB::Announcement';

use overload (
    q{""}    => 'as_string',
    fallback => 1,
);

sub as_string {
    my $report = inner;

    return $report;
}

__PACKAGE__->meta->make_immutable;

1;

