package TAEB::Announcement::Role::SelectSubset;
use Moose::Role;
with 'TAEB::Announcement::Role::HasMenu';

sub menu_style { 'multi' }

no Moose::Role;

1;

