package TAEB::World::Monster;
use Moose;
use TAEB::OO;
use TAEB::Util::Colors ':colors', 'string_color';
use TAEB::Util qw/align2str max min any all/;
use TAEB::Spoilers::Combat;

with 'TAEB::Role::Overload';

has glyph => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has color => (
    is       => 'ro',
    isa      => 'TAEB::Display::Color',
    required => 1,
);

has tile => (
    is       => 'ro',
    isa      => 'TAEB::World::Tile',
    weak_ref => 1,
    handles  => [qw/x y z level in_shop in_temple in_los distance/],
);

has possibilities => (
    traits   => ['Array'],
    isa      => 'ArrayRef[TAEB::Spoilers::Monster]',
    writer   => '_set_possibilities',
    lazy     => 1,
    default  => sub { [shift->_lookup_spoiler] },
    handles => {
        possibilities     => 'elements',
        possibility_count => 'count',
        possibility       => 'get',
    },
);

has disposition => (
    is  => 'rw',
    isa => 'Maybe[TAEB::Type::Disposition]',
);

has last_seen => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { TAEB->turn },
);

sub maybe {
    my $self = shift;
    my $property = shift;
    return any { $_->$property } $self->possibilities;
}

sub definitely {
    my $self = shift;
    my $property = shift;
    return all { $_->$property } $self->possibilities;
}

sub definitely_known {
    my $self = shift;
    return $self->possibility_count == 1;
}

sub spoiler {
    my $self = shift;
    return unless $self->definitely_known;
    return $self->possibility(0);
}

sub _lookup_spoiler {
    my $self = shift;
    return TAEB::Spoilers::Monster->lookup(
        glyph => $self->glyph,
        color => $self->color->standard_index,
        @_,
    );
}

sub reset_possibilities {
    my $self = shift;
    $self->_set_possibilities([$self->_lookup_spoiler(@_)]);
}

sub farlook {
    my $self = shift;
    my $tile = $self->tile;
    my @description = TAEB->farlook($tile);
    # Return if we can't see the monster. This might happen if, for instance,
    # it's an I glyph rather than a monster we can see.
    return unless @description > 2;
    my $species = $description[2];
    my $disposition = 'hostile';
    $disposition    = 'tame'     if $species =~ s/^tame //;
    $disposition    = 'peaceful' if $species =~ s/^peaceful //;

    $self->disposition($disposition);

    my $parse = NetHack::Monster::Spoiler->parse_description($species);

    $self->reset_possibilities(name => $parse->{monster});
}

sub is_shk {
    my $self = shift;

    return 1 if $self->definitely_known
             && $self->spoiler->name eq 'shopkeeper';
    # if we've seen a nurse recently, then this monster is probably that nurse
    # we really need proper monster tracking! :)
    return 0 if TAEB->turn < (TAEB->last_seen_nurse || -100) + 3;

    return 0 unless $self->glyph eq '@' && $self->color == COLOR_WHITE;

    # a shk isn't a shk if it's outside of its shop!
    # this also catches angry shks, but that's not too big of a deal
    return 0 unless $self->tile->type eq 'obscured'
                 || $self->tile->type eq 'floor';
    return unless $self->in_shop;
    $self->reset_possibilities(name => 'shopkeeper');
    return 1;
}

sub is_priest {
    my $self = shift;
    return 1 if $self->definitely_known
             && $self->spoiler->name =~ /priest/;
    return 0 unless $self->glyph eq '@' && $self->color == COLOR_WHITE;
    return unless $self->in_temple;
    $self->reset_possibilities(name => 'priest');
    return 1;
}

sub is_oracle {
    my $self = shift;

    return 1 if $self->definitely_known
             && $self->spoiler->name eq 'Oracle';
    # we know the oracle level.. is it this one?
    if (my $oracle_level = TAEB->dungeon->special_level->{oracle}) {
        return 0 if $self->level != $oracle_level;
    }
    # if we don't know the oracle level, well, is this level in the right range?
    else {
        return 0 if $self->z < 5 || $self->z > 9;
    }

    return 0 unless $self->x == 39 && $self->y == 12;
    if (TAEB->is_hallucinating
     || ($self->glyph eq '@' && $self->color == COLOR_BRIGHT_BLUE)) {
       $self->reset_possibilities(name => 'Oracle');
       return 1;
    }
    return 0;
}

sub is_vault_guard {
    my $self = shift;
    return 1 if $self->definitely_known
             && $self->spoiler->name eq 'guard';
    return 0 unless TAEB->following_vault_guard;
    if ($self->glyph eq '@' && $self->color == COLOR_BLUE) {
        $self->reset_possibilities(name => 'guard');
        return 1;
    }
    return 0;
}

sub is_quest_friendly {
    my $self = shift;

    # Attacking @s in quest level 1 will screw up your quest. So...don't.
    return 1 if $self->level->known_branch
             && $self->level->branch eq 'quest'
             && $self->z == 1
             && $self->glyph eq '@';
    return 0;
}

sub is_quest_nemesis {
    return 0; #XXX
}

sub is_enemy {
    my $self = shift;
    return 0 if $self->is_oracle;
    return 0 if $self->is_coaligned_unicorn;
    return 0 if $self->is_vault_guard;
    return 0 if $self->is_peaceful_watchman;
    return 0 if $self->is_quest_friendly;
    return 0 if $self->is_shk || $self->is_priest;
    return unless (defined $self->is_shk || defined $self->is_priest);
    return 1;
}

# Yes, this is different from is_enemy.  Enemies are monsters we should
# attack, hostiles are monsters we expect to attack us.  Even if they
# were perfect they'd be different, pick-wielding dwarves for instance.
#
# But they're not perfect, which makes the difference bigger.  If we
# decide to ignore the wrong monster, it will kill us, so is_enemy
# has to be liberal.  If we let a peaceful monster chase us, we'll
# starve, so is_hostile has to be conservative.

sub is_hostile {
    my $self = shift;

    # Otherwise, 1 if the monster is guaranteed hostile
    return 1 if $self->maybe('always_hostile');
    return 0 if $self->definitely('always_peaceful');
    return 0 if $self->is_quest_friendly;
    return 1 if $self->is_quest_nemesis;

    my $race = TAEB->race;
    return 1 if $self->maybe('is_elf')   && ($race eq 'Orc');
    return 1 if $self->maybe('is_dwarf') && ($race eq 'Orc');
    return 1 if $self->maybe('is_gnome') && ($race eq 'Hum');
    return 1 if $self->maybe('is_human') && ($race eq 'Gno' || $race eq 'Orc');
    return 1 if $self->maybe('is_orc')   && ($race eq 'Hum' || $race eq 'Elf'
                                                            || $race eq 'Dwa');

    return 1 if any { align2str($_->alignment) ne TAEB->align }
                    $self->possibilities;

    # do you have the amulet? is it a minion?  is it cross-aligned?
    return;
}

sub probably_sleeping {
    my $self = shift;

    return 0 if TAEB->noisy_turn && TAEB->noisy_turn + 40 > TAEB->turn;
    return 1 if $self->is_nymph || $self->is_leprechaun;
    return 1 if TAEB->is_stealthy;
    return 0;
}

# Would this monster chase us if it wanted to and noticed us?
sub would_chase {
    my $self = shift;

    # Unicorns won't step next to us anyway
    return 0 if $self->is_unicorn;

    # Leprechauns avoid the player once they have gold
    return 0 if $self->is_leprechaun;

    # Monsters that can't move won't take initiative
    return 0 unless $self->can_move;

    return 1;
}

sub will_chase {
    my $self = shift;

    return $self->would_chase
        && $self->is_hostile
        && !$self->probably_sleeping;
}

sub has_possibility {
    my $self = shift;
    my $name = shift;
    return any { $_->name eq $name } $self->possibilities;
}

# XXX: should be ai?
sub is_meleeable {
    my $self = shift;

    return 0 unless $self->is_enemy;

    return 0 if $self->has_possibility('floating eye')
             && !TAEB->is_blind;

    return 0 if $self->has_possibility('blue jelly')
             && !TAEB->cold_resistant;

    return 0 if $self->has_possibility('spotted jelly');

    return 0 if $self->has_possibility('gelatinous cube')
             && $self->level->has_enemies > 1;

    return 1;
}

# Yes, I know the name is long, but I couldn't think of anything better.
#  -Sebbe.
sub is_seen_through_warning {
    my $self = shift;
    return $self->glyph =~ /[1-5]/;
}

sub is_sleepable {
    my $self = shift;
    return $self->is_meleeable;
}

sub respects_elbereth {
    my $self = shift;
    return !$self->maybe('ignores_elbereth');
}

sub is_minotaur {
    my $self = shift;
    return any { $_->name eq 'minotaur' } $self->possibilities;
}

sub is_nymph {
    my $self = shift;
    return $self->glyph eq 'n';
}

sub is_leprechaun {
    my $self = shift;
    return $self->glyph eq 'l';
}

sub is_unicorn {
    my $self = shift;
    # unicorns have unique appearances
    return $self->definitely_known
        && $self->spoiler->is_unicorn;
}

sub is_coaligned_unicorn {
    my $self = shift;
    my $uni = $self->is_unicorn;

    return $uni && $uni eq TAEB->align;
}

sub is_peaceful_watchman {
    my $self = shift;
    return 0 unless $self->level->is_minetown;
    return 0 if $self->level->angry_watch;
    return 0 unless $self->glyph eq '@';

    return $self->color == COLOR_GRAY || $self->color == COLOR_GREEN;
}

sub is_ghost {
    my $self = shift;

    return $self->glyph eq ' ' if $self->level->is_rogue;
    return $self->glyph eq 'X';
}

sub can_move {
    my $self = shift;

    return 0 if all { $_->speed == 0 } $self->possibilities;
    return 0 if $self->is_oracle;
    return 1;
}

sub debug_line {
    my $self = shift;
    my @bits;

    push @bits, sprintf '(%d,%d)', $self->x, $self->y;
    my ($name) = map { $_->name } $self->possibilities;
    push @bits, $name if $self->definitely_known;
    push @bits, 'g<' . $self->glyph . '>';
    push @bits, 'c<' . string_color($self->color) . '>';

    return join ' ', @bits;
}

sub can_be_outrun {
    my $self = shift;

    my ($min_taeb_speed, $max_taeb_speed) = TAEB->speed;
    my $mon_speed = max map { $_->speed } $self->possibilities;

    return $mon_speed < $min_taeb_speed
        || ($mon_speed == $min_taeb_speed && $mon_speed < $max_taeb_speed);
}

sub can_be_infraseen {
    my $self = shift;
    return TAEB->has_infravision && $self->maybe('infravision_detectable');
}

sub speed {
    return max map { $_->{speed} } shift->possibilities;
}

sub maximum_melee_damage {
    return max map { ($_->_read_attack_string)[1] } shift->possibilities;
}

sub average_melee_damage {
    return max map { ($_->_read_attack_string)[0] } shift->possibilities;
}

sub average_actions_to_kill {
    my $self = shift;
    my $potential = shift;
    return unless $self->possibilities;
    if (!defined $potential) {
    # TODO: allow for monster resistances
        my $weapon = TAEB->inventory->equipment->weapon;
        # TODO: The framework doesn't support twoweaponing well yet,
        # so ignore the secondary weapon for now.
        # TODO: allow for monster size
        $potential = defined $weapon
                   ? TAEB::Spoilers::Combat->damage($weapon)
                   : TAEB::Spoilers::Combat->damage('-');
    }
    return if !$potential;
    # Hit dice are d8s, so average 4.5 sides each.
    my $hd = (max map { $_->hitdice } $self->possibilities);
    return 2.5 / $potential if !$hd;
    return $hd * 4.5 / $potential;
}

sub currently_seen {
    my $self = shift;
    return $self->last_seen == TAEB->turn;
}

sub persistence_time {
    my $self = shift;
    # XXX: this should eventually be configurable by the ai or something
    return ($self->can_move && $self->speed > 0) ? (120 / $self->speed) : 1e7;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 can_be_outrun :: bool

Return true if the player can definitely outrun the monster.

=head2 can_be_infraseen :: Bool

Returns true if the player could see this monster using infravision.

=head2 speed :: Int

Returns the (base for now) speed of this monster.  If we can't exactly
tell what it is, return the speed of the fastest possibility.

=head2 maximum_melee_damage :: Int

How much damage can this monster do in a single round of attacks if it
connects and does full damage with each hit?

=head2 average_melee_damage :: Int

How much damage can this monster do in a single round of attacks in
the average case, accounting for AC?

=head2 average_actions_to_kill [Num] :: Num

How many actions will it take to kill this monster, on average?
Returns undef if we cannot hurt this monster, and the number of
actions (that is, F or t commands) it will take otherwise. If given,
the argument is the average damage per round TAEB can deal to the
monster; otherwise, TAEB's current weapon damage will be used
(eventually this should allow for the monster's resistances, but at
present it doesn't). If it's unclear what sort of monster is on the
square, the worst possible case will be taken. This function is
unlikely to give a sensible result when hallucinating or on monsters
seen through warning.

=cut

