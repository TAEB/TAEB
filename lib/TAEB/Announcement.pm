package TAEB::Announcement;
use Moose;
use TAEB::OO;

has text => (
    is            => 'ro',
    isa           => 'Str',
    predicate     => 'has_text',
    documentation => 'The text sent by NetHack that generated this message.',
);

# default name for TAEB::Announcement::Foo::Bar is foo_bar
sub name {
    my $self = shift;
    my $class = blessed($self) || $self;

    $class =~ s/^TAEB::Announcement:://;
    $class =~ s/::/_/g;

    return lc $class;
}

sub immediate { 0 }
sub finished_sending { }

use Module::Pluggable (
    require          => 1,
    sub_name         => 'announcement_classes',
    search_path      => ['TAEB::Announcement'],
    on_require_error => sub { confess "Couldn't require $_[0]: $_[1]" },
);
my @announcement_classes = announcement_classes();

do {
    my %name_to_class;

    sub set_name_to_class {
        my $self = shift;
        my $name = shift;
        my $class = shift;

        if (exists $name_to_class{$name}) {
            confess "Two announcement classes conflict over the same name '$name': $class and $name_to_class{$name}";
        }

        $name_to_class{$name} = $class;
    }

    sub name_to_class {
        my $self = shift;
        my $name = shift;

        if (keys %name_to_class == 0) {
            $self->_build_name_to_class_mapping;
        }

        return $name_to_class{$name} if exists $name_to_class{$name};
        confess "No announcement class with the name '$name' exists";
    }

    sub _build_name_to_class_mapping {
        my $self = shift;
        for my $class (@announcement_classes) {
            next unless $class->isa(__PACKAGE__); # roles
            $self->set_name_to_class($class->name => $class);
        }
    }
};

do {
    my %exact_message_table;
    my @regex_message_table;

    sub parse_messages {
        my $class = shift;

        while (my ($message, $args) = splice @_, 0, 2) {
            my $constructor =
                  ref($args) eq 'HASH' ? sub { $class->new(%$args) }
                : ref($args) eq 'CODE' ? sub { $class->new($args->(@_)) }
                : confess "Unknown constructor type '$args' (I can handle hashref and coderef)";

            if (!ref($message)) {
                if (exists $exact_message_table{$message}) {
                    confess "An entry already exists for '$message'. This should not throw an error; perhaps the right refactor would be to compose the existing constructor with the new one?";
                }

                $exact_message_table{$message} = $constructor;
            }
            elsif (ref($message) eq 'Regexp') {
                push @regex_message_table, [ $message, $constructor ];
            }
            else {
                confess "Unknown message type '$message' (I can handle string and regex)";
            }
        }
    }

    sub announcements_for_message {
        my $self = shift;
        my $text = shift;
        my @announcements;

        study $text;

        if (my $constructor = $exact_message_table{$text}) {
            push @announcements, $constructor->();
        }

        for (@regex_message_table) {
            my ($regex, $constructor) = @$_;
            if (my @captures = $text =~ $regex) {
                push @announcements, $constructor->(@captures);
            }
        }

        return @announcements;
    }
};

__PACKAGE__->meta->make_immutable;

1;

