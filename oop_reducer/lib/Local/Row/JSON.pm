#!/usr/bin/env perl
package Local::Row::JSON;
use parent qw(Local::Row);

use strict;
use warnings;
use 5.016;
use JSON::XS;

sub new {
    my $class = shift;
    my $str = shift;
    my $self = {} ;
    eval {
        $self = JSON::XS->new->utf8->decode ($str);
    };
    if (my $e = $@ || ref $self ne 'HASH'){
        $self = undef;
    }
            
    bless $self, $class if defined $self;
    return $self;

}

1;
