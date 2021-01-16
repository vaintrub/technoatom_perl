#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Scalar::Util;

use Local::Reducer;
use Local::Reducer::Sum;
use Local::Reducer::MaxDiff;
use Local::Reducer::MinMaxAvg;
use Local::Row;
use Local::Row::Simple;
use Local::Row::JSON;
use Local::Source;
use Local::Source::Array;
use Local::Source::FileHandler;
use Local::Source::Text;

open (my $fh, "<:encoding(UTF-8)","file.txt") or die "cant open file\n";


print "______________________EXAMPLE FOR Local::Reducer::MinMaxAvg_________________________\n";

my $reducer1 = Local::Reducer::MinMaxAvg->new(
    field => 'price',
    source => Local::Source::FileHandler->new(fh => $fh),
    row_class => 'Local::Row::JSON',
    initial_value => 0,
);


my $r = $reducer1->reduce_n(6);
$r = $reducer1->reduce_all();
print "Max: ";
say $r->get_max();
print "Min: ";
say $r->get_min();
print "Avg: ";
say $r->get_avg();


print "\n\n";
print "______________________EXAMPLE FOR Local::Reducer::MaxDiff__________________________\n";

my $reducer2 = Local::Reducer::MaxDiff->new(
    top => 'received',
    bottom => 'sended',
    source => Local::Source::Text->new(text =>"sended:1024,received:2048\nsended:2048,received:10240"),
    row_class => 'Local::Row::Simple',
    initial_value => 0,
);
$reducer2->reduce_all();
print "MaxDiff: ";
say $reducer2->reduced();
print "\n\n";


print "______________________EXAMPLE FOR Local::Reducer::Sum______________________________\n";

my $reducer3 = Local::Reducer::Sum->new(
    field => 'price',
    source => Local::Source::Array->new(array => [
        '{"price": 1}',
        '{"price": 2}',
        '{"price": 3}',
    ]),
    row_class => 'Local::Row::JSON',
    initial_value => 0,
);

$reducer3->reduce_all();
print "Sum: ";
say $reducer3->reduced();
print "\n\n";

close($fh);

