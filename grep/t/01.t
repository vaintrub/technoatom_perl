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
my $binfile = 'grep.pl';
my ($buf, $pid);

sub check {
    my ($grep_args, $input, $output, $test_name) = @_;

    ($stdin, $stdout, $stderr) = ("","","");
    # $stderr = gensym;
    $pid = open3($stdin, $stdout, $stderr, '/usr/bin/perl', "bin/$binfile", "--no-color", @$grep_args) or fail("Cant open3 your $binfile implementation: $!");

    # pp(length $input, length $output);
    # pp($stdin, $stdout, $stderr);
    print $stdin encode_utf8($input);# or die "Cant write all the input! $!";
    ok(close($stdin), "$test_name: close STDIN");
    $buf = '';
    sysread($stdout, $buf, 1024);
    # warn $buf;
    chomp $buf;
    chomp $output;
    # warn $output;
    is(decode_utf8($buf), $output, $test_name);

    ok(close($stdout), "$test_name: close STDOUT");
    is(waitpid($pid, 0), $pid, "Check finish: $test_name");
}

sub get_seq {
    return join "\n", @_;
}

my ($pattern, @range);
@range = 1..10;

$pattern = '.*';
check([$pattern], get_seq(@range), get_seq(@range), "Simple seq");

$pattern = '1';
check([$pattern], get_seq(@range), get_seq( grep { /$pattern/ } @range), "Simple seq with /$pattern/");

# context tests
check([$pattern, "-A=2"], get_seq(@range), join("\n", qw/1 2 3 10/), "Testing -A");
check([$pattern, "-B=2"], get_seq(@range), join("\n", qw/1 8 9 10/), "Testing -B");
check([$pattern, "-C=2"], get_seq(@range), join("\n", qw/1 2 3 8 9 10/), "Testing -C");


# count tests
check([$pattern, "-c"], get_seq(@range), 2, "Count test simple");
check([$pattern, "-c", "-C=2"], get_seq(1..100), 20, "Count test context");
check([$pattern, "-c", "-C=2", "-v"], get_seq(1..100), 80, "Count test invert");

#invert test
check([$pattern, "-v"], get_seq(@range), get_seq(grep { ! m/$pattern/ } @range), "Invert test simple");
check([$pattern, "-C=2", "-v"], get_seq(@range), get_seq(@range), "Invert test with context");

#test fixed
$pattern = '[^2a-b]?.{1,}+(.*).?|^$';
my @test_seq = get_seq(1..3, $pattern, 'a'..'z', '');
check([$pattern, "-F"], @test_seq, $pattern, "Fixed test simple");

#test flexible
check([$pattern], @test_seq, @test_seq, "Flexible test simple");

#test linenum
check(["\\d", "-n"], get_seq(1..30), get_seq(map { sprintf "$_%s$_", $_ % 2 ? '-' : ':' } 1..30), "Invert test simple");

#test ignore case
@test_seq = ("\N{LATIN CAPITAL LETTER SHARP S}", "a".."c");
check(["^(?:ss|[A-C])\$", "-v"], get_seq(@test_seq), get_seq(@test_seq), "Ignore case simple");

done_testing();