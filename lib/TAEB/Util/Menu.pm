package TAEB::Util::Menu;
use strict;
use warnings;
use TAEB::Util::Pair;

use Sub::Exporter -setup => {
    exports => [ qw(item_menu hashref_menu object_menu list_menu) ],
};

sub _canonicalize_name_value {
    my ($name, $value) = @_;
    $value = "(undef)" if !defined($value);
    $value = "(empty)" if !length($value);

    return TAEB::Util::Pair->new(name => $name, value => $value);
}

sub _shorten_title {
    my $title = shift;
    return $title if length($title) <= 75;
    $title = substr $title, -75;
    $title = "... " . $title;
    return $title;
}

sub item_menu {
    my $title   = shift;
    my $thing   = shift;
    my $options = shift || {};

    if (blessed($thing) && $thing->can('meta')) {
        return object_menu($title, $thing, $options);
    }
    elsif (ref($thing) && ref($thing) eq 'HASH') {
        return hashref_menu($title, $thing, $options);
    }
    elsif (ref($thing) && ref($thing) eq 'ARRAY') {
        return list_menu($title, $thing, $options);
    }
    elsif (blessed($thing) && $thing->isa('Set::Object')) {
        return list_menu($title, [$thing->members], $options);
    }

    die "No valid menu type for '$thing'" unless $options->{quiet};
}

sub hashref_menu {
    my $title   = shift;
    my $hash    = shift;
    my $options = shift || {};

    $title ||= "${hash}'s keys/values";

    my @hash_data = (
        map {
            _canonicalize_name_value($_, $hash->{$_});
        }
        sort keys %$hash
    );

    my $menu = TAEB::Display::Menu->new(
        description => _shorten_title($title),
        items       => \@hash_data,
        select_type => $options->{select_type} || 'single',
    );
    my $item = TAEB->display_menu($menu) or return;
    my $selected = $item->user_data;

    if ($options->{no_recurse}) {
        return $selected;
    }

    item_menu(
        "$title -> " . $selected->name,
        $selected->value,
        { %$options, quiet => 1 },
    );
}

sub object_menu {
    my $title   = shift;
    my $object  = shift;
    my $options = shift || {};

    $title ||= "${object}'s attributes";

    my @object_data = (
        sort map {
            my $name = $_->name;
            my $reader = $_->get_read_method_ref;
            _canonicalize_name_value($name, scalar $reader->($object));
        }
        $object->meta->get_all_attributes
    );

    my $menu = TAEB::Display::Menu->new(
        description => _shorten_title($title),
        items       => \@object_data,
        select_type => $options->{select_type} || 'single',
    );
    my $item = TAEB->display_menu($menu) or return;
    my $selected = $item->user_data;

    if ($options->{no_recurse}) {
        return $selected;
    }

    item_menu(
        "$title -> " . $selected->name,
        $selected->value,
        { %$options, quiet => 1 },
    );
}

sub list_menu {
    my $title   = shift || "Unknown list";
    my $items   = shift;
    my $options = shift || {};

    my $menu = TAEB::Display::Menu->new(
        description => _shorten_title($title),
        items       => $items,
        select_type => $options->{select_type} || 'single',
    );
    my $item = TAEB->display_menu($menu) or return;
    my $selected = $item->user_data;

    if ($options->{no_recurse}) {
        return $selected;
    }

    item_menu(
        "$title -> " . $selected,
        $selected,
        { %$options, quiet => 1 },
    );
}

1;
