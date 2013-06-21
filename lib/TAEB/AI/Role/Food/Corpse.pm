package TAEB::AI::Role::Food::Corpse;
use Moose::Role;
use TAEB::OO;

sub beneficial_to_eat {
    my $self = shift;

    return 1 if $self->speed_toggle && !TAEB->is_fast;

    for my $nice (qw/energy gain_level heal intelligence invisibility strength
                     telepathy teleport_control/) {
        return 1 if $self->$nice;
    }

    return 1 if $self->reanimates; # eating trolls is useful too

    for my $resist (qw/shock poison fire cold sleep disintegration/) {
        my $prop = "${resist}_resistance";
        my $res  = "${resist}_resistant";
        return 1 if $self->$prop && !TAEB->senses->$res;
    }

    return 0;
}

no Moose::Role;
no TAEB::OO;

1;
