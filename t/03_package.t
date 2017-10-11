#!/usr/bin/perl

package MyNewPackage;

use lib 'lib','../lib';

use strict;
use warnings;

use Test;

BEGIN { plan tests => 1 }

use Pod::Autopod;

# This is a test sub
sub test_case_1 { # $output ($param)
}

my $ap = new Pod::Autopod();
$ap->readFile(__FILE__);

ok($ap->getPod(), <<'ORIG');
=head1 NAME

MyNewPackage


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



=cut

ORIG

1;
