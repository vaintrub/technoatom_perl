package Person;
use Meowse;
has name => (is => 'ro', required => 1);
has surname => (is => 'ro');
has is_adult => (is => 'ro', lazy_build => 1);
has age => (is => 'rw', required => 1);
no Meowse;

sub greet {
    my $self = shift;
    return ('Hello! ' .'My name is '. $self->name . ($self->surname ? " ".$self->surname : '') . ". I am ".$self->age." years old.\n");
}
sub _build_is_adult {
    my $self = shift;
    return ($self->age >= 18) ? 'More than 18' : 'Less than 18';
}

############################
package Student;
use Meowse;
use feature 'say';
use Data::Dumper;

extends 'Person';
has university => (is => 'rw', required => 1);
has city_univ => (is => 'rw', lazy_build => 1);
around 'greet' => sub {
    my $orig = shift;
    my $self = shift;
    my $greeting = $self->$orig();
    $greeting .= "My university is ".$self->university;
    say $greeting;
};
no Meowse;
sub _build_city_univ {
    my $self = shift;
    return $self->university eq 'mephi' ? 'Moscow' : ':(';
}
my $student = Student->new(university => 'mephi', name => 'George', age => 19, surname => 'Vayntrub');
$student->greet;
say;
say 'has_is_adult - '. $student->has_is_adult;
say 'is_adult - '. $student->is_adult;
say 'has_is_adult - '. $student->has_is_adult;
say 'clear_is_adult - '. $student->clear_is_adult;
say 'has_is_adult - '. $student->has_is_adult;


1;
