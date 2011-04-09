package TAEB::Role::Overload;
use MooseX::Role::WithOverloading;
use TAEB::Util 'refaddr';

my (%comparison, %stringification);
BEGIN {
    %comparison = (
        q{==} => sub {
            my $self = shift;
            my $other = shift;

            refaddr($self) == refaddr($other)
        },
        q{!=} => sub {
            my $self = shift;
            my $other = shift;

            not($self == $other);
        },
    );

    $comparison{eq} = $comparison{'=='};
    $comparison{ne} = $comparison{'!='};

    %stringification = (
        q{""} => sub {
            my $self = shift;
            sprintf "[%s: %s]",
                $self->meta->name,
                $self->debug_line;
        },
    );
}

use overload
    fallback => undef,
    %comparison,
    %stringification;

requires 'debug_line';

1;

