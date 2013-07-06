package TAEB::Meta::Trait::Persistent;
use Moose::Role;
Moose::Util::meta_attribute_alias('TAEB::Persistent');

before _process_options => sub {
    my ($class, $name, $options) = @_;

    $options->{lazy} = 1;

    $options->{default}
        || confess "Persistent attribute ($name) must have a default value.";

    my $old_default = $options->{default};
    $options->{default} = sub {
        my $self = shift;

        # do we have the value from persistency?
        my $value = delete TAEB->persistent_data->{$name};
        if (defined($value)) {
            # For some reason Storable doesn't load TAEB::AI::Demo
            Class::MOP::load_class(blessed($value)) if blessed($value);
            # sigh, this is awful, but whatever, i'll be rewriting it soon
            # anyway, hopefully
            $value->institute if $value->isa('TAEB::AI');
            return $value;
        }

        # otherwise, use the old default
        ref($old_default) eq 'CODE' ? $old_default->($self, @_) : $old_default;
    };
};

before attach_to_class => sub {
    my ($self, $class) = @_;

    $class->does_role('TAEB::Role::Persistency')
        || confess "Persistent attributes must be applied to a class that does TAEB::Role::Persistency";
};

no Moose::Role;

1;

