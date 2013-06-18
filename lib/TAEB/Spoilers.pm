package TAEB::Spoilers;
use Moose;

use Module::Pluggable (
    require          => 1,
    sub_name         => 'load_spoiler_classes',
    search_path      => [__PACKAGE__],
    on_require_error => sub { confess "Couldn't require $_[0]: $_[1]" },
);
__PACKAGE__->load_spoiler_classes;

1;

