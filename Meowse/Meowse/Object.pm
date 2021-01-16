package Meowse::Object; # Base class for all Meowse's classes
use Meowse::Meta::Class;

sub new {
    my ($class, %data) = @_;
    my $meta = _get_meta_by_class($class);
    $meta->validate_attr(%data);
    my $self = bless \%data, $class;
    return $self;
}

1;
