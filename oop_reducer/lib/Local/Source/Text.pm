#!/usr/bin/env perl
package Local::Source::Text;
use parent qw(Local::Source::Array);

use strict;
use warnings;
use 5.016;

sub new {
    my $class = shift;
    my (%data) = @_;

    $data{delimiter} = '\n' unless exists $data{delimiter};

    return $class->SUPER::new('array' => [split($data{delimiter}, $data{text})]);

}

1;
