#!/usr/bin/perl

use lib 'lib','../lib';

use strict;
use warnings;

use Test;

BEGIN { plan tests => 1 }

use Pod::Autopod;

# This is a parent sub
# with description on the other line
sub parent_sub
{ # $output ($param)

    # This is a child sub
    sub child_sub { # void ($a,$b)
    }

    my $anonymous_sub =
    sub {
    }
}

my $ap = new Pod::Autopod();
$ap->readFile(__FILE__);

ok($ap->getPod(), <<'ORIG');
=head1 NAME

t::06_complicated_syntax.t - t::06_complicated_syntax.t


=head1 DESCRIPTION

!/usr/bin/perl


=head1 REQUIRES

L<Pod::Autopod> 

L<Test> 

L<lib> 


=head1 METHODS

=head2 child_sub

 child_sub($a, $b);

This is a child sub


=head2 parent_sub

 parent_sub();

This is a parent sub
with description on the other line



=cut

ORIG

1;
