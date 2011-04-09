package TAEB::Role::WeakenFix;
use Moose::Role;
use TAEB::OO;

# see http://www.nntp.perl.org/group/perl.perl5.porters/2008/11/msg142001.html
after DEMOLISHALL => sub { %{ $_[0] } = () };

no Moose::Role;
no TAEB::OO;

1;

