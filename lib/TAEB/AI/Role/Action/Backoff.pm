package TAEB::AI::Role::Action::Backoff;
use MooseX::Role::Parameterized;

parameter action => (
    isa      => 'ClassName',
    required => 1,
);

parameter blackout_when => (
    isa      => 'CodeRef',
    required => 1,
);

parameter clear_when => (
    isa      => 'CodeRef',
    required => 1,
);

parameter filter => (
    isa     => 'CodeRef',
    default => sub { sub { 1 } },
);

parameter label => (
    isa     => 'Str',
    lazy    => 1,
    default => sub { lc(shift->action->name) },
);

parameter annotate_currently => (
    isa     => 'Bool',
    default => 1,
);

parameter max_exponent => (
    isa     => 'Int',
    default => 8,
);

role {
    my $p = shift;

    my $label         = $p->label;
    my $action_class  = $p->action;
    my $blackout_when = $p->blackout_when;
    my $clear_when    = $p->clear_when;
    my $filter        = $p->filter;
    my $max_exponent  = $p->max_exponent;

    my $clear_exponent_method  = "clear_${label}_blackout_exponent";
    my $clear_forbidden_until  = "clear_${label}_forbidden_until";
    my $exponent_method        = "${label}_blackout_exponent";
    my $failed_at_method       = "${label}_failed_at";
    my $forbidden_until_method = "${label}_forbidden_until";
    my $is_blacked_out_method  = "${label}_is_blacked_out";

    has $failed_at_method => (
        is  => 'rw',
        isa => 'Int',
    );

    has $exponent_method => (
        is      => 'rw',
        isa     => 'Int',
        clearer => $clear_exponent_method,
    );

    has $forbidden_until_method => (
        is      => 'rw',
        isa     => 'Int',
        clearer => $clear_forbidden_until,
    );

    method "$is_blacked_out_method" => sub {
        my $self = shift;
        return TAEB->turn < ($self->$forbidden_until_method||0);
    };

    my $maybe_blackout_method = sub {
        my $self = shift;
        my $prev = TAEB->previous_action;

        return unless $prev && $prev->isa($action_class);
        return unless $self->$filter($prev);

        if ($self->$blackout_when($prev)) {
            my $turn = TAEB->turn;

            $self->$failed_at_method($turn);

            my $exponent = 1 + ($self->$exponent_method || 1);

            # limit blackout length
            if ($exponent < $max_exponent) {
                $self->$exponent_method($exponent);
            }

            $self->$forbidden_until_method($turn + 2 ** $exponent);
        }
        elsif ($self->$clear_when($prev)) {
            $self->$clear_exponent_method;

            $self->$clear_forbidden_until;
        }
    };

    around next_action => sub {
        my $orig = shift;
        my $self = shift;

        $self->$maybe_blackout_method;

        my $action = $self->$orig(@_);

        return $action if !$action;

        if ($action->isa($action_class) && $self->$filter($action)) {

            if ($self->$is_blacked_out_method) {
                my $forbidden_until = $self->$forbidden_until_method;
                TAEB->log->ai("$label is blacked out until $forbidden_until but it was used anyway!", level => "error");
            }
        }

        return $action;
    };

    if ($p->annotate_currently) {
        around currently => sub {
            my $orig = shift;
            my $self = shift;

            # writer
            if (@_) { return $self->$orig(@_) }

            my $forbidden_until = $self->$forbidden_until_method;

            if ($self->$is_blacked_out_method) {
                my $turn = TAEB->turn;
                return $self->$orig
                     . " [${label}ban " . ($forbidden_until - $turn) . "]";
            }

            return $self->$orig;
        };
    }
};

1;

__END__

=head1 SYNOPSIS

    with 'TAEB::AI::Role::Action::Backoff' => {
        action        => 'TAEB::Action::Travel',
        blackout_when => sub {
            my ($self, $prev_action) = @_;
    
            return TAEB->current_tile == $prev_action->path->from;
        },
        clear_when    => sub {
            my ($self, $prev_action) = @_;
            my $original_path = $prev_action->intralevel_subpath || $prev_action->path;
            return TAEB->current_tile == $original_path->to;
        },
    };

=cut

