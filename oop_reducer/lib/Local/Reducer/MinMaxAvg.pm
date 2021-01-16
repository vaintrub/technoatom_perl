#!/usr/bin/env perl
package Local::Reducer::MinMaxAvg;
use parent qw(Local::Reducer);

use strict;
use warnings;
use 5.016;
use Scalar::Util qw(looks_like_number);
use List::Util qw(min max);
use Local::Reducer::MinMaxAvgResult;


sub reduce{
    my $self = shift;
    my $str = $self->{source}->next();
    my $row = $self->{row_class}->new($str);
    
    my $el = $row->get($self->{field}) if defined $row;
    if (defined $row && looks_like_number($el)){
       $self->{reduced}->{max} = $el unless defined $self->{reduced}->get_max(); 
       $self->{reduced}->{min} = $el unless defined $self->{reduced}->get_min();
       $self->{reduced}->{max} = max($el, $self->{reduced}->get_max()) if defined $self->{reduced}->get_max();
       $self->{reduced}->{min} = min($el, $self->{reduced}->get_min()) if defined $self->{reduced}->get_min();
       $self->{reduced}->add_sum($el);
       $self->{reduced}->inc_counter();
    }


    return $self->{reduced};
  

}

sub new {
    my $class = shift;
    my (%data) = @_;
    my $self =\%data;

    $self->{reduced} = Local::Reducer::MinMaxAvgResult->new(max => undef, min => undef, sum => 0, count => 0, avg => undef );
    return bless $self, $class;
    
}


1;
