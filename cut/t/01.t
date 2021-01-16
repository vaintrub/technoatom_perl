#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use IPC::Open3;
use Data::Dump qw/pp/;

use open ':encoding(UTF-8)';
use utf8;
use charnames ':full';
use Encode qw( encode_utf8 decode_utf8 );


my ($stdin, $stdout, $stderr);
use Symbol 'gensym';
my $binfile = 'cut.pl';
my ($buf, $pid);

sub check {
    my ($test_name, $args, $input, %params) = @_;

    ($stdin, $stdout, $stderr) = ("","","");
    $stderr = gensym;
    $pid = open3($stdin, $stdout, $stderr, '/usr/bin/perl', "bin/$binfile", @$args) or fail("Cant open3 your $binfile implementation: $!");

    print $stdin encode_utf8($input);# or die "Cant write all the input! $!";
    ok(close($stdin), "$test_name: close STDIN");

    $buf = '';
    for (qw/stdout stderr/) {
        my $stream_out = $params{$_} or next;
        my $stream = { stdout => $stdout, stderr => $stderr }->{$_};

        warn sysread($stream, $buf, 2 * length($stream_out)+ 100);

        chomp $buf;
        chomp $stream_out;
        # warn $output;
        is(decode_utf8($buf), $stream_out, $test_name);
        ok(close($stream), "$test_name: close $_");
    }

    is(waitpid($pid, 0), $pid, "$test_name: exited");
    is($? >> 8, $params{exit_status} // 0, "$test_name: exit status ok");
}

sub get_seq {
    return join "\n", @_;
}

# просто генерим строчку таблички
sub gen_table {
    my $seed = shift;
    my @columns = sort @_;

    my @res;
    for my $c (@columns) {
        if($c == 1) {
            push @res,  ($seed-2) . " " . ($seed-1);
        }
        elsif ($c == 2) {
            push @res,  $_;
        }
        elsif ($c == 3) {
            push @res,  $_ << 2;
        }
        else {
            push @res,  $_ << 1;
        }
    }

    return join "\t", @res;
}

my $simple_input = get_seq(map { gen_table($_, 1..4) } 1..15);
# die "\n".$simple_input;

# bad args tests

check("No args",    [],           $simple_input, exit_status => 1, stderr => "cut: you must specify a list of fields");
check("Bad delim",  ["-d=123"], $simple_input,   exit_status => 1, stderr => "cut: the delimiter must be a single character");
check("Zero field",  ["-f=0"],  $simple_input,   exit_status => 1, stderr => "cut: fields are numbered from 1");

my $KK = 1_000_001;
check("Too large field",  ["-f=$KK"],  $simple_input, exit_status => 1, stderr => "cut: field number '$KK' is too large");
check("Decreasing range",  ["-f=2-1"], $simple_input, exit_status => 1, stderr => "cut: invalid decreasing range");

my $cadabra = "abra";
check("Invalid field",  ["-f=$cadabra"], $simple_input, exit_status => 1, stderr => "cut: invalid field value '$cadabra'");

# fields test
check("Field N",    ["-f=2"],   $simple_input, stdout => get_seq(1..15));
check("Field N-M",  ["-f=2-3"], $simple_input, stdout => get_seq(map { gen_table($_, 2..3) } 1..15));
check("Field N-",   ["-f=2-"],  $simple_input, stdout => get_seq(map { gen_table($_, 2..4) } 1..15));
check("Field -M",   ["-f=-2"],  $simple_input, stdout => get_seq(map { gen_table($_, 1..2) } 1..15));

check("Field list #1",   ["-f=-2,4"],   $simple_input, stdout => get_seq(map { gen_table($_, 1, 2, 4) } 1..15));
check("Field list #2",   ["-f=4,1"],    $simple_input, stdout => get_seq(map { gen_table($_, 1, 4) } 1..15));
check("Field list #3",   ["-f=3-,1,1"], $simple_input, stdout => get_seq(map { gen_table($_, 1, 3, 4) } 1..15));
check("Field list #3",   ["-f=2-3,1"],  $simple_input, stdout => get_seq(map { gen_table($_, 1, 2, 3) } 1..15));

check("Big field num", ["-d=\ ", "-f=100"], get_seq((100) x 10), stdout => get_seq(("") x 11));


# delimeter test
my $expected_output = <<OUTPUT;
-1 

1 2	3	12	6
2 3	4	16	8
3 4	5	2
4 5	6	24	12
5 6	7	28	14
6 7	8	32	16
7 8	9	36	18
8 9	1
9 1
1
11 12	13	52	26
12 13	14	56	28
13 14	15	6
OUTPUT

check("Zero delim test", ["-d=0", "-f=1"], $simple_input, stdout => $expected_output);

# separated test
$expected_output = <<OUTPUT;
-1 0	1	4	2
0 1	2	8	4
3 4	5	20	1
8 9	10	40
9 10	11	44	22
10 11	12	48	24
13 14	15	60	3
OUTPUT

check("Separated test", ["-s", "-d=0", "-f=-2,4"], $simple_input, stdout => $expected_output);

my $challenging = get_seq((join(" ", 1..1_000_000)) x 100);
# print $challenging;
check("A lot of seps", ["-d= ", "-f=100"], $challenging, stdout => get_seq((100) x 100));

done_testing();