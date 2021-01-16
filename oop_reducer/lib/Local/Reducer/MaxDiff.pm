#!/usr/bin/env perl
package Local::Reducer::MaxDiff;

use parent qw(Local::Reducer);

use strict;
use warnings;
use 5.016;
use Scalar::Util qw(looks_like_number);

sub reduce {
    my $self = shift;
    my $str = $self->{source}->next();
    my $row = $self->{row_class}->new($str);

    if (defined $row && looks_like_number($row->get($self->{top})) && looks_like_number($row->get($self->{bottom}))) {
        my $substr = abs($row->get($self->{top}) - $row->get($self->{bottom}));

        $substr > $self->{reduced} ? $self->{reduced} = $substr : return $self->{reduced};
        
    }
    
    return $self->{reduced};
}

1;


