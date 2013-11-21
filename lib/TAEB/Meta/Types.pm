package TAEB::Meta::Types;
use Moose::Util::TypeConstraints;
use TAEB::Util::World qw/tile_types trap_types/;

enum 'TAEB::Type::PlayState' => [qw(logging_in unable_to_login playing dying human_override)];

enum 'TAEB::Type::Role'   => [qw(Arc Bar Cav Hea Kni Mon Pri Ran Rog Sam Tou Val Wiz)];
enum 'TAEB::Type::Race'   => [qw(Hum Elf Dwa Gno Orc)];
enum 'TAEB::Type::Align'  => [qw(Law Neu Cha)];
enum 'TAEB::Type::Gender' => [qw(Mal Fem Neu)];

enum 'TAEB::Type::BUC'       => [qw(blessed uncursed cursed)];
enum 'TAEB::Type::ItemType'  => [qw(gold weapon armor food corpse scroll spellbook potion amulet ring wand tool gem other)];

enum 'TAEB::Type::Tile' => [tile_types];

enum 'TAEB::Type::DoorState' => [qw(locked unlocked)];

enum 'TAEB::Type::Burden' => [qw(Unencumbered Burdened Stressed Strained Overtaxed Overloaded)];

enum 'TAEB::Type::Branch' => [qw(dungeons mines sokoban quest ludios gehennom vlad planes)];

enum 'TAEB::Type::Trap' => [trap_types];

enum 'TAEB::Type::Disposition' => [qw(hostile peaceful tame)];

enum 'TAEB::Type::Menu' => [qw(none single multi)];

enum 'TAEB::Type::DeathState' => [qw(inventory attributes kills conducts summary scores)];

enum 'TAEB::Type::TermColor' => [0 .. 7];

1;

__END__

=head1 NAME

TAEB::Meta::Types - TAEB-specific types

=cut
