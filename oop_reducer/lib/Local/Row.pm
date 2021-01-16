#!/usr/bin/env perl
package Local::Row;

use strict;
use warnings;
use 5.016;

sub new {}

sub get {
    my $self = shift;
    my $field = shift;
    return $self->{$field};
}

1;


