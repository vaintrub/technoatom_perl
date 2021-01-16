#!/usr/bin/env perl
package Local::Source::Array;
use parent qw(Local::Source);

use strict;
use warnings;
use 5.016;

sub next {
    my $self = shift;
    return $self->{array}->[$self->inc_iter()];
}

sub hasNext {
    my $self = shift;
    if ($self->{iter} < @{$self->{array}}){
        return 1;
    }
    
    return 0;
}

1;
