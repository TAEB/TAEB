#!/bin/bash

set -e

# Update the system.
sudo apt-get update
sudo apt-get -y upgrade

# Install tools to build stuff.
sudo apt-get -y install build-essential curl git-core libssl-dev libncurses5-dev tmux

# Install cpanm.
curl -L http://cpanmin.us | perl - --sudo App::cpanminus

# TAEB uses Dist::Zilla.
cpanm --sudo --notest Dist::Zilla Software::License::NetHack

# Fetch TAEB.
git clone https://github.com/TAEB/TAEB.git

# Install everything else that TAEB needs.
(
cd TAEB
#dzil authordeps --missing | cpanm --sudo --notest
dzil listdeps --missing | cpanm --sudo --notest
)

# Get some AIs.
git clone https://github.com/TAEB/TAEB-AI-Behavioral.git
git clone https://github.com/TAEB/TAEB-AI-Magus.git

# Get latest versions of several CPAN modules TAEB uses.
TAEB_DEPS='NetHack-Engravings NetHack-Item NetHack-Menu NetHack-PriceID '
for dep in $TAEB_DEPS; do
    git clone https://github.com/TAEB/${dep}.git
    # Install it from the git repo.
    (
    cd $dep
    dzil build
    cpanm --sudo $dep-*.tar.gz
    )
done

# Do some rudimentary setup for TAEB.
mkdir ~/.taeb
cp TAEB/etc/examples/cloud-taeb.yml .taeb/config.yml

echo <<MSG
########################################################################

TAEB set up in ~/TAEB. You must edit ~/.taeb/pass_config.yml to set
connection details.

########################################################################
MSG
