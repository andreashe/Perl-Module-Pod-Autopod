#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;

my @modules = qw(
FileHandle;
Pod::Abstract
Pod::Abstract::BuildNode
);

foreach my $module (@modules) {
    eval " use $module ";
    ok(!$@, "$module compiles");
}

1;
