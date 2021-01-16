#!/usr/bin/env perl
package Local::Reducer::Sum;
use parent qw(Local::Reducer);

use strict;
use warnings;
use 5.016;
use Scalar::Util qw(looks_like_number);

sub reduce {
    my $self = shift;
        
    my $str = $self->{source}->next();
    my $row = $self->{row_class}->new($str);
    if (defined $row) {
        my $el = $row->get($self->{field});
        $self->{reduced} += $el if looks_like_number($el);
    }
    

    return $self;

}

1;

