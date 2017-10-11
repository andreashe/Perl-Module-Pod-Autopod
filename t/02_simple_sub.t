#!/usr/bin/perl

use lib 'lib','../lib';

use strict;
use warnings;

use Test;

BEGIN { plan tests => 1 }

use Pod::Autopod;

# This is a test sub
# @param single parameter
sub test_case { # $output ($param)
    return 1;
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

=head2 test_case

 my $output = test_case($param);

This is a test sub

parameter: single parameter




=cut

ORIG

1;
