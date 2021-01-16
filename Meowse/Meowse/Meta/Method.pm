package Meowse::Meta::Method;
use Carp;

sub new {
    my ($class, $name, $generator) = @_;
    my $code; 
    if (ref $generator eq 'CODE') {
        $code = $generator # Already generated
    } else {
        my $generated = $generator->($name);
        my $e = do{
            local $@;
            $code = eval $generated;
            $@;
        };
        die $e if $e;
    }
    return bless {code => $code}, $class;
}

sub _generate_accessor {
    my ($name) = @_;
    my $accessor = "sub {
        my \$self = shift;
        my \$value = shift;
        if (\$value) {
            \$self->{$name} = \$value;
        }
        return \$self->{$name}
    }";
    return $accessor;
}
sub _generate_reader {
    my ($name) = @_;
    my $reader = "sub {
        my \$self = shift;
        carp 'This attribute is read-only' if (shift);
        return \$self->{$name};
    }";
    return $reader;
}
sub _generate_lazy_accessor {
    my ($name) = @_;
    my $accessor .= "sub {
        my \$self = shift;
        if (\$self->{$name}) {
            return \$self->{$name};
        } else {
            my \$builder = \$self->can('_build_'.$name) or croak 'Cannot find builder _build_$name';
            \$self->{$name} = \$builder->(\$self);
            return \$self->{$name};
        }
    }";
    return $accessor;
}
sub _generate_clear {
    my ($name) = @_;
    my $clearer .= "sub {
        my \$self = shift;
        if (\$self->{$name}) {
            delete \$self->{$name};
        }
    }";
    return $clearer;
}
sub _generate_has {
    my ($name) = @_;
    my $has .= "sub {
        my \$self = shift;
        if (\$self->{$name}) {
            return 1;
        }
        return 0;
    }";
    return $has;
}

sub code {
    my $self = shift;
    return $self->{code};
}

1;
