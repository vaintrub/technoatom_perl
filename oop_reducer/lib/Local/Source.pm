#!/usr/bin/env perl
package Local::Source;

use strict;
use warnings;
use 5.016;

sub new {
    my $class = shift;
    my (%data) = @_;
    my $self = bless \%data, $class;
    $self->restart_iter();

    return $self;
}
sub next {}

sub hasNext {}

sub inc_iter {
    my $self = shift;
    return $self->{iter}++;
}

sub restart_iter {
    my $self = shift;
    $self->{iter} = 0;
}

1;
