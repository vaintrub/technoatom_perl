#!/usr/bin/env perl

use 5.016;
use warnings;
use strict;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

my $endhour = (60 - $min) * 60 - (60 - $sec);
my $endday = (24 - $hour) * 3600 - (60 - $min) * 60 - (60 - $sec);
my $endweek = (6 - $wday) * 86400 - (24 - $hour) * 3600 - (60 - $min) * 60 - (60 - $sec);

printf("to end of the hour - %d\n", $endhour);
printf("to end of the day - %d\n", $endday);
printf("to end of the week - %d\n", $endweek);

