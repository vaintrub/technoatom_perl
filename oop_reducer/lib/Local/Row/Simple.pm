#!/usr/bin/env perl
package Local::Row::Simple;
use parent qw(Local::Row);

use strict;
use warnings;
use 5.016;

sub new {
    my $class = shift;
    my $str = shift;
    my $self = {};

    bless $self, $class;

    $str = [split(/,/,$str)];
    for (@$str) {
        if (/^\s*([^,:\s]+)\s*:\s*([^,:]*)\s*$/) {
            $self->{$1}=$2;
        }else {
             $self = undef;
        }
    }

    return $self; 
}

1;
