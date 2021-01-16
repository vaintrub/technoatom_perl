package Notes::Model::Schema::Result::Note;

use strict;
use warnings;

use base qw(DBIx::Class::Core);

__PACKAGE__->table('notes');


__PACKAGE__->add_columns(
    id => {
        data_type => 'blob',
        is_nullable => 0,
    },
    id_user => {
        data_type => 'integer',
        is_nullable => 0,
    },
    note_text => {
        data_type => 'text',
        is_nullable => 0
    }
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraint([qw(id)]);

__PACKAGE__->belongs_to(users => 'Notes::Model::Schema::Result::User', {'foreign.id' => 'self.id_user'});

1;
