#!/usr/bin/env perl

use 5.016;
use warnings;
use strict;

sub _fact {
	my ($n) = @_;
	return 1 if ($n==1);
	return _fact($n-1) * $n;
}

if (@ARGV == 1) {
	my ($n) = @ARGV;
	if ($n >= 1) {
		printf("%d\n",_fact($n));
	}else {
		warn "Not a natural number\n";
		exit;
	}
}else{
	die "Wrong number of the arguments\n";
}
