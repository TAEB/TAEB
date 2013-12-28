package TAEB::Announcement::Character::StatusChange;
use Moose;
use TAEB::OO;
extends 'TAEB::Announcement::Character';

use constant name => 'status_change';

has status => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has in_effect => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
);

__PACKAGE__->parse_messages(
    "You are blinded by a blast of light!" => {
        status => 'blindness', in_effect => 1
    },
    "You can see again." => {
        status => 'blindness', in_effect => 0
    },
    "You feel feverish." => {
        status => 'lycanthropy', in_effect => 1
    },
    "You feel purified." => {
        status => 'lycanthropy', in_effect => 0
    },
    "You feel quick!" => {
        status => 'fast', in_effect => 1
    },
    "You feel slow!" => {
        status => 'fast', in_effect => 0
    },
    "You seem faster." => {
        status => 'fast', in_effect => 1
    },
    "You seem slower." => {
        status => 'fast', in_effect => 0
    },
    "You feel slower." => {
        status => 'fast', in_effect => 0
    },
    "You speed up." => {
        status => 'fast', in_effect => 1
    },
    "Your quickness feels more natural." => {
        status => 'fast', in_effect => 1
    },
    "You are slowing down." => [
        { status => 'fast',    in_effect => 0 },
        { status => 'stoning', in_effect => 1 },
    ],
    "Your limbs are getting oozy." => {
        status => 'fast', in_effect => 0
    },
    "You slow down." => [
        { status => 'fast',      in_effect => 0 },
        { status => 'very_fast', in_effect => 0 },
    ],
    "Your quickness feels less natural." => [
        { status => 'fast',      in_effect => 0 },
        { status => 'very_fast', in_effect => 0 },
    ],
    '"and thus I grant thee the gift of Speed!"' => {
        status => 'fast', in_effect => 1
    },
    "You are suddenly moving faster." => {
        status => 'very_fast', in_effect => 1
    },
    "You are suddenly moving much faster." => {
        status => 'very_fast', in_effect => 1
    },
    "Your knees seem more flexible now." => {
        status => 'very_fast', in_effect => 1
    },
    "You feel yourself slowing down." => {
        status => 'very_fast', in_effect => 0
    },
    "You feel yourself slowing down a bit." => {
        status => 'very_fast', in_effect => 0
    },
    '"and thus I grant thee the gift of Stealth!"' => {
        status => 'stealthy', in_effect => 1
    },
#    "You feel clumsy." XXX this is also an attribute loss message
    "You feel stealthy!" => {
        status => 'stealthy', in_effect => 1
    },
    "You feel less stealthy!" => {
        status => 'stealthy', in_effect => 0
    },
    "You feel very jumpy." => {
        status => 'intrinsic_teleportitis', in_effect => 1
    },
    "You feel diffuse." => {
        status => 'intrinsic_teleportitis', in_effect => 1
    },
    "You feel less jumpy." => {
        status => 'intrinsic_teleportitis', in_effect => 0
    },
    "Your limbs are stiffening." => {
        status => 'stoning', in_effect => 1
    },
    "You feel more limber." => { # praying
        status => 'stoning', in_effect => 0
    },
    "You feel limber!" => { # consuming acid
        status => 'stoning', in_effect => 0
    },
    "Your right leg is in no shape for kicking." => {
        status => 'wounded_legs', in_effect => 1
    },
    "You start to float in the air!" => {
        status => 'levitation', in_effect => 1
    },
    "You float gently to the floor." => {
        status => 'levitation', in_effect => 0
    },
    "You are floating high above the stairs." => {
        status => 'levitation', in_effect => 1
    },
    "You have nothing to brace yourself against." => {
        status => 'levitation', in_effect => 1
    },
    "You cannot reach the ground." => {
        status => 'levitation', in_effect => 1
    },
    "You are floating high above the fountain." => {
        status => 'levitation', in_effect => 1
    },
    "You feel a strange mental acuity." => {
        status => 'telepathy', in_effect => 1
    },
    "You feel in touch with the cosmos." => {
        status => 'telepathy', in_effect => 1
    },
    "All of a sudden, you can't see yourself." => {
        status => 'invisible', in_effect => 1
    },
    "Your body seems to unfade..." => {
        status => 'invisible', in_effect => 0
    },
    qr/^Your legs? feels? somewhat better\.$/ => {
        status => 'wounded_legs', in_effect => 0
    },
    qr/^What a pity - you just ruined a future piece of (?:fine )?art!/ => {
        status => 'stoning', in_effect => 0
    },
    qr/^Your .* get new energy\.$/ => {
        status => 'very_fast', in_effect => 1
    },
    # This one is somewhat tricky. There is no message for speed ending
    # if you are still very fast due to speed boots, so speed will stay
    # at 'fast'. This causes no harm until the boots are taken off or
    # destroyed; fortunately at that time we receive the following message,
    # which allows us to fix the mistaken speed.
    qr/^You feel yourself slow down.*\.$/ => {
        status => 'very_fast', in_effect => 0
    },
    qr/You feel (?:controlled!|in control of yourself\.|centered in your personal space\.)/ => {
        status => 'intrinsic_teleport_control', in_effect => 1
    },
    qr/You feel uncontrolled!/ => {
        status => 'intrinsic_teleport_control', in_effect => 0
    },
);

__PACKAGE__->meta->make_immutable;

1;
