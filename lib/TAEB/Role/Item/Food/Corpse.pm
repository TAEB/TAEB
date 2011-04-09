package TAEB::Role::Item::Food::Corpse;
use Moose::Role;
use TAEB::OO;
with 'TAEB::Role::Item::Food';

has is_forced_verboten => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has estimated_date => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { TAEB->turn },
);

sub failed_to_sacrifice {
    my $self = shift;
    $self->estimated_date(TAEB->turn - 50)
        if $self->estimated_date > TAEB->turn - 50;
}

sub estimate_age {
    my $self = shift;
    my $when = shift || TAEB->turn;
    return $when - $self->estimated_date;
}

sub maybe_rotted {
    my $self = shift;
    my $when = shift || TAEB->turn;

    my $rotted_low = int($self->estimate_age($when) / 29);
    my $rotted_high = int($self->estimate_age($when) / 10);

    if (!defined($self->buc)) {
        $rotted_low -= 2; $rotted_high += 2;
    } elsif ($self->buc eq 'blessed') {
        $rotted_low -= 2; $rotted_high -= 2;
    } elsif ($self->buc eq 'uncursed') {
    } elsif ($self->buc eq 'cursed') {
        $rotted_low += 2; $rotted_high += 2;
    }

    $rotted_high = 10 if $self->is_forced_verboten;

    return 0 if $self->permanent || $self->monster->name eq 'acid blob)';
    TAEB->log->item("in maybe_rotted; " . $rotted_low . "-" . $rotted_high .
        " for " . $self->raw . "(" . $self->estimate_age . ")" .
        $self->is_forced_verboten);

    return 1 if $rotted_low > 5;
    return 0 if $rotted_high <= 5;
    return;
}

sub would_be_rotted {
    my $self     = shift;
    my $distance = shift || 0;

    $self->maybe_rotted(TAEB->turn + ($distance * TAEB->speed / 12));
}

sub same_race {
    my $self = shift;
    return $self->match(cannibal => TAEB->race);
}

sub should_sac {
    my ($self) = @_;

    return 0 if $self->monster->touch_petrifies &&
        !TAEB->equipment->gloves;

    return 0 if $self->monster ne 'acid blob' && $self->estimate_age > 50;

    return 0 if $self->same_race && TAEB->align ne 'Cha';

    return 0 if ($self->unicorn || "") eq TAEB->align;

    return 0 if $self->failed_to_sacrifice;

    return 0 if $self->permanent;

    return 1;
}

sub unicorn {
    my $self = shift;

    return unless $self->monster->name =~ /(.*) unicorn/;

    return 'Law' if $1 eq 'white';
    return 'Neu' if $1 eq 'gray';
    return 'Cha' if $1 eq 'black';

    TAEB->log->item("Bizarrely colored unicorn corpse: " . $self->monster->name,
                    level => 'error');
    return;
}

around is_safely_edible => sub {
    my $orig = shift;
    my $self = shift;
    my %args = @_;

    my $unihorn  = $args{unihorn};
    my $distance = $args{distance};

    my $rotted = $self->would_be_rotted($distance);
    # Don't bother eating food that is clearly rotten
    return 0 if $rotted;
    # and don't risk it without a known-uncursed unihorn
    return 0 if !$unihorn && !defined($rotted);

    # Instant death? No thanks.
    for my $killer (qw/die lycanthropy petrify polymorph slime/) {
        return 0 if $self->$killer;
    }

    # Stun is pretty irritating.
    return 0 if $self->stun;

    # Acidic items deal damage.
    return 0 if $self->acidic && TAEB->hp <= 15;

    # Worst case is Str-dependant and usually milder.
    return 0 if $self->poisonous && !TAEB->senses->poison_resistant
             && TAEB->hp <= 29;

    # Orcs and Cavs can cannibalize and eat pets.
    return 0 if ($self->same_race || $self->aggravate)
             && TAEB->race ne 'Orc'
             && TAEB->role ne 'Cav';

    # Don't eat quantum mechanics if we're already fast
    return 0 if $self->speed_toggle && TAEB->is_fast;

    # Teleportitis is actually pretty good for bots.
    #return 0 if $self->teleportitis && !$self->teleport_control;

    if (!$unihorn) {
        # Don't inflict very bad conditions

        return 0 if $self->hallucination;
        return 0 if $self->poisonous && !TAEB->senses->poison_resistant;
    }

    return $orig->($self, @_);
};

sub beneficial_to_eat {
    my $self = shift;

    return 1 if $self->speed_toggle && !TAEB->is_fast;

    for my $nice (qw/energy gain_level heal intelligence invisibility strength
                     telepathy teleport_control teleportitis/) {
        return 1 if $self->$nice;
    }

    return 1 if $self->reanimates; # eating trolls is useful too

    for my $resist (qw/shock poison fire cold sleep disintegration/) {
        my $prop = "${resist}_resistance";
        my $res  = "${resist}_resistant";
        return 1 if $self->$prop && !TAEB->$res;
    }

    return 0;
}

no Moose::Role;
no TAEB::OO;

1;
