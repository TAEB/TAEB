package TAEB::Logger;
use Moose;
use TAEB::OO;
use Log::Dispatch::File;
use Carp;
use MooseX::NonMoose;
use TAEB::Util qw/weaken/;
extends 'Log::Dispatch::Channels';
with 'TAEB::Role::Config';

has default_outputs => (
    is      => 'ro',
    isa     => 'ArrayRef[Log::Dispatch::Output]',
    lazy    => 1,
    default => sub { [] },
);

has bt_levels => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { { error => 1, warning => 1 } },
);

has everything => (
    is      => 'ro',
    isa     => 'Log::Dispatch::File',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $output = Log::Dispatch::File->new(
            name      => 'everything',
            min_level => $self->_default_min_level,
            filename  => logfile_for("everything"),
            callbacks => sub { _format(@_) },
        );
        $self->add_as_default($output);
        return $output;
    },
);

has warning => (
    is      => 'ro',
    isa     => 'Log::Dispatch::File',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $output = Log::Dispatch::File->new(
            name      => 'warning',
            min_level => 'warning',
            filename  => logfile_for("warning"),
            callbacks => sub { _format(@_) },
        );
        $self->add_as_default($output);
        return $output;
    },
);

has error => (
    is      => 'ro',
    isa     => 'Log::Dispatch::File',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $output = Log::Dispatch::File->new(
            name      => 'error',
            min_level => 'error',
            filename  => logfile_for("error"),
            callbacks => sub { _format(@_) },
        );
        $self->add_as_default($output);
        return $output;
    },
);

has twitter => (
    traits  => [qw/TAEB::DontInitialize/],
    is      => 'ro',
    isa     => 'Maybe[Log::Dispatch::Twitter]',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return unless $self->config;
        my $error_config = $self->config->{twitter}{errors};
        return unless $error_config;
        return unless eval { require Log::Dispatch::Twitter; 1 };

        my $twitter = Log::Dispatch::Twitter->new(
            name      => 'twitter',
            min_level => 'error',
            username  => $error_config->{username},
            password  => $error_config->{password},
            callbacks => sub {
                my %args = @_;
                $args{message} =~ s/\n.*//s;
                return sprintf "%s (T%s): %s",
                            TAEB->loaded_persistent_data
                         && defined TAEB->senses # i.e. not yet cleaned up
                          ? (TAEB->name, TAEB->turn)
                          : ('?', '-'),
                            $args{message};
            },
        );
        $self->add_as_default($twitter);
        return $twitter;
    },
);

sub BUILD {
    my $self = shift;
    # we don't initialize log files until they're used, so need to make sure
    # old ones don't stick around
    $self->_clean_log_dir;
    $self->everything;
    $self->warning;
    $self->error;
    $self->twitter;
};

around twitter => sub {
    my $orig = shift;
    my $self = shift;
    my $output = $self->$orig();
    return $output unless @_;
    my $message = shift;
    $output->log(level => 'error', message => $message, @_);
};

around [qw/everything warning error/] => sub {
    my $orig = shift;
    my $self = shift;
    die "Don't log directly to the catch-all loggers" if @_;
    return $self->$orig();
};

after add_channel => sub {
    my $self = shift;
    my $channel_name = shift;

    for my $output (@{ $self->default_outputs }) {
        $self->channel($channel_name)->add($output);
    }
};

sub log_to_channel {
    my $self         = shift;
    my $channel_name = shift;
    my $message      = shift;

    return unless $self->_should_log($channel_name);
    my $channel = $self->channel($channel_name);
    if (!$channel) {
        my $weakself = $self;
        weaken $weakself;
        # XXX: would be nice if LDC had global callbacks
        $self->add_channel($channel_name,
                           callbacks => [
                           sub {
                               my %args = @_;
                               if ($weakself->bt_levels->{$args{level}}) {
                                   return Carp::longmess($args{message});
                               }
                               else {
                                   return $args{message};
                               }
                           },
                           sub {
                               my %args = @_;
                               return sprintf "[%s:%s] %s",
                                              uc($args{level}),
                                              $channel_name,
                                              $args{message};
                           },
                           ]);
        $self->add(Log::Dispatch::File->new(
                       name      => $channel_name,
                       min_level => $self->_default_min_level,
                       filename  => logfile_for($channel_name),
                       callbacks => sub { _format(@_) },
                   ),
                   channels => $channel_name);
    }
    $self->log(channels => $channel_name,
               level    => 'debug',
               message  => $message,
               @_);
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;

    my $channel_name = $AUTOLOAD;
    $channel_name =~ s/.*:://;

    $self->log_to_channel($channel_name, @_);
}

sub add_as_default {
    my $self = shift;
    my $output = shift;

    $self->add($output);
    push @{ $self->default_outputs }, $output;
}

sub _format {
    my %args = @_;

    chomp $args{message};

    my ($sec, $min, $hour, $mday, $mon, $year) = localtime;

    return sprintf "<T%s> %04d-%02d-%02d %02d:%02d:%02d %s\n",
                   (TAEB->loaded_persistent_data
                && defined TAEB->senses # i.e. not yet cleaned up
                 ? TAEB->turn
                 : '-'),
                   $year + 1900,
                   $mon + 1,
                   $mday,
                   $hour,
                   $min,
                   $sec,
                   $args{message};
}

sub _default_min_level {
    my $self = shift;
    my $log_config = $self->config;
    return 'debug' unless defined $log_config
                       && exists  $log_config->{min_level};
    return $log_config->{min_level};
}

sub _should_log {
    my $self = shift;
    my ($channel) = @_;
    # don't treat DEMOLISH as a logging call, etc
    return if $channel =~ /^[A-Z_]+$/;
    my $log_config = $self->config;
    if (defined $log_config && exists $log_config->{suppress}) {
        my $suppression = $log_config->{suppress};
        if (ref($suppression) eq 'ARRAY') {
            return if grep { $channel eq $_ } @$suppression;
        }
        elsif ($suppression =~ s{^/(.*)/$}{$1}) {
            return if $channel =~ /$suppression/;
        }
        else {
            return if $channel eq $suppression;
        }
    }
    return 1;
}

sub _maybe_create_dir {
    my $dir = shift;
    my $dir_reason = shift;
    if (!-d $dir && !mkdir $dir) {
        warn "Please make a writable $dir_reason directory at $dir";
        return 0;
    }
    return 1;
}

sub logfile_for {
    my $channel = shift;

    # if we can't open or create the logdir, then just put logs into the current
    # directory :/
    my $logdir = TAEB->config->taebdir_file("log");
    return "TAEB-$channel.log" unless _maybe_create_dir($logdir, "log file");
    return TAEB->config->taebdir_file("log", "$channel.log");
}

sub _creation_time {
    open my $everything, "<", logfile_for("everything") or return;
    my $start_line = <$everything>;
    return unless $start_line;
    $start_line =~ s/^<T-> (\S+ \S+).*/$1/;
    $start_line =~ /(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/;
    return ($1, $2, $3, $4, $5, $6);
}

sub _backup_logs {
    my $self = shift;
    my ($config) = @_;

    return unless _maybe_create_dir(TAEB->config->taebdir_file($config->{dir}),
                                    "log rotate");

    my ($year, $mon, $mday, $hour, $min, $sec) = $self->_creation_time;
    return unless defined $year;
    my $timestamp = sprintf "%04d%02d%02d%02d%02d%02d", $year, $mon, $mday,
                                                        $hour, $min, $sec;

    TAEB->display_topline("Backing up logfiles...");
    my $compress = $config->{compress};
    require File::Copy;
    require IO::Compress::Gzip if $compress;
    for my $file (glob logfile_for('*')) {
        TAEB->display_topline("Backing up logfiles... ($file)");
        (my $backup = $file) =~ s{(?:.*/)?(.*?)}{$1};
        $backup = TAEB->config->taebdir_file($config->{dir},
                                             "$backup.$timestamp");
        File::Copy::copy($file, $backup);
        if ($compress) {
            IO::Compress::Gzip::gzip($backup => "$backup.gz");
            unlink $backup;
        }
    }
    TAEB->display_topline('');
}

before _clean_log_dir => sub {
    my $self = shift;
    return unless -d TAEB->config->taebdir_file("log");
    return unless defined $self->config;
    my $log_rotate_config = $self->config->{log_rotate};
    return unless $log_rotate_config && $log_rotate_config->{dir};
    $self->_backup_logs($log_rotate_config);
};
sub _clean_log_dir {
    unlink for (glob logfile_for('*'));
}

__PACKAGE__->meta->make_immutable;

1;
