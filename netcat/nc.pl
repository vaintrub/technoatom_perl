#!/usr/bin/env perl

use strict;
use warnings;
use 5.016;
use IO::Socket;

my $host = shift @ARGV;
my $port = shift @ARGV;
my $sock = IO::Socket::INET->new(
    PeerAddr => $host,
    PeerPort => $port,
    Proto => "tcp",
    Type => SOCK_STREAM) or die "Can't connect to $host $/";

while (my $data = <STDIN>) {
    print {$sock} $data;
}

