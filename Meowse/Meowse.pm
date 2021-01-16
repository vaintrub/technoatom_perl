package Meowse;
use Meowse::Object;
use Meowse::Meta::Class;

use Carp;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(has extends around before after);

use feature 'say';
use Data::Dumper;

sub unimport {
    my ($package, @args) = @_;
    my $from = caller;
    @args = @EXPORT unless @args;
    for (@args) {
        do {
            no strict 'refs';
            delete ${$from.'::'}{$_} || carp "Can't find a method $_";
        }
    }
}


sub has {
    my $meta = Meowse::Meta::Class->initialize(scalar caller);
    my $name_attr = shift; # Name(s) of attributes 
    confess "Invalid number of param. Usage: has [name|names] => (is => 'rw|ro|bare', ...)"
        unless @_;
    for my $name (ref($name_attr) ? @{$name_attr} : $name_attr) {
       $meta->add_attribute($name => @_); 
    }
    return;
}

sub extends {
    Meowse::Meta::Class->initialize(scalar caller)->superclasses(@_);
}

sub around {
    confess "Incorrect arguments. Usage: around 'method_name' => sub {....};" if (@_ != 2 || ref $_[1] ne 'CODE');
    Meowse::Meta::Class->initialize(scalar caller)->set_decorator('around', shift, shift);
    return;
}

sub before {
    confess "Incorrect arguments. Usage: before 'method_name' => sub {....};" if (@_ != 2 || ref $_[1] ne 'CODE');
    Meowse::Meta::Class->initialize(scalar caller)->set_decorator('before', shift, shift);
    return;
}

sub after {
    confess "Incorrect arguments. Usage: after 'method_name' => sub {....};" if (@_ != 2 || ref $_[1] ne 'CODE');
    Meowse::Meta::Class->initialize(scalar caller)->set_decorator('after', shift, shift);
    return;
}

1;
