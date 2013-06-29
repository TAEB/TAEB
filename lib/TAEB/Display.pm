package TAEB::Display;
use Moose;
use TAEB::OO;
use TAEB::Display::Color;
use TAEB::Display::Menu;

sub get_key { confess shift . " must implement get_key" }

# whether or not this output writes to the terminal: if it does, we don't want
# to also be sending warnings/errors there, for example.
use constant to_screen => 0;

sub reinitialize {
    inner();
    shift->redraw(force_clear => 1);
}

sub display_menu {
    my $self = shift;
    my $menu = shift;

    inner($menu);
    $self->redraw(force_clear => 1);

    return $menu->selected;
}

sub deinitialize { }

sub notify { }

sub redraw { }

sub display_topline { }

sub place_cursor { }

sub try_key { }

sub change_draw_mode { }

__PACKAGE__->meta->make_immutable;

1;

