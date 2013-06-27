-- GETTING TAEB

The preferred method for obtaining the TAEB source is from the github repo:
    git clone git://github.com/TAEB/TAEB.git

Alternatively, you can download "http://github.com/TAEB/TAEB/tarball/master"
and extract to the directory of your choice.

You can also download TAEB from the CPAN: cpan -i TAEB

Downloading the tarball or installing from CPAN means less work up front (no
need to install git), but it'll be more work every time you want to update.


-- INSTALLING FROM TARBALL

If you're on Ubuntu, you'll first need to install the "build-essential" (for
make) and "libncurses5-dev" (for the Curses library) packages. If you are on OS
X, you will need Xcode and probably a few packages from MacPorts.


$ perl Makefile.PL

Answer the defaults to any dependencies it asks about. You may have to
set up CPAN. The defaults are usually fine. Be sure to set a mirror though.

$ make && sudo make install

This will install the modules from CPAN. TAEB's dependencies themselves
usually have a few dependencies. All in all you're probably looking at
about 60 modules.


-- AI

Though TAEB ships with a demo AI, you should still install a robust AI. There
are two actively developed AIs. The older of the two is Behavioral. The
preferred method to get it is through git:
    git clone git://github.com/TAEB/TAEB-AI-Behavioral.git

Or you can get a tarball from
"http://github.com/TAEB/TAEB-AI-Behavioral/tarball/master" or the CPAN.

The newer actively developed AI is Planar, whose design principle is "be the
opposite of Behavorial". You can get it from darcs:

    darcs get http://patch-tag.com/r/ais523/taeb-ai-planar

-- CONFIGURATION

TAEB itself has a lot of configuration. It sets up some sensible defaults for
you (such as playing nethack locally with the Demo AI and communicating with
you via Curses). You aren't required to set up config, but if you want to
change how TAEB operates, such as by making him play on a NetHack server, you
can. Specify configuration in ~/.taeb/config.yml, which is written in YAML
(http://en.wikipedia.org/wiki/Yaml). Read the sample configuration in
TAEB::Config for more details.

-- RUNNING TAEB

You should now be ready to run TAEB! Type "taeb" and cross your fingers.

If perl doesn't find the installed modules you may need to set PERL5LIB to
where you placed them.

-- HACKING ON TAEB

If you're sufficiently inspired by TAEB, we'd love to have you onboard! The
best first step is to read TAEB::AI::Demo's code (which lives in
lib/TAEB/AI/Demo.pm) then try some of the exercises. The exercises are geared
toward letting you explore TAEB's codebase. Very tricky, we are.

We also write a lot about TAEB's architecture and dealing with programmatic
NetHack on our blog, http://taeb-blog.sartak.org/

