package TAEB::Action::Wield;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';
with 'TAEB::Action::Role::Item' => { items => [qw/weapon/] };

use constant command => "w";

has '+weapon' => (
    isa      => 'NetHack::Item | Str',
    required => 1,
);

sub respond_wield_what {
    my $self = shift;

    if (blessed $self->weapon) {
        return $self->weapon->slot;
    } elsif ($self->weapon eq "nothing") {
        return "-";
    } else {
        TAEB->log->action("Unable to wield " . $self->weapon . ".  Sending escape");
        return "\e";
    }
}

sub done {
    my $self = shift;

    if (blessed $self->weapon) {
        $self->weapon->is_wielded(1);
        TAEB->inventory->update($self->weapon);
    } else {
        TAEB->inventory->clear_weapon;
    }

    # XXX: we need to track TAEB's offhand weapon too
}

__PACKAGE__->meta->make_immutable;

1;

