package Notes::DB;

use strict;
use warnings;
 
use lib '.';
use Notes::Model::Schema;

my $connect_info; 
BEGIN {
    $connect_info = {
        schema_class => 'Notes::Model::Schema',
        dsn => 'dbi:name_driver:name_database',
        user => 'db_username',
        password => 'db_password',
        param => {}
    }
}

sub init {
    my $self = shift;
    die "dsn was not passed" unless $self && $self->{dsn};
    my $schema = $self->{schema_class}->connect(@$self{qw(dsn user password param)});
    return $schema;
}

sub configure {
    my $class = shift;
    my $config = shift;

    $connect_info->{dsn} = $config->{dsn};
    $connect_info->{user} = $config->{user};
    $connect_info->{password} = $config->{password};
    $connect_info->{param} = $config->{param};
    return bless $connect_info, $class;
}


1;
