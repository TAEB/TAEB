package TAEB::Action::Wipe;
use Moose;
use TAEB::OO;
extends 'TAEB::Action';

use constant command => "#wipe\n";

sub msg_face_clean {
    TAEB->senses->is_pie_blind(0);
}

__PACKAGE__->meta->make_immutable;

1;

