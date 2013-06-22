package TAEB::Senses;
use Moose;
use TAEB::OO;

has name => (
    is  => 'rw',
    isa => 'Str',
);

has role => (
    is  => 'rw',
    isa => 'TAEB::Type::Role',
);

has race => (
    is  => 'rw',
    isa => 'TAEB::Type::Race',
);

has align => (
    is  => 'rw',
    isa => 'TAEB::Type::Align',
);

has gender => (
    is  => 'rw',
    isa => 'TAEB::Type::Gender',
);

has hp => (
    is  => 'rw',
    isa => 'Int',
);

has maxhp => (
    is  => 'rw',
    isa => 'Int',
);

has power => (
    is  => 'rw',
    isa => 'Int',
);

has maxpower => (
    is  => 'rw',
    isa => 'Int',
);

has nutrition => (
    is      => 'rw',
    isa     => 'Int',
    default => 900,
);

has [qw/is_blind is_stunned is_confused is_hallucinating is_lycanthropic is_engulfed is_grabbed is_petrifying is_levitating is_food_poisoned is_ill is_wounded_legs/] => (
    traits  => ['TAEB::DisplayStatus'],
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    trigger => sub {
        my ($self, $old, $new);
        no warnings 'uninitialized';
        return unless (!defined($old) && defined($new))
                   || (!defined($new) && defined($old))
                   || $old != $new;
        $self->_clear_statuses;
    },
);

has [qw/is_fast is_very_fast is_stealthy is_teleporting/] => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has level => (
    is      => 'rw',
    isa     => 'Int',
    default => 1,
);

has prev_turn => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has turn => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has step => (
    is        => 'rw',
    traits    => ['Counter'],
    default   => 0,
    handles   => {
        inc_step => 'inc',
    },
);

has max_god_anger => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has baseluck => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has in_beartrap => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has in_pit => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has in_web => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has str => (
    is      => 'rw',
    isa     => 'Str',
    default => 0,
);

has [qw/dex con int wis cha/] => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has score => (
    is        => 'rw',
    isa       => 'Int',
    predicate => 'has_score',
);

has gold => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has debt => (
    is        => 'rw',
    isa       => 'Int',
    default   => 0,
    predicate => 'known_debt',
    clearer   => '_clear_debt',
);

has [
    qw/poison_resistant cold_resistant fire_resistant shock_resistant sleep_resistant disintegration_resistant/
] => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has following_vault_guard => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has last_seen_nurse => (
    is  => 'rw',
    isa => 'Int',
);

has checking => (
    is      => 'rw',
    isa     => 'Str',
    clearer => 'clear_checking',
    trigger => sub {
        my (undef, $checking) = @_;
        TAEB->log->senses("Checking $checking");
        TAEB->redraw;
    },
);

has last_prayed => (
    is      => 'rw',
    isa     => 'Int',
    default => -400,
);

has autopickup => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has ac => (
    is      => 'rw',
    isa     => 'Int',
    default => 10,
    trigger => sub {
        my ($self, $new, $old) = @_;
        if (defined($old) && defined($new) && $new != $old) {
            TAEB->send_message(check => 'inventory');
        }
    },
);

has burden => (
    is  => 'rw',
    isa => 'TAEB::Type::Burden',
);

has noisy_turn => (
    is  => 'rw',
    isa => 'Int',
);

has polyself => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

has spell_protection => (
    is  => 'rw',
    isa => 'Int',
    default => 0,
);

has death_state => (
    is  => 'rw',
    isa => 'TAEB::Type::DeathState',
    trigger => sub {
        my (undef, $new_state) = @_;
        TAEB->log->senses("Death state is now $new_state.");
        TAEB->display->redraw;
    },
);

has death_report => (
    traits  => [qw/TAEB::Meta::Trait::DontInitialize/],
    is      => 'ro',
    isa     => 'TAEB::Announcement::Report::Death',
    lazy    => 1,
    default => sub { TAEB::Announcement::Report::Death->new },
);

has is_friday_13th => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has is_new_moon => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has is_full_moon => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has statuses => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    lazy    => 1,
    builder => '_build_statuses',
    clearer => '_clear_statuses',
    handles => {
        statuses => 'elements',
    },
);

sub _build_statuses {
    my $self = shift;
    my @statuses;
    my @attr = grep { $_->does('TAEB::DisplayStatus') }
               $self->meta->get_all_attributes;

    for my $attr (@attr) {
        next unless $attr->get_value($self);
        my $status = $attr->name;
        $status =~ s/^is_//;
        push @statuses, $status;
    }
    return \@statuses;
}

sub parse_botl {
    my $self = shift;
    my $status = TAEB->vt->row_plaintext(22);
    my $botl   = TAEB->vt->row_plaintext(23);

    if ($status =~ /^(\w+)?.*?St:(\d+(?:\/(?:\*\*|\d+))?) Dx:(\d+) Co:(\d+) In:(\d+) Wi:(\d+) Ch:(\d+)\s*(\w+)\s*(.*)$/) {
        # $1 name
        $self->str($2);
        $self->dex($3);
        $self->con($4);
        $self->int($5);
        $self->wis($6);
        $self->cha($7);
        # $8 align

        # we can't assume that TAEB will always have showscore. for example,
        # slackwell.com (where he's playing as of this writing) doesn't have
        # that compiled in
        if ($9 =~ /S:(\d+)\s*/) {
            $self->score($1);
        }
    }
    else {
        TAEB->log->senses("Unable to parse the status line '$status'",
                          level => 'error');
    }

    if ($botl =~ /^(Dlvl:\d+|Home \d+|Fort Ludios|End Game|Astral Plane)\s+(?:\$|\*):(\d+)\s+HP:(\d+)\((\d+)\)\s+Pw:(\d+)\((\d+)\)\s+AC:([0-9-]+)\s+(?:Exp|Xp|HD):(\d+)(?:\/(\d+))?\s+T:(\d+)\s+(.*?)\s*$/) {
        # $1 dlvl (cartographer does this)
        $self->gold($2);
        $self->hp($3);
        $self->maxhp($4);
        $self->power($5);
        $self->maxpower($6);
        $self->ac($7);
        $self->level($8);
        # $9 experience
        $self->turn($10);
        # $self->status(join(' ', split(/\s+/, $11)));
    }
    else {
        TAEB->log->senses("Unable to parse the botl line '$botl'",
                          level => 'error');
    }
}

sub find_statuses {
    my $self = shift;
    my $status = TAEB->vt->row_plaintext(22);
    my $botl   = TAEB->vt->row_plaintext(23);

    if ($status =~ /^\S+ the Were/) {
        $self->is_lycanthropic(1);
    }

    # we can definitely know some things about our nutrition
    if ($botl =~ /\bSat/) {
        $self->nutrition(1000) if $self->nutrition < 1000;
    }
    elsif ($botl =~ /\bHun/) {
        $self->nutrition(149)  if $self->nutrition > 149;
    }
    elsif ($botl =~ /\bWea/) {
        $self->nutrition(49)   if $self->nutrition > 49;
    }
    elsif ($botl =~ /\bFai/) {
        $self->nutrition(-1)   if $self->nutrition > -1;
    }
    else {
        $self->nutrition(999) if $self->nutrition > 999;
        $self->nutrition(150) if $self->nutrition < 150;
    }

    if ($botl =~ /\bOverl/) {
        $self->burden('Overloaded');
    }
    elsif ($botl =~ /\bOvert/) {
        $self->burden('Overtaxed');
    }
    elsif ($botl =~ /\bStra/) {
        $self->burden('Strained');
    }
    elsif ($botl =~ /\bStre/) {
        $self->burden('Stressed');
    }
    elsif ($botl =~ /\bBur/) {
        $self->burden('Burdened');
    }
    else {
        $self->burden('Unencumbered');
    }

    $self->is_blind($botl =~ /\bBli/ ? 1 : 0);
    $self->is_stunned($botl =~ /\bStun/ ? 1 : 0);
    $self->is_confused($botl =~ /\bConf/ ? 1 : 0);
    $self->is_hallucinating($botl =~ /\bHal/ ? 1 : 0);
    $self->is_food_poisoned($botl =~ /\bFoo/ ? 1 : 0);
    $self->is_ill($botl =~ /\bIll/ ? 1 : 0);
}

sub resistances {
    my $self = shift;
    my @resistances;
    my @attr = grep { $_->name =~ /_resistant$/ }
               $self->meta->get_all_attributes;

    for my $attr (@attr) {
        next unless $attr->get_value($self);
        my ($resistance) = $attr->name =~ /(\w+)_resistant$/;
        push @resistances, $resistance;
    }
    return @resistances;
}

sub update {
    my $self = shift;
    my $main = shift;

    if ($main) {
        $self->inc_step;
        TAEB->send_message(step => TAEB::Announcement::Step->new);
    }

    $self->parse_botl;
    $self->find_statuses;

    if ($self->prev_turn) {
        if ($self->turn != $self->prev_turn) {
            for ($self->prev_turn + 1 .. $self->turn) {
                TAEB->send_message(
                    turn => TAEB::Announcement::Turn->new(turn_number => $_));
            }
        }
    }

    $self->prev_turn($self->turn);
}

sub msg_autopickup {
    my $self    = shift;
    my $enabled = shift;
    $self->autopickup($enabled);
}

sub is_polymorphed {
    my $self = shift;
    return defined $self->polyself;
}

sub is_checking {
    my $self = shift;
    my $what = shift;
    return 0 unless defined($self->checking);
    return $self->checking eq $what;
}

sub msg_god_angry {
    my $self      = shift;
    my $max_anger = shift;

    $self->max_god_anger($max_anger);
}

sub luck {
    my $self = shift;
    my $luck = $self->baseluck;
    $luck-- if $self->is_friday_13th;
    $luck++ if $self->is_full_moon;
    # TODO Extra luck from luckstones
    return $luck;
}

sub in_pray_heal_range {
    my $self = shift;
    return $self->hp * 7 < $self->maxhp || $self->hp < 6;
}

subscribe beartrap => sub {
    my $self  = shift;
    my $event = shift;

    $self->in_beartrap($event->now_stuck);
};

sub msg_walked {
    my $self = shift;
    $self->in_beartrap(0);
    $self->in_pit(0);
    $self->in_web(0);
    $self->is_grabbed(0);
    if (!$self->autopickup xor TAEB->current_tile->in_shop) {
        TAEB->log->senses("Toggling autopickup because we entered/exited a shop");
        TAEB->write("@");
        TAEB->process_input;
    }
}

subscribe turn => sub {
    my $self = shift;
    my $event = shift;

    $self->nutrition($self->nutrition - 1);

    my $luck = $self->baseluck;
    # TODO AoY affects this too
    my $luckturns = $self->max_god_anger != 0 ? 300 : 600;
    if ($event->turn_number % $luckturns == 0) {
        # TODO Luckstones prevent timeing out
        if ($luck > 0) {
            $luck--;
        } elsif ($luck < 0) {
            $luck++;
        }
        $self->baseluck($luck);
    }
};

my %method_of = (
    lycanthropy   => 'is_lycanthropic',
    blindness     => 'is_blind',
    confusion     => 'is_confused',
    stunning      => 'is_stunned',
    hallucination => 'is_hallucinating',
    pit           => 'in_pit',
    web           => 'in_web',
    stoning       => 'is_petrifying',
    levitation    => 'is_levitating',
);

sub msg_status_change {
    my $self     = shift;
    my $status   = shift;
    my $now_have = shift;

    my $method = $method_of{$status} || "is_$status";

    if ($self->can($method)) {
        $self->$method($now_have);
    }
}

sub msg_resistance_change {
    my $self     = shift;
    my $status   = shift;
    my $now_have = shift;

    my $method = "${status}_resistant";
    TAEB->log->senses("resistance_change $method");
    if ($self->can($method)) {
        $self->$method($now_have);
    }
}
sub msg_pit {
    my $self = shift;
    $self->msg_status_change(pit => @_);
    TAEB->send_message('dungeon_feature' => 'trap' => 'pit');
}

sub msg_web {
    my $self = shift;
    $self->msg_status_change(web => @_);
    TAEB->send_message('dungeon_feature' => 'trap' => 'web');
}

sub msg_life_saving {
    my $self   = shift;
    my $target = shift;
    TAEB->log->senses("Life saving target: $target");
    #note that naming a monster "Your" returns "Your's" as the target
    if ($target eq 'Your') {
        #At least I had it on!
        #Remove it from inventory
        my $item = TAEB->inventory->amulet;
        TAEB->log->senses("Removing $item  from slot " . $item->slot . " beacuse it is life saving and we just used it.");
        TAEB->inventory->decrease_quantity($item->slot);
    }

    # oh well, i guess it wasn't my "oLS
    # trigger a discoveries check if we didn't know the appearance
    TAEB->send_message(check => 'discoveries') if
        TAEB->item_pool->possible_appearances_of("amulet of life saving") > 1;
}

sub msg_engulfed {
    my $self = shift;
    $self->msg_status_change(engulfed => @_);
}

subscribe grabbed => sub {
    my $self = shift;
    my $event = shift;
    
    $self->is_grabbed($event->grabbed);
};

sub elbereth_count {
    TAEB->currently("Checking the ground for elbereths");
    TAEB->action(TAEB::Action::Look->new);
    TAEB->run_action;
    TAEB->full_input;
    my $tile = TAEB->current_tile;
    my $elbereths = $tile->elbereths;
    TAEB->log->senses("Tile (".$tile->x.", ".$tile->y.") has $elbereths Elbereths (".$tile->engraving.")");
    return $elbereths;
}

sub msg_nutrition {
    my $self = shift;
    my $nutrition = shift;

    $self->nutrition($nutrition);
}

sub msg_polyself {
    my $self = shift;
    my $newform = shift;

    $self->polyself($newform);

    # Polyselfing can make us drop things; recheck our inventory
    TAEB->send_message(check => 'inventory');
}

# this is nethack's internal representation of strength, to make other
# calculations easier (see include/attrib.h)
sub _nethack_strength {
    my $self = shift;
    my $str = $self->str;

    if ($str =~ /^(\d+)(?:\/(\*\*|\d+))?$/) {
        my $base = $1;
        my $ext  = $2 || 0;
        $ext = 100 if $ext eq '**';

        return $base if $base < 18;
        return 18 + $ext if $base == 18;
        return 100 + $base;
    }
    else {
        TAEB->log->senses("Unable to parse strength $str.",
                          level => 'error');
    }
}

# this is what NetHack uses to convert 18/whackiness to an integer
# or so I think. crosscheck src/attrib.c and src/botl.c..
sub numeric_strength {
    my $self = shift;
    my $str = $self->_nethack_strength;

    return $str if $str <= 18;
    return 19 + int($str / 50) if ($str <= 100 + 21);
    return $str - 100;
}

sub strength_damage_bonus {
    my $self = shift;
    my $str = $self->_nethack_strength;

       if ($str <  6)        { return -1 }
    elsif ($str <  16)       { return 0  }
    elsif ($str <  18)       { return 1  }
    elsif ($str == 18)       { return 2  }
    elsif ($str <= 18 + 75)  { return 3  }
    elsif ($str <= 18 + 90)  { return 4  }
    elsif ($str <  18 + 100) { return 5  }
    else                     { return 6  }
}

sub accuracy_bonus {
    # XXX: everything
    return 0;
}

sub item_damage_bonus {
    # XXX: include rings of increase damage, etc here
    return 0;
}

sub burden_mod {
    my $self = shift;
    my $burden = $self->burden;

    return 1    if $burden eq 'Unencumbered';
    return .75  if $burden eq 'Burdened';
    return .5   if $burden eq 'Stressed';
    return .25  if $burden eq 'Strained';
    return .125 if $burden eq 'Overtaxed';
    return 0    if $burden eq 'Overloaded';

    die "Unknown burden level ($burden)";
}

sub speed_range {
    my $self = shift;
    Carp::croak("Call speed_range in list context") if !wantarray;
    return (18, 24) if $self->is_very_fast;
    return (12, 18) if $self->is_fast;
    return (12, 12);
}

sub speed {
    my $self = shift;
    my ($min, $max) = $self->speed_range;
    my $burden_mod = $self->burden_mod;

    $min *= $burden_mod;
    $max *= $burden_mod;

    if (!wantarray) {
        if ($self->is_very_fast) {
            return ($min * 2 + $max) / 3;
        }
        else {
            return ($min + $max * 2) / 3;
        }
    }
    return ($min, $max);
}

# The maximum weight we can carry with out current stats and still be
# unburdened. The maximum weight we can carry without being stressed
# is about 1.5 times this; wizmode testing shows that a character with
# no inventory, and max str and con, can carry $100049 without being
# burdened, and $149949 without being stressed.
sub unburdened_limit {
    my $self = shift;
    my $limit = 25*($self->con+$self->numeric_strength)+50;
    return 1000 if $limit > 1000;
    return 1000;
}

# XXX this belongs elsewhere, but where?

sub spell_protection_return {
    my $self = shift;

    my $nat_rank = int((10 - ($self->ac + $self->spell_protection)) / 10);
    $nat_rank = 3 if $nat_rank > 3;

    my $lev = $self->level;
    my $amt = - int($self->spell_protection / (4 - $nat_rank));

    while ($lev >= 1) { $lev = int($lev / 2); $amt++ };

    return $amt > 0 ? $amt : 0;
}

sub msg_protection_add {
    my ($self, $amt) = @_;
    $self->spell_protection($self->spell_protection + $amt);
}

subscribe protection_dec => sub {
    my ($self) = @_;
    $self->spell_protection($self->spell_protection - 1);
};

subscribe protection_gone => sub {
    my $self = shift;
    $self->spell_protection(0);
};

subscribe friday_13th => sub {
   my $self = shift;
   $self->is_friday_13th(1);
};

subscribe new_moon => sub {
   my $self = shift;
   $self->is_new_moon(1);
};

subscribe full_moon => sub {
   my $self = shift;
   $self->is_full_moon(1);
};

sub has_infravision {
    my $self = shift;
    return 0 if $self->race eq 'Hum';
    return 0 if $self->is_polymorphed; # XXX handle polyself
    return 1;
}

subscribe debt => sub {
    my $self  = shift;
    my $event = shift;

    my $amount = $event->amount;

    # gold is occasionally undefined. that's okay, that tells us to check
    # how much we owe with the $ command
    if (!defined($amount)) {
        $self->_clear_debt;
        TAEB->send_message(check => 'debt');
    }
    else {
        $self->debt($amount);
    }
};

sub msg_game_started {
    my $self = shift;

    $self->cold_resistant(1) if $self->role eq 'Val';

    $self->poison_resistant(1) if $self->role eq 'Hea'
                               || $self->role eq 'Bar'
                               || $self->race eq 'Orc';

    $self->is_fast(1) if $self->role eq 'Arc'
                      || $self->role eq 'Mon'
                      || $self->role eq 'Sam';

    $self->is_stealthy(1) if $self->role =~ /Arc|Rog|Val/;
}

subscribe vault_guard => sub {
    my $self  = shift;
    my $event = shift;

    my $following = $event->following;

    $self->following_vault_guard($following);
};

sub msg_attacked {
    my $self = shift;
    my $attacker = shift;

    if ($attacker =~ /\bnurse\b/) {
        $self->last_seen_nurse($self->turn);
    }
}

sub msg_check {
    my $self = shift;
    my $thing = shift;

    if (!$thing) {
        # discoveries must come before inventory, otherwise I'd meta this crap
        for my $aspect (qw/crga spells discoveries inventory enhance floor debt autopickup/) {
            my $method = "_check_$aspect";
            $self->$method;
        }
    }
    elsif (my $method = $self->can("_check_$thing")) {
        $self->$method(@_);
    }
    else {
        TAEB->log->senses("I don't know how to check $thing.",
                          level => 'warning');
    }
}

my %check_command = (
    discoveries => "\\",
    inventory   => "Da\n",
    spells      => "Z",
    crga        => "\cx",
    floor       => ":",
    debt        => '$',
    enhance     => "#enhance\n",
    autopickup  => "@@",
);

my %post_check = (
    debt => sub {
        my $self = shift;
        $self->debt(0) if !$self->known_debt;
    },
);

for my $aspect (keys %check_command) {
    my $command = $check_command{$aspect};
    my $post    = $post_check{$aspect};

    __PACKAGE__->meta->add_method("_check_$aspect" => sub {
        my $self = shift;
        $self->checking($aspect);
        TAEB->write($command);
        TAEB->full_input;
        $post->($self) if $post;
        $self->clear_checking;
    });
}

sub _check_tile {
    my $self = shift;
    my $tile = shift;

    my $msg = TAEB->farlook($tile);
    TAEB->send_message('farlooked' => $tile, $msg);
}

subscribe noise => sub {
    my $self = shift;

    $self->noisy_turn($self->turn);
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 burden_mod

Returns the speed modification imposed by burden.

=head2 speed_range

Returns the minimum and maximum speed level.

=head2 speed :: (Int,Int)

Returns the minimum and maximum speed of the PC in its current condition.
In scalar context, returns the average.

=head2 spell_protection_return :: Int

Returns the amount of protection the PC would get from the spell right now.

=head2 has_infravision :: Bool

Return true if the PC has infravision.

=cut

