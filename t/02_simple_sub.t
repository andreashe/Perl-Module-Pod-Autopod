#!/usr/bin/perl

use lib 'lib','../lib';

use strict;
use warnings;

use Test;

BEGIN { plan tests => 1 }

use Pod::Autopod;

# This is a test sub
# @param single parameter
sub test_case_1 { # $output ($param)
}

sub test_case_2 { # $a,$b,$c (\@aref,\%href)
}

# @return nothing it really returns nothing
sub test_case_3 {
}

my $ap = new Pod::Autopod();
$ap->readFile(__FILE__);

ok($ap->getPod(), <<'ORIG');
=head1 NAME

t::02_simple_sub.t - t::02_simple_sub.t


=head1 DESCRIPTION

!/usr/bin/perl


=head1 REQUIRES

L<Pod::Autopod> 

L<Test> 

L<lib> 


=head1 METHODS

=head2 test_case_1

 my $output = test_case_1($param);

This is a test sub

parameter: single parameter



=head2 test_case_2

 my ($a, $b, $c) = test_case_2(\@aref, \%href);

=head2 test_case_3

 test_case_3();


returns  it really returns nothing




=cut

ORIG

1;
