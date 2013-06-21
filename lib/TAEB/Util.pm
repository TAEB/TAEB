package TAEB::Util;
use strict;
use warnings;

use Scalar::Util qw(blessed isweak refaddr weaken);
use List::Util qw(first min max minstr maxstr reduce sum shuffle);
use List::MoreUtils ':all';

use Sub::Exporter -setup => {
    exports => [
        qw(dice align2str assert assert_is),
        qw(blessed isweak refaddr weaken),
        @List::Util::EXPORT_OK,
        @List::MoreUtils::EXPORT_OK,
    ],
};

sub align2str {
    my $val = shift;

    return 'Una' if !defined($val);
    return ($val > 0) ? 'Law' : ($val < 0) ? 'Cha' : 'Neu';
}

sub dice {
    my $dice = shift;
    my ($num, $sides, $num2, $sides2, $bonus) =
        $dice =~ /(\d+)?d(\d+)(?:\+(\d+)?d(\d+))?([+-]\d+)?/;
    $num ||= 1;
    $num2 ||= 1;
    $bonus ||= 0;
    $sides2 ||= 0;
    $bonus =~ s/\+//;

    my $average = $num * $sides / 2 + $num2 * $sides2 / 2 + $bonus;
    return $average if !wantarray;

    my $max = $num * $sides + $num2 * $sides2 + $bonus;
    my $min = $num + $num2 + $bonus;

    return ($min, $average, $max);
}

sub _add_file_line {
    my $explanation = shift;

    my (undef, $file, $line) = caller(1);
    return $explanation .= " at $file line $line";
}

sub assert {
    my ($condition, $explanation) = @_;

    return if $condition;

    my $message = _add_file_line("Assertion failed: $explanation");

    if (TAEB->config->kiosk_mode) {
        warn $message;
    }
    else {
        TAEB->debugger->console->repl($message);
    }
}

sub assert_is {
    my ($got, $expected, $explanation) = @_;

    return if !defined($got) && !defined($expected);
    return if defined($got) && defined($expected) && $got eq $expected;

    $explanation = "Assertion failed: " . _add_file_line($explanation) . "\n";
    $explanation .= "'$got' does not equal '$expected'";

    my $message = _add_file_line("Assertion failed: $explanation");

    if (TAEB->config->kiosk_mode) {
        warn $message;
    }
    else {
        TAEB->debugger->console->repl($message);
    }
}

1;

