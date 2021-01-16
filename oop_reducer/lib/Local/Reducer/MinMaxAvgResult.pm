#!/usr/bin/env perl
package Local::Reducer::MinMaxAvgResult;

use strict;
use warnings;
use 5.016;

sub new {
    my $class = shift @_;
    my (%data) = @_;
    my $self = \%data;
    return bless $self, $class;
}

sub inc_counter{
    my $self = shift;
    $self->{count}++;
}
sub add_sum {
    my $self = shift;
    my $el = shift;
    $self->{sum} += $el;
}
sub get_avg {
    my $self = shift;
    $self->{avg} = $self->{sum}/$self->{count};
    return $self->{avg};
}

sub get_min {
    my $self = shift;
    return $self->{min};
}

sub get_max {
    my $self = shift;
    return $self->{max};
}

1;
