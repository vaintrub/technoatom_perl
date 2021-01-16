#!/usr/bin/env perl

use 5.016;
use warnings;
use strict;

my $b, my $c, my $a;

if (@ARGV > 3 || @ARGV < 1 ) {
	die "Wrong number of argument\n";
}elsif (@ARGV == 2) { 
	($a,$b) = @ARGV;
	$c = 0;
}elsif (@ARGV == 1) {
	($a) = @ARGV;
	$b = 0;
	$c = 0;
}else {
	($a,$b,$c) = @ARGV;
}

if ($a == 0) {
	die "Not quadratic\n";
}

printf("Please, enter the number of decimal places\n");
my $s =<STDIN>;
chomp($s);

my $x1, my $x2;
my $d = $b*$b - 4 * $a *$c;

if ($d > 0) {
	$x1 = ((-1)*$b + sqrt($d))/(2*$a);
	$x2 = ((-1)*$b - sqrt($d))/(2*$a);
	printf("%.${s}f, %.${s}f\n",$x1, $x2);
}elsif ($d < 0) { #imaginary solution
	my $re, my $im;
	$re = ((-1)*$b)/(2*$a);
	$im = sqrt(abs($d))/(2*$a);
	printf("%.${s}f+%.${s}fi, %.${s}f-%.${s}fi\n",$re, $im, $re, $im);
}else {
	$x1 = ((-1)*$b)/(2*$a);
	printf("%.${s}f\n",$x1);
}



# die "Not implemented";
