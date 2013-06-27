package TAEB::World;
use Moose;

use NetHack::Item 0.09;

use TAEB::Role::Overload ();

use Module::Pluggable (
    require          => 1,
    sub_name         => 'load_nhi_classes',
    search_path      => ['NetHack::Item'],
    except           => qr/Meta|Role/,
    on_require_error => sub { confess "Couldn't require $_[0]: $_[1]" },
);

use Module::Pluggable (
    require          => 1,
    sub_name         => 'load_world_classes',
    search_path      => ['TAEB::World'],
    on_require_error => sub { confess "Couldn't require $_[0]: $_[1]" },
);

sub _find_item_role {
    my $item_class = shift;
    (my $role = $item_class) =~ s/^NetHack/TAEB::Role/;
    while (1) {
        if ($role eq 'TAEB::Role') {
            TAEB->log->moose("Couldn't find a role to apply to $item_class",
                             level => 'error');
            return;
        }
        if (eval { local $SIG{__DIE__}; Class::MOP::load_class($role) }) {
            return $role;
        }
        $role =~ s/::[^:]*$//;
    }
}

for my $class (__PACKAGE__->load_nhi_classes) {
    next if $class =~ /Spoiler/;
    taebify($class);
}

sub taebify {
    my $class = shift;

    (my $taeb_class = $class) =~ s/^NetHack::Item/TAEB::World::Item/;
    Moose::Meta::Class->create(
        $taeb_class,
        superclasses => [$class],
        roles        => [_find_item_role($class), 'TAEB::Role::Overload'],
    );
}

__PACKAGE__->load_world_classes;

1;

