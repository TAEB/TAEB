package TAEB::Announcement::Role::HasMenu;
use Moose::Role;

requires 'menu_style';

has menu => (
    is       => 'ro',
    isa      => 'NetHack::Menu',
    required => 1,
    handles  => {
        _set_menu_style => 'select_count',
    },
);

# can't use handles for required role methods
sub all_menu_items {
    my $self = shift;
    $self->menu->all_items(@_);
}

after finished_sending => sub {
    my $self = shift;
    $self->_set_menu_style($self->menu_style);
};

no Moose::Role;

1;

