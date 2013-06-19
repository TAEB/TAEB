package TAEB::Config;
use Moose;
use YAML ();
use TAEB::Util qw/first/;
use Hash::Merge 'merge';
Hash::Merge::set_behavior('RIGHT_PRECEDENT');

use File::Spec;
use File::HomeDir;
use Cwd 'abs_path';

sub taebdir_file {
    my $self = shift;
    File::Spec->catfile($self->taebdir, @_)
}

has contents => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {
        return {
            ai        => 'Demo',
            interface => 'Local',
            display   => 'Curses',
        };
    },
);

has taebdir => (
    is      => 'ro',
    isa     => 'Str',
    default => sub {
        my $taebdir = $ENV{TAEBDIR};
        $taebdir ||= File::Spec->catdir(File::HomeDir->my_home, '.taeb');
        $taebdir = abs_path($taebdir);
        return $taebdir if -d $taebdir;
        mkdir $taebdir, 0700 or do {
            local $SIG{__DIE__} = 'DEFAULT';
            die "Please create a $taebdir directory.\n";
        };
    },
);

sub BUILD {
    my $self = shift;

    my @config = grep { -e } $self->taebdir_file('config.yml')
        or return;

    my %seen;

    while (my $file = shift @config) {
        next if $seen{$file}++;

        my $config = YAML::LoadFile($file);
        $self->contents(merge($self->contents, $config));

        # if this config specified other files, load them too
        if ($config->{other_config}) {
            my $c = $config->{other_config};
            my @new_files;
            if (ref($c) eq 'ARRAY') {
                @new_files = @$c;
            }
            elsif (ref($c) eq 'HASH') {
                @new_files = keys %$c;
            }
            else {
                @new_files = ($c);
            }
            push @config, map {
                my $file = $_;
                $file =~ s{^~(\w+)}{File::HomeDir->users_home($1)}e;
                $file =~ s{^~}{File::HomeDir->my_home}e;
                File::Spec->file_name_is_absolute($file)
                    ? $file
                    : File::Spec->catfile($self->taebdir, $file);
            } @new_files;
        }
    }
}

sub override_config {
    my $self = shift;
    my $override = YAML::Load(shift);
    $self->contents(merge($self->contents, $override));
}

sub _get_character_info {
    my $self = shift;
    my ($crga_type, $parser) = @_;
    return '*' unless $self->character;
    my $crga;
    if (ref $crga_type) {
        $crga = first { defined }
                map   { $self->character->{$_} }
                @$crga_type;
    }
    else {
        $crga = $self->character->{$crga_type};
    }
    return '*' unless $crga;
    return $parser->($crga) || '*';
}

sub get_role {
    my $self = shift;
    return $self->_get_character_info('role', sub {
        my $role = shift;
        return $1
            if lc($role) =~ /^([abchkmpstvw])/;
        return 'r'
            if $role =~ /^R[^a]/ || $role eq 'r';
        return 'R'
            if $role =~ /^Ra/i || $role eq 'R';
    });
}

sub get_race {
    my $self = shift;
    return $self->_get_character_info('race', sub {
        my $race = shift;
        return $1
            if lc($race) =~ /^([hedgo])/;
    });
}

sub get_gender {
    my $self = shift;
    return $self->_get_character_info('gender', sub {
        my $gender = shift;
        return $1
            if lc($gender) =~ /^([mf])/;
    });
}

sub get_align {
    my $self = shift;
    return $self->_get_character_info([qw/align alignment/], sub {
        my $align = shift;
        return $1
            if lc($align) =~ /^([lnc])/;
    });
}

sub _get_controller_class {
    my $self = shift;
    my ($controller) = @_;
    my $controller_config = lc($controller);

    my $controller_class = $self->$controller_config
        or die "Specify a class for '$controller_config' in your config";
    $controller_class = $controller_class =~ s/^\+//
                      ? $controller_class
                      : "TAEB::${controller}::${controller_class}";

    Class::MOP::load_class($controller_class);

    return $controller_class;
}

sub _get_controller_config {
    my $self = shift;
    my ($controller, $controller_class) = @_;
    my $controller_config = lc($controller);

    my $options = $self->contents->{"${controller_config}_options"};
    return {} unless $options;

    $controller_class ||= (caller(1))[0];
    $controller_class = $self->_get_controller_class($controller)
        if $controller_class !~ /^TAEB::${controller}::/;

    my $controller_class_config = $controller_class;
    $controller_class_config =~ s/^TAEB::${controller}::([^:]*)(?:::.*)?/$1/;

    return $options->{$controller_class_config} || {};
}

for my $controller (qw/AI Interface Display/) {
    for my $method (qw/class config/) {
        my $controller_method = "_get_controller_$method";
        __PACKAGE__->meta->add_method(
            'get_'.lc($controller)."_$method" => sub {
                my $self = shift;
                return $self->$controller_method($controller, @_);
            }
        );
    }
}

sub nethackrc_contents {
    return << 'NETHACKRC';
# improve the consistency of telnet ping/pong
OPTIONS=!sparkle
OPTIONS=runmode:teleport
OPTIONS=!timed_delay

# display
OPTIONS=showexp
OPTIONS=showscore
OPTIONS=time
OPTIONS=color
OPTIONS=boulder:0
OPTIONS=!tombstone
OPTIONS=!news
OPTIONS=!legacy
OPTIONS=suppress_alert:3.4.3
OPTIONS=hilite_pet

# functionality
OPTIONS=autopickup
OPTIONS=pickup_types:$/
OPTIONS=pickup_burden:unburdened
OPTIONS=!prayconfirm
OPTIONS=pettype:none
OPTIONS=!cmdassist
OPTIONS=disclose:yi +avgc

# miscellaneous
OPTIONS=!mail

# map changes for code simplicity
OPTIONS=monsters:abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ@X'&;:wm
# "strange monster" = m (mimic)
# ghost/shade = X     now space is solid rock
# worm tail = w       now ~ is water

OPTIONS=traps:\^\^\^\^\^\^\^\^\^\^\^\^\^\^\^\^\^\^\^\^\^
# spider web = ^      now " is amulet

OPTIONS=dungeon: |--------||.-|]]}}.##<><>_\\\\{{~.}..}} #}
#  sink => {          one less #, walkable
#  drawbridge => }    one less #, not walkable
#  iron bars => }     one less #, not walkable (color: cyan)
#  trees => }         one less #, not walkable (color: green)
#  closed doors => ]  now + is spellbook
#  grave => \         now gray | and - are walls, (grey -- thrones)
#  water => ~         it looks cool (blue -- long worm tail)

OPTIONS=objects:m
# "strange object" = m (mimic)
# now ] is closed door
NETHACKRC
}

# yes autoload is bad. but, I am lazy
our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    $AUTOLOAD =~ s{.*::}{};

    if (@_) {
        TAEB->config->contents->{$AUTOLOAD} = shift;
    }

    return TAEB->config->contents->{$AUTOLOAD};
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

TAEB::Config

=head1 SAMPLE CONFIG

    ---
    #### Mandatory options ####
    # What should be controlling TAEB
    ai: Demo
    # How TAEB should communicate with NetHack (another option is Telnet)
    interface: Local
    # How TAEB should communicate with you!
    display: Curses

    #### AI config ############
    # Configure AI-specific options here (none of the AIs that ship with TAEB
    # are configurable though...)
    #ai_options:

    #### Interface config #####
    # Configure the interface if necessary (telnet and ssh)
    #interface_options:
    #    Telnet:
    #        account: taeb
    #        password: pass
    #    SSH:
    #        account: taeb
    #        password: pass

    #### Display config #######
    # How TAEB should look when you're watching him
    # color_method controls how tiles are colored, and glyph_method controls
    # which glyphs to display. They can both be changed at runtime as well, see
    # doc/debug-commands.txt.
    # color_method options: normal, debug, engraving, stepped, time, lit
    # glyph_method options: normal, floor
    #display_options:
    #    Curses:
    #        color_method: normal
    #        glyph_method: normal

    #### Character config #####
    # Specify what TAEB should choose when picking a character
    #character:
    #    role: '*'
    #    race: '*'
    #    gender: '*'
    #    align: '*'

    #### Debugging config #####
    # Configure various debugging plugins for TAEB here
    #debug:
    #    sanity:
    #        enabled: 0
    #    console:
    #        readline: Gnu

    #### Logging config #######
    # note: log_rotate->compress requires IO::Compress::Gzip to be installed
    #logger:
    #    min_level: debug
    #    suppress: [moose, undef]
    #    log_rotate:
    #        dir: logs
    #        compress: 1

    #### Misc config ##########
    # Set this to 1 if you want to run a buggy TAEB overnight; it causes TAEB
    # to quit instead of saving on errors; if your TAEB is not particularly
    # buggy, you might want to leave this this at 0 so the full state is kept.
    #kiosk_mode: 0

    #### External config ######
    # Specify other config files to load here - for example, config files
    # containing passwords, or config files specific to a certain ai
    #other_config:
    #    - site_config.yml

=head1 METHODS

=head2 get_role

Retrieves the role from the config, or picks randomly.

=head2 get_race

Retrieves the race from the config, or picks randomly.

=head2 get_gender

Retrieves the gender from the config, or picks randomly.

=head2 get_align

Retrieves the alignment from the config, or picks randomly.

=cut

