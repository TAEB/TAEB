package TAEB::World::Spell;
use Moose;
use TAEB::OO;
use TAEB::Util qw/max min/;

with 'TAEB::Role::Overload';

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has learned_at => (
    is       => 'rw',
    isa      => 'Int',
    default  => sub { TAEB->turn },
);

has fail => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

has slot => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has spoiler => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $self = shift;
        NetHack::Item::Spoiler->spoiler_for("spellbook of " . $self->name);
    },
);

has casted_count => (
    is  => 'rw',
    isa => 'Int',
);

for my $attribute (qw/level read marker role emergency skill/) {
    __PACKAGE__->meta->add_method($attribute => sub {
        my $self = shift;
        $self->spoiler->{$attribute};
    });
}

sub castable {
    my $self = shift;

    return 0 if $self->forgotten;
    return 0 if $self->power > TAEB->power;
    return 0 if $self->fail == 100;

    # "You are too hungry to cast!" (detect food is exempted by NH itself)
    return 0 if TAEB->nutrition <= 10 && $self->name ne 'detect food';

    return 1;
}

sub failure_rate {
    my $self = shift;
    my %penalties = (
        Arc => {
            base => 5,  emergency =>  0, shield => 2, suit => 10, stat => 'int'
        },
        Bar => {
            base => 14, emergency =>  0, shield => 0, suit => 8,  stat => 'int'
        },
        Cav => {
            base => 12, emergency =>  0, shield => 1, suit => 8,  stat => 'int'
        },
        Hea => {
            base => 3,  emergency => -3, shield => 2, suit => 10, stat => 'wis'
        },
        Kni => {
            base => 8,  emergency => -2, shield => 0, suit => 9,  stat => 'wis'
        },
        Mon => {
            base => 8,  emergency => -2, shield => 2, suit => 20, stat => 'wis'
        },
        Pri => {
            base => 3,  emergency => -3, shield => 2, suit => 10, stat => 'wis'
        },
        Ran => {
            base => 9,  emergency =>  2, shield => 1, suit => 10, stat => 'int'
        },
        Rog => {
            base => 8,  emergency =>  0, shield => 1, suit => 9,  stat => 'int'
        },
        Sam => {
            base => 10, emergency =>  0, shield => 0, suit => 8,  stat => 'int'
        },
        Tou => {
            base => 5,  emergency =>  1, shield => 2, suit => 10, stat => 'int'
        },
        Val => {
            base => 10, emergency => -2, shield => 0, suit => 9,  stat => 'wis'
        },
        Wiz => {
            base => 1,  emergency =>  0, shield => 3, suit => 10, stat => 'int'
        },
    );

    my %aspect = (
        shield    => TAEB->equipment->shield,
        cloak     => TAEB->equipment->cloak,
        helmet    => TAEB->equipment->helmet,
        gloves    => TAEB->equipment->gloves,
        boots     => TAEB->equipment->boots,
        bodyarmor => TAEB->equipment->bodyarmor,
        int       => TAEB->senses->int,
        wis       => TAEB->senses->wis,
        level     => TAEB->level,

        @_
    );

    use integer;

    # start with base penalty
    my $penalty = $penalties{TAEB->role}->{base};

    # Inventory penalty calculation
    # first the shield!
    $penalty += $penalties{TAEB->role}->{shield}
             if defined $aspect{shield};
    # body armor, complicated with the robe
    if (defined $aspect{bodyarmor}) {
        my $suit_penalty = 0;
        $suit_penalty = $penalties{TAEB->role}->{suit}
                      if $aspect{bodyarmor}->is_metallic;
        # if wearing a robe, either halve the suit penalty or negate completely 
        if (defined $aspect{cloak}
           && $aspect{cloak}->name eq 'robe') {
            if ($suit_penalty > 0) {
                $suit_penalty /= 2;
            }
            else {
                $suit_penalty = -($penalties{TAEB->role}->{suit});
            }
        }
        $penalty += $suit_penalty;
    }
    # metallic helmet, except if HoB
    $penalty += 4 if defined $aspect{helmet}
                  && $aspect{helmet}->is_metallic
                  && $aspect{helmet}->name ne 'helm of brilliance';
    # metallic gloves
    $penalty += 6 if defined $aspect{gloves}
                  && $aspect{gloves}->is_metallic;
    # metallic boots
    $penalty += 2 if defined $aspect{boots}
                  && $aspect{boots}->is_metallic;

    $penalty += $penalties{TAEB->role}->{emergency} if $self->emergency;
    $penalty -= 4 if ($self->role || '') eq TAEB->role;

    my $chance;
    my $SKILL = 0; # XXX: this needs to reference skill levels
    my $statname = $penalties{TAEB->role}->{stat};
    my $basechance = $aspect{$statname} * 11 / 2;
    my $diff = (($self->level - 1) * 4 -
        ($SKILL * 6 + ($aspect{level} / 3) + 1));
    if ($diff > 0) {
        $chance = $basechance - sqrt(900 * $diff + 2000);
    }
    else {
        my $learning = -15 * $diff / $self->level;
        $chance = $basechance + min($learning, 20);
    }

    $chance = max(min($chance, 120), 0);

    # shield and special spell
    if (defined $aspect{shield}
       && $aspect{shield}->name ne 'small shield') {
        if (($self->role || '') eq TAEB->role) {
            # halve chance if special spell
            $chance /= 2;
        }
        else {
            # otherwise quarter chance
            $chance /= 4;
        }
    }

    $chance = $chance * (20 - $penalty) / 15 - $penalty;
    $chance = max(min($chance, 100), 0);

    # The internal NetHack code returns success, but we (to be more
    # understandable to players) want to return failure.

    $chance = 100 - $chance;

    return $chance;
}

sub forgotten {
    my $self = shift;
    return TAEB->turn > $self->learned_at + 20_000;
}

sub debug_line_noslot {
    my $self = shift;

    return join ' ',
            $self->name,
            $self->fail . '%',
            ($self->damage_range ? ("[" . (join "-", $self->damage_range) . "]") : ()),
            "cast " . ($self->casted_count || 0) . "x",
            "(learned T" . $self->learned_at . ")";
}

sub debug_line {
    my $self = shift;

    return $self->slot . ' - ' . $self->debug_line_noslot;
}

sub power { 5 * shift->level }

sub did_cast {
    my $self = shift;
    $self->casted_count(($self->casted_count || 0) + 1);
}

# I'm going by zap.c:2470
# (void) bhit(u.dx,u.dy, rn1(8,6),ZAPPED_WAND, bhitm,bhito, obj);
sub minimum_range { 6 }
sub maximum_range { 13 }

sub damage_range {
    my $self = shift;
    return unless $self->skill eq 'attack';

    my $name = $self->name;

    my ($base_min, $base_max);

    if ($name eq 'force bolt') {
        ($base_min, $base_max) = (2, 24);
    }
    elsif ($name eq 'drain life') {
        ($base_min, $base_max) = (1, 8);
    }
    elsif ($name eq 'fireball') {
        # no modifiers
        return (12, 72);
    }
    elsif ($name eq 'finger of death') {
        # no damage
        return;
    }
    else { # magic missile, cone of cold
        my $spell_damage = int(TAEB->level / 2) + 1;
        $base_min = $spell_damage;
        $base_max = $spell_damage * 6;
    }

    my $mod = 0;
    my $int = TAEB->int;
    $mod = -3 if $int < 10;

    if (TAEB->level > 4) {
        $mod++ if $int >= 14;
        $mod++ if $int > 18;
    }

    return ($base_min + $mod, $base_max + $mod);
}

sub direction {
    my $self = shift;

    my $direction = $self->spoiler->{direction}
        or return;

    # most spells have a single, constant direction
    if (!ref($direction)) {
        return $direction;
    }

    # some spells (cone of cold, fireball) vary based on skill in the spell
    my $skill = $self->skill;
    my $level = lc TAEB->senses->level_for_skill($skill);

    return $direction->{$level};
}

sub nutrition {
    my $self = shift;

    # detect food doesn't make us hungry
    return 0 if $self->name eq 'detect food';

    my $nutrition = TAEB->nutrition;

    # in the future, let's check to see how much we actually spent (Amulet of
    # Yendor)
    my $energy = 5 * $self->power;
    my $hunger = 2 * $energy;

    if (TAEB->role eq 'Wiz') {
           if (TAEB->int >= 17) { $hunger = 0 }
        elsif (TAEB->int == 16) { $hunger = int($hunger / 4) }
        elsif (TAEB->int == 15) { $hunger = int($hunger / 2) }
    }

    if ($hunger > $nutrition - 3) {
        $hunger = $nutrition - 3;
    }

    return $hunger;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 castable

Can this spell be cast this turn? This does not only take into account spell
age, but also whether you're confused, have enough power, etc.

=cut

