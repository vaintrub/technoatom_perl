#!/usr/bin/env perl

use 5.016;
use warnings;
use strict;

my ($haystack, $needle) = @ARGV;
if (@ARGV == 2) {
	my $index = index($haystack, $needle);
	if ($index != -1) {
		printf("%d\n",$index);
		printf("%s\n",substr($haystack,$index));
	}else {
		warn "Substring is not detected\n";
		exit 1;
	}
}else {
	die "Wrong number of the arguments\n";
}




