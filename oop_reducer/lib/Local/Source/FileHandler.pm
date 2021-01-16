#!/usr/bin/env perl
package Local::Source::FileHandler;
use parent qw(Local::Source);

use strict;
use warnings;
use 5.016;

sub new {
    my $class = shift;
    my (%data) = @_;
    $data{size} = (-s $data{fh}) - tell($data{fh});
    my $self = bless \%data, $class;
    #$self->restart_iter();

    return $self;
}

sub next {
    my $self = shift;
    my $fh = $self->{fh};
    my $line = <$fh>;
    if ($line) {
        chomp($line);
    }
    return $line;
}

sub hasNext {
    my $self = shift;
    if (tell($self->{fh}) < $self->{size}) {
        return 1;
    }
    return 0;
}
sub restart_iter {
    my $self = shift;
    seek $self->{fh}, 0, 0;
}

1;
