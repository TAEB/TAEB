package TAEB::Announcement::Role::HasMenu;
use Moose::Role;

requires 'menu_style';

has menu => (
    is       => 'ro',
    isa      => 'NetHack::Menu',
    required => 1,
    handles  => {
        all_menu_items  => 'all_items',
        _set_menu_style => 'select_count',
    },
);

after finished_sending => sub {
    my $self = shift;
    $self->_set_menu_style($self->menu_style);
};

no Moose::Role;

1;

