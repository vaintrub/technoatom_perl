#!/usr/bin/env perl

use 5.016;
use warnings;

sub _fib { 
	my ($n,$x,$y) = @_;
	if ($n) {

    	@_ = ( $n-1, $y, $x+$y ); goto &_fib;
	}
	else {

		return $x+$y;
	}
}

if (@ARGV == 1) {
	my ($n) = @ARGV;

	if ($n == 0) {
		printf("%d\n", 0);
		exit 0;
	}elsif ($n == 1) {
		printf("%d\n", 1);
		exit 0;
	}
	
	if ($n > 1) {
		printf("%d\n", _fib($n-2,0,1));
	}else {
		warn "Not a natural number\n";
		exit;
	}
}else {
	die "Wrong number of arguments\n";
}
