#!/usr/bin/env perl

use 5.016;
use warnings;
use strict;

if (@ARGV == 1) {
	my ($n) = @ARGV;
	die "Not a natural number\n" if ($n <= 0);
	for (my $i = 2; $i <= $n; $i++) {
		my $k = 0;
		for (my $j = 1; $j <= $n; $j++) {
			if ($i % $j == 0) {
				$k++;
			}
		}
		if ($k == 2) {
			printf("%d ",$i);
		}
	}
	print "\n";


}else{
	die "Wrong number of arguments\n";
}
