package TAEB::Spoilers::Room;
use Moose;
use TAEB::OO;

class_has shop_names => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        my %shop_names = (
            "general store"                   => 'general',
            "used armor dealership"           => 'armor',
            "second-hand bookstore"           => 'book',
            "liquor emporium"                 => 'potion',
            "antique weapons outlet"          => 'weapons',
            "delicatessen"                    => 'food',
            "jewelers"                        => 'gem',
            "quality apparel and accessories" => 'wand',
            "hardware store"                  => 'tool',
            "rare books"                      => 'book',
            "lighting store"                  => 'light',
        );
        return \%shop_names;
    },
);

sub shop_type {
    my $self = shift;
    my $name = shift;

    if ($self->shop_names->{$name}) {
        return $self->shop_names->{$name};
    }

    TAEB->log->spoiler("Failed to find shop matching description $name",
                       level => 'error');
    return 0;
}

__PACKAGE__->meta->make_immutable;

1;

