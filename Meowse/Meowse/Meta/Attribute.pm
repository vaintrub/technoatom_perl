package Meowse::Meta::Attribute;
use Carp;

use feature 'say';
use Data::Dumper;

my %valid_params = (
        is => 1, 
        lazy_build => 1, 
        required => 1,
        name => 1,
    );

sub new {
    my ($class, $meta, %attr) = @_;
    #TODO validation
    for my $p (keys %attr) {
        unless ($valid_params{$p}) {
            croak "$p is unknown parameter!";
        }
    }
    my $self = bless \%attr, $class;
    $self->_install_accessor($meta);
    $self->_install_lazy($meta) if ($self->{lazy_build});
    return $self;
}

sub _install_accessor {
    my ($self, $meta) = @_; 
    my $generator = '_generate_';
    if ($self->{is} eq 'rw') {
        $generator .= 'accessor';
    } elsif ($self->{is} eq 'ro') {
        $generator .= 'reader';
    } else {
        confess "$self->{is} incorrect parameter. Possible: is => (rw|ro)";
    }

    $generator = '_generate_lazy_accessor' if ($self->{lazy_build});
    $meta->add_method($self->{name}, $self->{name}, $generator);
}
sub _install_lazy {
    my ($self, $meta) = @_;
    $meta->add_method('clear_'.$self->{name}, $self->{name}, '_generate_clear');
    $meta->add_method('has_'.$self->{name}, $self->{name}, '_generate_has');
}
sub is_required {
    my $self = shift;
    return $self->{required} ? 1 : 0;
}

1;
