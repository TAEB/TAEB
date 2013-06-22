package TAEB::AI::Util::Food::Corpse;
use strict;
use warnings;

use Sub::Exporter -setup => {
    exports => [ qw(beneficial_to_eat) ],
};

sub beneficial_to_eat {
    my $item = shift;

    return 1 if $item->speed_toggle && !TAEB->is_fast;

    for my $nice (qw/energy gain_level heal intelligence invisibility strength
                     telepathy teleport_control/) {
        return 1 if $item->$nice;
    }

    return 1 if $item->reanimates; # eating trolls is useful too

    for my $resist (qw/shock poison fire cold sleep disintegration/) {
        my $prop = "${resist}_resistance";
        my $res  = "${resist}_resistant";
        return 1 if $item->$prop && !TAEB->senses->$res;
    }

    return 0;
}


1;
