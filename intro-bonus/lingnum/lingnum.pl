#!/usr/bin/env perl

use 5.016;
use warnings;
use strict;
use Data::Dumper;

my ($number) = @ARGV;

my @units = qw(один два три четыре пять шесть семь восемь девять);
my @unitsFr11To19 = qw(одиннадцать двенадцать тринадцать четырнадцать пятнадцать шестнадцать семнадцать восемнадцать девятнадцать);
my @dozens = qw(десять двадцать тридцать сорок пятьдесят шестьдесят семьдесят восемьдесят девяносто);


if (@ARGV == 1) {
	if ($number <= 0) {
		die "Not a natural number\n";
	}

	#I split the number into three digits
	my $length = length $number;
	my @triplets;
	@triplets= ( substr($number, $length % 3) =~ m/.../g );
	unshift (@triplets, substr($number, 0, $length % 3 )) if ($length % 3 !=0);

	my $numtr = @triplets;
	my $d1, my $d2, my $d3;
	my $res;

	for my $triplet (@triplets) {
		$d1 = 0;
		$d2 = 0;
		$d3 = 0;
		if ($numtr == @triplets && length $triplet !=3) { #I divide triplets into 3 separate numbers
			if (length $triplet == 1) {
				$d3 = $triplet;
			}elsif (length $triplet == 2) {
				$d2 = int($triplet / 10);
				$d3 = $triplet % 10;
			}
		}else {
			$d1 = int($triplet / 100);
			$d2 = int(($triplet % 100) / 10);
			$d3 = $triplet % 10;
		}

		if ($d1 >= 5 && $d1 <= 9) {
			$res .= $units[$d1-1] . "сот ";
		}elsif ($d1 == 4 || $d1 == 3) {
			$res .= $units[$d1-1] . "ста ";
		}elsif ($d1 == 2) {
			$res .="двести ";
		}elsif ($d1 == 1) {
			$res .="сто ";
		}

		if ($d2 >=2 && $d2 <= 9) {
			$res .= $dozens[$d2-1] . " ";
		}elsif ($d2 == 1 ) {
			if ($d3 == 0) {
				$res .= $dozens[0] . " ";
			}else {
				$res .= $unitsFr11To19[$d3-1] . " ";
			}
		}
		if ($d2 != 1) {

			if ($d3 >= 3 && $d3 <= 9) {

				 $res .= $units[$d3-1] . " ";

			}elsif ($d3 == 2) {

				if ($numtr == 2) {
				 	$res .= "две ";
				}else {
					$res .= "два ";
				}

			}elsif ($d3 == 1) {

				if ($numtr == 2) {
					$res .= "одна ";
				}else {
					$res .= "один ";
				}

			}
		}
		if ($d3 >= 5 && $d3 <= 9) { #Add the end of the triplet

			if ($numtr == 4) {
				$res .= "миллиардов ";
			}elsif ($numtr == 3) {
				$res .= "миллионов ";
			}elsif ($numtr == 2) {
				$res .= "тысяч ";
			}

		}elsif ($d3 >= 2 && $d3 <= 4) {

			if ($numtr == 4) {
				$res .= "миллиарда ";
			}elsif ($numtr == 3) {
				$res .= "миллиона ";
			}elsif ($numtr == 2) {
				$res .= "тысячи ";
			}

		}elsif ($d3 == 1) {

			if ($d2 == 1) {
				if ($numtr == 4) {
					$res .= "миллиардов ";
				}elsif ($numtr == 3) {
					$res .= "миллионов ";
				}elsif ($numtr == 2) {
					$res .= "тысяч ";
				}
			}else {

				if ($numtr == 4) {
					$res .= "миллиард ";
				}elsif ($numtr == 3) {
					$res .= "миллион ";
				}elsif ($numtr == 2) {
					$res .= "тысяча ";
				}
			}

		}elsif ( ($d1 != 0 && $d3==0) || ($d1 == 0 && $d2==1) || ($d1 == 0 && $d2!=0 && $d3==0) ) {
			if ($numtr == 4) {
				$res .= "миллиардов ";
			}elsif ($numtr == 3) {
				$res .= "миллионов ";
			}elsif ($numtr == 2) {
				$res .= "тысяч ";
			}
		}

		# say $d1;
		# say $d2;
		# say $d3;
		# print "numbertr - $numtr;\n";
		
		$numtr--;
	}


	# say Dumper(@triplets);


say $res;

}else {

	die "Wrong number of arguments\n"; 
}
