package TAEB::Util::Menu;
use strict;
use warnings;
use TAEB::Util 'blessed';

use Sub::Exporter -setup => {
    exports => [ 'item_menu' ],
    groups  => {
        default => [ 'item_menu' ],
    },
};

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

    my @menu_items = (
        map {
            my $value = $hash->{$_};
            $value = "(undef)" if !defined($value);
            $value = "(empty)" if !length($value);

            TAEB::Display::Menu::Item->new(
                user_data => $value,
                title     => "$_: $value",
            ),
        }
        sort keys %$hash
    );

    my $menu = TAEB::Display::Menu->new(
        description => _shorten_title($title),
        items       => \@menu_items,
        select_type => $options->{select_type} || 'single',
    );
    my $item = TAEB->display_menu($menu) or return;

    if ($options->{no_recurse}) {
        return $item->user_data;
    }

    item_menu(
        "$title -> " . $item->title,
        $item->user_data,
        { %$options, quiet => 1 },
    );
}

sub object_menu {
    my $title   = shift;
    my $object  = shift;
    my $options = shift || {};

    $title ||= "${object}'s attributes";

    my @menu_items = (
        map {
            my $name   = $_->name;
            my $reader = $_->get_read_method_ref;
            my $value  = $reader->($object);

            $value = "(undef)" if !defined($value);
            $value = "(empty)" if !length($value);

            TAEB::Display::Menu::Item->new(
                user_data => $value,
                title     => "$name: $value",
            ),
        }
        sort { $a->name cmp $b->name } $object->meta->get_all_attributes
    );

    my $menu = TAEB::Display::Menu->new(
        description => _shorten_title($title),
        items       => \@menu_items,
        select_type => $options->{select_type} || 'single',
    );
    my $item = TAEB->display_menu($menu) or return;

    if ($options->{no_recurse}) {
        return $item->user_data;
    }

    item_menu(
        "$title -> " . $item->title,
        $item->user_data,
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
