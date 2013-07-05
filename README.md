# Getting TAEB

The preferred method for obtaining the TAEB source is from the GitHub repo:

    git clone git://github.com/TAEB/TAEB.git

Alternatively, you can download a snapshot of the code as a tarball:

    http://github.com/TAEB/TAEB/tarball/master

You could also download a potentially very old copy of TAEB from CPAN:

    cpanm TAEB

Downloading the tarball or installing from CPAN means less work up
front (no need to install git), but it'll be more work every time
you want to update. We very strongly recommend using git.

# Installing dependencies

TAEB uses [`Dist::Zilla`](http://dzil.org) for its packaging and
toolchain support.

You can install TAEB's dependencies with the following commands:

    dzil authordeps --missing | cpanm
    dzil listdeps --missing | cpanm

# AI

Though TAEB ships with a demo AI, you should still install a robust
AI. There are two actively developed AIs, Behavioral and Planar.

## Behavioral AI

The primary AI is Behavioral, since it is the original TAEB AI and
is developed by many of the primary TAEB authors. The preferred
method to get it is through git:

    git clone git://github.com/TAEB/TAEB-AI-Behavioral.git

Or you can get a tarball from:

    http://github.com/TAEB/TAEB-AI-Behavioral/tarball/master

or an old copy from CPAN:

    cpanm TAEB::AI::Behavioral

## Planar AI

The other actively developed AI is Planar, whose design principle is "be the
opposite of Behavorial". You can get it with darcs:

    darcs get http://patch-tag.com/r/ais523/taeb-ai-planar

Or the GitHub mirror:

    git clone git://github.com/TAEB/TAEB-AI-Planar.git

Or a tarball snapshot of the GitHub mirror:

    http://github.com/TAEB/TAEB-AI-Planar/tarball/master

# Configuration

TAEB itself has a lot of configuration. It sets up some sensible
defaults for you (such as playing `nethack` locally with the Demo
AI and communicating with you via Curses). You aren't required to
set up a config, but if you want to change how TAEB operates, such
as by making him play on a NetHack server, you can. Specify the
configuration in `~/.taeb/config.yml`, which is written in
[YAML](http://en.wikipedia.org/wiki/Yaml). The full list of
configuration options, including the required `.nethackrc` file is
provided in
[`TAEB::Config`](https://github.com/TAEB/TAEB/blob/master/lib/TAEB/Config.pm).
Sample configuration files are available in
[`etc/examples`](https://github.com/TAEB/TAEB/tree/master/etc/examples).

# Running TAEB

You should now be ready to run TAEB! If you're in the TAEB checkout,
run `perl -Ilib bin/taeb`. Or, if you installed TAEB, run `taeb`.
Either way, be sure to cross your fingers.

If `perl` doesn't find the installed modules you may need to set
the `$PERL5LIB` environment variable to where you placed them.

## Debug commands

TAEB ships with a number of debug commands. Typing `?` will list
them for you.

# Hacking on TAEB

If you're sufficiently inspired by TAEB, we'd love to have you onboard! The
best first step is to read
[`TAEB::AI::Demo`'s code](https://github.com/TAEB/TAEB/blob/master/lib/TAEB/AI/Demo.pm),
then try some of the exercises. The exercises are geared
toward letting you explore TAEB's codebase. Very tricky, we are.

We also write a lot about TAEB's architecture and dealing with programmatic
NetHack on our blog, http://taeb-nethack.blogspot.com/.
