package TAEB::Role::Overload;
use MooseX::Role::WithOverloading 0.09;
use TAEB::Util 'refaddr';

my (%comparison, %conversion);
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

    %conversion = (
        q{""} => sub {
            my $self = shift;
            sprintf "[%s: %s]",
                $self->meta->name,
                $self->debug_line;
        },
        q{bool} => sub {
            # Overloading string conversion means that a lot of
            # calculation must be done merely to determine boolean
            # value of an object. In practice, it'll always be 1;
            # cut out the wait.
            1;
        }
    );
}

use overload
    fallback => undef,
    %comparison,
    %conversion;

requires 'debug_line';

1;

