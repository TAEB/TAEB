package TAEB::Action;
use Moose;
use TAEB::OO;

has aborted => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has starting_tile => (
    is      => 'ro',
    isa     => 'TAEB::World::Tile',
    default => sub { TAEB->current_tile },
);

sub command { confess shift . " must implement ->command" }

sub run { shift->command }

sub done { }

sub new_action {
    my $self = shift;
    my $name = shift;

    # guess case if all lowercase, otherwise use whatever we've got
    if ($name eq lc $name) {
        $name = ucfirst $name;
    }

    my $package = "TAEB::Action::$name";
    return $package->new(@_);
}

sub name {
    my $self = shift;

    # because Moose may rebless our instance, we need to look at the
    # inheritance hierarchy for something that resembles TAEB::Action::Foo
    for my $class ($self->meta->linearized_isa) {
        return $1 if $class =~ m{^TAEB::Action::(\w+)$};
    }

    TAEB->log->action("Unable to get the action name of $self: " . join(', ', $self->meta->linearized_isa), level => 'warning');
    return;
}

sub is_impossible { 0 }
sub is_advisable  { 1 }

use Module::Pluggable
    search_path      => 'TAEB::Action',
    require          => 1,
    sub_name         => 'actions',
    on_require_error => sub { confess "Couldn't require $_[0]: $_[1]" };

# force loading of all the actions for compile errors etc
my @actions = grep { $_->isa('TAEB::Action') }
              sort { $a cmp $b } actions();

sub action_names {
    my $self = shift;

    return map { (my $class = $_) =~ s/^TAEB::Action:://; $class }
           @actions;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head2 command

This is the basic command for the action. For example, C<E> for engraving, and
C<#pray> for praying.

=head2 run

This is what is called to begin the NetHack command. Usually you don't override
this. Your command should define prompt handlers (C<respond_*> methods) to
continue interaction.

=head2 done

This is called just before the action is freed, just before the next command
is run.

=head2 new_action Str, Args => Action

This will create a new action with the specified name and arguments. The name
is typically the package name in lower case.

=head2 name

Returns the name of this action object.

=head2 is_impossible

Returns whether the action is possible to perform this step or not.

=head2 is_advisable

Returns whether the action is likely to have the desired results or not. For
example, engraving while blind is not advisable.

=head2 action_names

Returns a list of action names (Search, Melee, Eat, etc)

=cut

