#!/usr/bin/env perl
use 5.016;
use Term::ANSIColor;
use strict;
use warnings;
use Data::Dumper;
use Pod::Usage;
use Getopt::Long qw(:config bundling);
use utf8;
use Encode qw(decode encode);
#use open ':std', ':encoding(UTF-8)';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');

#OPTIONS
my $after = 0;
my $before = 0;
my $context = 0;
my $count = 0;
my $ignoreCase = 0;
my $invert = 0;
my $fixed = 0;
my $lineNum = 0;
my $help = 0;
my $man = 0;

#Getting the options
GetOptions ("after|A=i" => \$after,
			"before|B=i" => \$before,
			"context|C=i" => \$context,
			"count|c" => \$count,
			"ignoreCase|i" => \$ignoreCase,
			"invert|v" => \$invert,
			"fixed|F" => \$fixed,
			"lineNum|n" => \$lineNum,
			"help|h" => \$help,
			"man"=> \$man) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;


## Check for too many arguments
pod2usage("$0: Too many arguments given.\n")  if (@ARGV > 1);

## Check for enough number of arguments
pod2usage("$0: You must give one search pattern\n")  if (@ARGV == 0);


my ($pattern) = @ARGV;

my $buffer = {}; #store in the buffer only the lines that came before the current line (and only $size strings)
my $size; #buffer size
my $c = 0; #counter 
my $line;
my $compRef; #comparison conditions
my $num = 0;

if ($after) {
	$size = $after;
}elsif ($context) {
	$size = $context;
}elsif ($before) {
	$size = $before;
}


#we decode the pattern because it is obtained from @ARGV and not from stdin
$pattern = decode('UTF-8', $pattern);


sub _output {    #string output function
	my ($line) = @_;
	my $position, my $pos = 0;


	if ($lineNum) { #if -n then there will be line numbering
		if (($num % 2) == 0) {
			print "$num:";
		}else{
			print "$num-";
		}
	}
	if (!$invert) {
		while ($line =~ /$pattern/gp){
			$position = pos($line);
			print substr($line, $pos, $position - length (${^MATCH}) - $pos);
			print colored("${^MATCH}", 'red');
			$pos = $position;
		}
	}
	print substr($line, $pos);
	print "\n";

}

# handling flags -invert, -fixed, -ignoreCase.

#$pattern =~ s#([\(\)\[\{\*\+\.\$\^\\\|\?])#\\$1#g;
$pattern =  quotemeta($pattern) if $fixed; #to find a fixed string, we need to escape all special characters

# forming a comparator function ($compRef)
if ($ignoreCase) {
	$compRef = sub {$_[0] =~ /$pattern/ig};
	$pattern = qr/$pattern/i;	#only for colored output, it is not possible to pass compRef to _output
										# for the pos() function to work correctly
}else{
	$compRef = sub {$_[0] =~ /$pattern/g};
	$pattern = qr/$pattern/;	#only for colored output
}




my $flag = 0;
my $i = 0;
my $j = -1;
if (!$count) { 

	while (defined($line = <STDIN>)) {
		chomp($line);
		$num++; #counter of lines

		if(&$compRef($line) xor $invert){
			if ($j == 0 && $flag == 0 && ($after || $context)){
				print "--\n";
			}
			if (%$buffer && $j!=-1 && ($before || $context)) {
				print "--\n";
			}
			if ($before || $context) { #output lines from the buffer
				for ($num - $size..$num + 1){
					if (exists $buffer->{$_}){
						_output($buffer->{$_});
						delete $buffer->{$_};
					}
				}
			}

			$flag = 1; # было совпадение
			$j = 0; # нужно еще снизу вывести $size строк

			_output($line);
		}else{

			$buffer->{$num} = $line if ($before || $context);

			if ($after || $context) {
				if ($flag && $j!=$size) {
					_output($line);
					$j++;
				}
				if ($j == $size){
					$j = 0;
					$flag = 0;
				}
			}


		}

		
	} continue {
		delete $buffer->{$num - $size} if ($before || $context); #clean the buffer
	}

}else {
	while (defined($line = <STDIN>)){
		chomp($line);
		if (&$compRef($line) xor $invert){
			$c++;
		}
	}
	print "$c\n";
}


__END__

=head1 NAME
 
grep - print lines matching a pattern
 
=head1 SYNOPSIS
 
perl grep  [OPTIONS]  PATTERN
 
 Options:
   --help            brief help message
   --man             full documentation
   -A               [num]
   -B               [num]
   -C               [num]
   -c               Without Arg
   -i               Without Arg
   -v               Without Arg
   -F               [string]
   -n               Without Arg
 
=head1 OPTIONS

=head2 -F, --fixed
Interpret PATTERN as a list of fixed strings, separated by newlines, any of which is to be matched.

=head2 -i, --ignoreCase

Ignore case distinctions in both the PATTERN and the input files.

=head2 -v, --invert

Invert the sense of matching, to select non-matching lines.

=head2 -c, --count

Suppress normal output; instead print a count of matching lines for each input file.
With the -v, --invert-match option (see below), count non-matching lines.

=head2 -n, --lineNum

Prefix each line of output with the 1-based line number within its input file. 

=head2 -A NUM, --after=NUM, --A=NUM

Print NUM lines of trailing context after matching lines.

=head2 -B NUM, --before=NUM, --B=NUM

Print NUM lines of leading context before matching lines.

=head2 -C NUM, --context=NUM, --C=NUM

Print NUM lines of output context.


=head1 DESCRIPTION
 
grep searches standard input for lines containing a match to the given PATTERN.
By default, grep prints the matching lines.
 
=cut
