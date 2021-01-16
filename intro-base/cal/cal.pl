#!/usr/bin/env perl

use 5.016;
use warnings;
use diagnostics;
use strict;

use Time::Local 'timelocal';
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime(time); #got the today's date

#I suppose that this task is only about 2020.
my @numOfDayInMon = (31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
my $dayOfW;

sub _output {

	my ($numOfDayInMonref, $day, $month) = @_;
	my @months = qw(January February March April May June July August September October November December);
	my @daysOfW = qw(Mo Tu We Th Fr Sa Su);

	printf("     %s 2020\n",$months[$month-1]);
		print(" @daysOfW\n");
		printf("   ") for(0..$day-1);
		for (my $i=0; $i < $$numOfDayInMonref[$month-1]; $i++) {
			if ($day == 7) {
				$day = 0;
				printf("\n");
			}

			$day++;
			printf("%3d",$i + 1);
		}

		printf("\n");
}

sub _findDayOfWeek {
	my ($numOfDayInMonref, $month)=@_;
	my $sum = 0, my $day;
	if ($month >= 1 && $month <= 12) {
		for (my $i=0; $i < $month-1; $i++) {
			$sum += $$numOfDayInMonref[$i];
		}

		$day = ((($sum % 7) + 3 - 1) % 7);# +3 because 1st January is Wednesday
	}
}

if (@ARGV == 1) { #checking that an argument was received
	my ($month) = @ARGV;
	if ($month >= 1 && $month <= 12) {
		$dayOfW = _findDayOfWeek(\@numOfDayInMon, $month);	
		_output(\@numOfDayInMon, $dayOfW, $month);
	}else {

		die "Month is out of range\n";
	}

}elsif (not @ARGV) { #current month
	$dayOfW = _findDayOfWeek(\@numOfDayInMon, $mon+1);	
	_output(\@numOfDayInMon, $dayOfW, $mon+1);
}else {

	die "Wrong number of arguments\n";
}
