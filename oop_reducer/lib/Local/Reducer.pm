#!/usr/bin/env perl
package Local::Reducer;

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Reducer - base abstract reducer

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub new {
    my $class = shift;
    my (%data) = @_ ;
    my $self = \%data;
    
    $self->{reduced} = $self->{initial_value};

    return bless $self, $class;
}

sub reduce{}

sub reduced {
    my $self = shift;
    return $self->{reduced};
}
sub reduce_n{
    my $self = shift;
    my $n = shift;

    for (1..$n) { 
        if ($self->{source}->hasNext()) {
            $self->reduce();
        }else{
            last;
        }
    }

    return $self->reduced();
}

sub reduce_all {
    my $self = shift;
    #$self->{source}->restart_iter();
    
    while(){
        last unless $self->{source}->hasNext();
        $self->reduce();
    }

    return $self->reduced();
}



1;
