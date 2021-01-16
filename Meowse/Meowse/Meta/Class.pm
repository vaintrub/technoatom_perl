package Meowse::Meta::Class;
use Meowse::Meta::Attribute;
use Meowse::Meta::Method;

use Exporter qw(import);
our @EXPORT = ('_get_meta_by_class');

use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use feature 'say';

my %METAS;


sub initialize {
    my ($class, $pkg) = @_; 
    return $METAS{$pkg} ||= $class->_create_meta(package => $pkg);
}
sub add_attribute {
    my $self = shift;
    my $name = shift;
    $name or croak "Name of attribute must be defined";
    $self->{attributes}->{$name} = Meowse::Meta::Attribute->new($self, 'name' => $name, @_);
}
sub superclasses {
    my $self = shift;
    my $super_class = shift;
    my $super_meta = _get_meta_by_class($super_class); 
    @{ $self->{superclasses} } = ($super_class)  if ($super_meta);
}

sub _get_meta_by_class {
    my $super = shift;
    my $meta = $METAS{$super};
    #carp "$super is not Meowse's class!" unless $meta;
    return $meta;
}
sub _create_meta {
    my ($class, %args) = @_;
    $args{attributes} = {};
    $args{methods} = {};
    $args{superclasses} = do {
        no strict 'refs';
        \@{$args{package}.'::ISA'};
    };
    push @{$args{superclasses}}, 'Meowse::Object';
    my $self = bless \%args, $class;
    return $self;
}

sub set_decorator {
    my ($self, $type, $name, $code) = @_;
    my $class = $self->{package};
    #TODO CHECK
    my $orig = $class->can($name) or carp "$name was not found!";
    if (!$self->{decorators}->{$name}) {
        my (@before, @after, @around);
        my $next = $orig;
        my $decorator = sub {
            if (@before) {
                $_->(@_) for(@before);
            }
            unless (@after) {
                return $next->(@_);
            }
            if (wantarray) { # list context
                my @val = $next->(@_);               
                $_->(@_) for(@after);
                return @val;
            } elsif (defined wantarray) { # Scalar
                my $val = $next->(@_);               
                $_->(@_) for(@after);
                return $val;
            } else { # void
                $next->(@_);
                $_->(@_) for(@after);
                return;
            }
        };
        $self->{decorators}->{$name} = {
                before => \@before,
                after => \@after,
                around => \@around,
                next => \$next,
        };
        $self->add_method($name, $name, $decorator);
    }
    if ($type eq 'before') {
        push @{ $self->{decorators}->{$name}->{before} }, $code;
    } elsif ($type eq 'after') {
        push @{ $self->{decorators}->{$name}->{after} }, $code;
    } else { # around
        push @{ $self->{decorators}->{$name}->{around} }, $code;
        my $next = ${ $self->{decorators}->{$name}->{next} };     
        ${ $self->{decorators}->{$name}->{next} } = sub { $code->($next, @_) };
    }
    return;
}

sub add_method {
    my ($self, $name_method, $name_attr, $method) = @_;
    # $method either generator or code ref
    $self->{methods}->{$name_method} = Meowse::Meta::Method->new($name_attr, $method);
    *{$self->{package}.'::'.$name_method} = $self->{methods}->{$name_method}->code;
}

sub validate_attr {
    my ($self, %data) = @_;
    my $super_meta = _get_meta_by_class(@{ $self->{superclasses} });
    my %attributes = (%{ $self->{attributes} }, %{ $super_meta->{attributes} }); # All attributes
    my @bad;
    for my $attr (keys %attributes) {
        if ($attributes{$attr}->is_required && !$data{$attr}) {
            push @bad, $attr;
        }
    }
    croak "Attributes [@bad] are required!" if (@bad);
}
1;
