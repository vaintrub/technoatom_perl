#!/usr/bin/env perl

use strict;
use warnings;
use FindBin; use lib "$FindBin::Bin/../lib";
use Test::More;

use_ok 'Local::Row::Simple';

is_deeply Local::Row::Simple->new( "" ), {}, "empty struct";
is_deeply Local::Row::Simple->new( "key:val" ), {key => "val"}, "one pair";
is_deeply Local::Row::Simple->new("a:1,b:2" ), { a => 1, b => 2 }, "two pairs";

is_deeply Local::Row::Simple->new( "test" ), undef, "no value";
is_deeply Local::Row::Simple->new( "test:test:test" ), undef, "too many colons in pair";
is_deeply Local::Row::Simple->new("test,test,test" ), undef, "record does not have value";
is_deeply Local::Row::Simple->new( "key:val,test" ), undef, "record does not have value 2";

done_testing();
