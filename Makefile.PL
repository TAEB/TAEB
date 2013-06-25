# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name           'TAEB';
all_from       'lib/TAEB.pm';

# the object system
requires 'Moose'                       => 1.15;
requires 'MooseX::ABC'                 => 0.02;
requires 'MooseX::ClassAttribute'      => 0.24;
requires 'MooseX::NonMoose'            => 0.18;
requires 'MooseX::Role::Parameterized' => 0.24;
requires 'MooseX::Role::Matcher'       => 0.03;
requires 'MooseX::Role::WithOverloading' => 0.09;
requires 'Module::Pluggable';
requires 'namespace::autoclean';

# parse escape codes into an addressable screen
requires 'Term::VT102::ZeroBased';

# print on an addressable screen
requires 'Curses';

# logging
requires 'Log::Dispatch::Channels';

# config
requires 'YAML';
requires 'Hash::Merge';
requires 'File::HomeDir';

# TAEB::Util
requires 'Sub::Exporter';
requires 'List::MoreUtils';

# pathfinding
requires 'Heap::Simple';
requires 'Heap::Simple::XS'; # why doesn't Heap::Simple do this for us...

# miscellaneous
requires 'Time::HiRes';
requires 'Data::Page';
requires 'Getopt::Long';

# NetHack-specific things
requires 'NetHack::Menu' => 0.06;
requires 'NetHack::FOV'  => 0.01;
requires 'NetHack::Item' => 0.09;
requires 'NetHack::Monster::Spoiler' => 0.02;
requires 'NetHack::Engravings';

my $has_nethack = can_run('nethack');
if (!$has_nethack) {
    warn << '__NETHACK__';
******************************************************************
It appears that you do not have a "nethack" binary available. You will not be
able to use TAEB's Local interface until you install nethack.

Alternatively, use the Telnet interface for playing on public servers such as
nethack.alt.org. Be sure that the "server nethack" dependencies are satisfied.
******************************************************************
__NETHACK__

    # Give them some time to read.
    sleep 10;
}

features(
    # optional modules that enhance TAEB's playing
    'TAEB for server NetHack' => [
        -default => !$has_nethack,
        recommends('IO::Socket::Telnet::HalfDuplex'),
    ],
    'TAEB for local NetHack' => [
        -default => $has_nethack,
        recommends('IO::Pty::HalfDuplex'),
    ],
    'Legacy interface for TAEB on local NetHack' => [
        -default => 0,
        recommends('IO::Pty::Easy' => 0.05),
    ],

    # debugging tools
    'REPL on ~' => [
        -default => 0,
        recommends('Carp::REPL'),
    ],
    'Compress backed up logfiles' => [
        -default => 1,
        recommends('IO::Compress::Gzip'),
    ],
);

build_requires 'Test::More';

install_script 'bin/taeb';

tests('t/*.t t/*/*.t');

WriteAll;

