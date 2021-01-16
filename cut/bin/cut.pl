#!/usr/bin/env perl
use 5.016;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use utf8;
use Encode qw(encode decode);
use Pod::Usage;
use List::MoreUtils qw/ uniq /; # deletes all the same elements in an array
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

#OPTIONS
my $fields = 0;
my $delimiter = "\t"; #default - \t
my $separated = 0;
my $help = 0;
my $man = 0;

pod2usage("You must give at least one option.\n")  if (@ARGV == 0);

GetOptions ("fields=s" => \$fields,
			"delimiter=s" => \$delimiter,
			"separated" => \$separated,
			"help|?" => \$help,
			"man" => \$man
			) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;


my $inf = 0; # it is a flag. If " -f 2- " 2.....inf
$fields =~ s/(\d+)-(\d+)/join ',', ($1..$2)/ge; # replace 2-5 with this 2,3,4,5
$fields =~ s/-(\d+)/join ',', (1..$1)/ge; # replace -5 with this 1,2,3,4,5
if ($fields =~ /(\d+)-/){
    $inf = 1; # we have inf
    $fields =~ s/(\d+)-/join ',', ($1)/ge; # add only beggining of infinity to the string
}
$fields = [split(/,/,$fields)]; 
@$fields = uniq @$fields; # delete the same elemets
@$fields = map {$_ - 1} @$fields; # because in @match columns are numbered from 0
@$fields = sort @$fields; 

$delimiter = decode('UTF-8', $delimiter);

my @match;
my $last = 0; # the element from which infinity begins. For example: "-f 1,2,3,1-" infinity begins from 3 but not 1.
while (defined(my $line = <STDIN>)) {
	chomp($line);
    my $flag = 0;
	@match = $line =~ /(?|^([^$delimiter]*?)(?=$delimiter)|$delimiter([^$delimiter]*?)(?=$delimiter)|$delimiter([^$delimiter]*?)$)/g;

	if (@match != 0) { #if the current line not matched

		for (@$fields) {
			if ($_ < @match) {
				print $delimiter if ($flag); #outout of delimiter between columns
				print $match[$_];
                $flag = 1;
				$last = $_;
			}
		}
		if ($inf) { #end the output if there was infinity
            my $till = $#match;
			for ($last+1..$till){
				print $delimiter if ($flag);
				print $match[$_];
                $flag = 1;
			}
		}
		print "\n";
	}else {
		if (!$separated) {
			print "$line\n";
		}
	}

	@match = ();
}

__END__

=head1 NAME
 
cut - remove sections from each line of files
 
=head1 SYNOPSIS

 perl cut [OPTIONS]
 
 Options:
   -help         brief help message
   -man          full documentation
   -f            [LIST] for example, [1,2,3] or [1-] or [-5] or [1-5]
   -d            [char] default - \t
   -s            without arg.
 
=head1 OPTIONS

=head2 -d, --delimiter=DELIM

use DELIM instead of TAB for field delimiter

=head2 -f, --fields=LIST

select only these fields; also print any line that contains no delimiter character, unless the -s option is specified

=head2 -s, --separated

do not print lines not containing delimiters

 
=head1 DESCRIPTION
 
Print selected parts of lines from each FILE to standard output.
 
=cut
