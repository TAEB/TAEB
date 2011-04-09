package TAEB::Spoilers::Engravings;
use Moose;
use TAEB::OO;
use TAEB::Util 'any';

class_has rubouts => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {
        0   => ' (?C',
        1   => ' ?|',
        6   => ' ?co',
        7   => ' /?',
        8   => ' 3?co',
        ":" => ' .?',
        ";" => ' ,?',
        A   => ' ?^',
        B   => ' -?FP[b|',
        b   => ' ?|',
        C   => ' (?',
        D   => ' )?[|',
        d   => ' ?c|',
        E   => ' -?FL[_|',
        e   => ' ?c',
        F   => ' -?|',
        G   => ' (?C',
        g   => ' ?c',
        H   => ' -?|',
        h   => ' ?nr',
        I   => ' ?|',
        j   => ' ?i',
        K   => ' <?|',
        k   => ' ?|',
        L   => ' ?_|',
        l   => ' ?|',
        M   => ' ?|',
        m   => ' ?nr',
        N   => ' ?\\|',
        n   => ' ?r',
        O   => ' (?C',
        o   => ' ?c',
        P   => ' -?F|',
        Q   => ' (?C',
        q   => ' ?c',
        R   => ' -?FP|',
        T   => ' ?|',
        U   => ' ?J',
        V   => ' /?\\',
        W   => ' /?V\\',
        w   => ' ?v',
        y   => ' ?v',
        Z   => ' /?'
    } },
);

sub is_degradation {
    my $self = shift;
    my $orig = shift;
    my $cur  = shift;

    my @orig = split '', $orig;
    my @cur  = split '', $cur;

    C: for my $c (@cur) {
        while (@orig) {
            my $o = shift @orig;

            next C if $o eq $c;

            if ($o eq ' ') {
                next C if $c eq ' ';
            }
            else {
                next C if any { $_ eq $c } split '', ($self->rubouts->{ $o } || ' ?');
            }
        }

        # we ran out of characters in the original engraving
        return 0 if !@orig;
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;

