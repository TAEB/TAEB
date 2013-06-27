# Getting TAEB

The preferred method for obtaining the TAEB source is from the GitHub repo:

    git clone git://github.com/TAEB/TAEB.git

Alternatively, you can download

    http://github.com/TAEB/TAEB/tarball/master

and extract to the directory of your choice.

You can also download a potentially very old copy of TAEB from the CPAN:

    cpanm TAEB

Downloading the tarball or installing from CPAN means less work up front (no
need to install git), but it'll be more work every time you want to update.

# Running from tarball

    dzil authordeps --missing | cpanm
    dzil listdeps --missing | cpanm
    perl -Ilib bin/taeb

# AI

Though TAEB ships with a demo AI, you should still install a robust
AI. There are two actively developed AIs. The primary AI is Behavioral.
The preferred method to get it is through git:

    git clone git://github.com/TAEB/TAEB-AI-Behavioral.git

Or you can get a tarball from

    http://github.com/TAEB/TAEB-AI-Behavioral/tarball/master

or an old copy from the CPAN.

    cpanm TAEB::AI::Behavioral

The other actively developed AI is Planar, whose design principle is "be the
opposite of Behavorial". You can get it from darcs:

    darcs get http://patch-tag.com/r/ais523/taeb-ai-planar

or the GitHub mirror

    git clone git://github.com/TAEB/TAEB-AI-Planar.git

# Configuration

TAEB itself has a lot of configuration. It sets up some sensible defaults for
you (such as playing `nethack` locally with the Demo AI and communicating with
you via Curses). You aren't required to set up config, but if you want to
change how TAEB operates, such as by making him play on a NetHack server, you
can. Specify configuration in `~/.taeb/config.yml`, which is written in
[YAML](http://en.wikipedia.org/wiki/Yaml). Read the sample configuration in
TAEB::Config and `etc/examples` for more details.

# Running TAEB

You should now be ready to run TAEB! If you installed TAEB, type
`taeb`. Otherwise if you're running TAEB from the checkout run
`perl -Ilib bin/taeb`. Either way, be sure to cross your fingers.

If `perl` doesn't find the installed modules you may need to set
the `$PERL5LIB` environment variable to where you placed them.

# Hacking on TAEB

If you're sufficiently inspired by TAEB, we'd love to have you onboard! The
best first step is to read
[`TAEB::AI::Demo`'s code](https://github.com/TAEB/TAEB/blob/master/lib/TAEB/AI/Demo.pm),
then try some of the exercises. The exercises are geared
toward letting you explore TAEB's codebase. Very tricky, we are.

We also write a lot about TAEB's architecture and dealing with programmatic
NetHack on our blog, http://taeb-blog.sartak.org/

