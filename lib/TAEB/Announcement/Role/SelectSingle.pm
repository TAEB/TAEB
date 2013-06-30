package TAEB::Announcement::Role::SelectSingle;
use Moose::Role;
with 'TAEB::Announcement::Role::HasMenu';

sub menu_style { 'single' }

no Moose::Role;

1;

