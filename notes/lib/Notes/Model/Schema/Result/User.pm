package Notes::Model::Schema::Result::User;

use strict;
use warnings;
use base qw(DBIx::Class::Core);

__PACKAGE__->table('users');

__PACKAGE__->add_columns(
    id => {
        data_type => 'INTEGER',
        is_nullable => 0,
        is_auto_increment => 1
    },
    login => {
        data_type => 'text',
        is_nullable => 0,
    },
    password => {
        data_type => 'blob',
        is_nullable => 0
    },
    email => {
        data_type => 'text',
        is_nullable => 0
    }
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraint([qw(login id)]);

__PACKAGE__->has_many(notes => 'Notes::Model::Schema::Result::Note', {'foreign.id_user' => 'self.id'});

1;

