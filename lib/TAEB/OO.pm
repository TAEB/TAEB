package TAEB::OO;
use Moose ();
use MooseX::ClassAttribute 0.24 ();
use Moose::Exporter;

use autodie;
use namespace::autoclean ();

use TAEB::Meta::Trait::Persistent;
use TAEB::Meta::Trait::DisplayStatus;
use TAEB::Meta::Trait::DontInitialize;
use TAEB::Meta::Types;

my ($import) = Moose::Exporter->setup_import_methods(
    also      => ['MooseX::ClassAttribute'],
    with_meta => ['extends', 'subscribe'],
    base_class_roles => [
        'TAEB::Role::Initialize',
        'TAEB::Role::Subscription',
    ],
    class_metaroles => {
        attribute => ['TAEB::Meta::Trait::Provided'],
    },
    (Moose->VERSION >= 1.9900
        ? (role_metaroles => {
               applied_attribute => ['TAEB::Meta::Trait::Provided'],
           })
        : ()),
);

# make sure using extends doesn't wipe out our base class roles
sub extends {
    my ($meta, @superclasses) = @_;
    @superclasses = map { $_->[0] } @{ Data::OptList::mkopt(\@superclasses) };
    Class::MOP::load_class($_) for @superclasses;
    for my $parent (@superclasses) {
        goto \&Moose::extends if $parent->can('does')
                              && $parent->does('TAEB::Role::Initialize');
    }
    # i'm assuming that after apply_base_class_roles, we'll have a single
    # base class...
    my ($superclass_from_metarole) = $meta->superclasses;
    push @_, $superclass_from_metarole;
    goto \&Moose::extends;
}


sub subscribe {
    my $meta = shift;
    my $handler = pop;

    for my $name (@_) {
        my $method_name = "subscription_$name";
        my $super_method = $meta->find_method_by_name($method_name);
        my $method;

        if ($super_method) {
            $method = sub {
                $super_method->execute(@_);
                goto $handler;
            };
        }
        else {
            $method = $handler;
        }

        $meta->add_method($method_name => $method);
    }
}

sub import {
    my $caller = caller;

    autodie->import;
    namespace::autoclean->import(-cleanee => $caller);

    goto $import;
}

1;
