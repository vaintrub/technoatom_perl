package Notes;
use Mojo::Base 'Mojolicious';

use Mojo::Log;
my $log = Mojo::Log->new;
use Data::Dumper;

use lib '.';
use Notes::DB;
use Crypt::PBKDF2;

# This method will run once at server start
sub startup {
    my $self = shift;
    # Load configuration from config file
    my $config = $self->plugin('JSONConfig' => {file => 'conf.json'});

    #set schema in $self->{_dbh}
    $self->_set_db_handler($config->{db} || {
            dsn => "dbi:SQLite:dbname=" . $self->home->rel_file('storage') . "/database.db",
            user => '',
            password => '',
            param => {
                sqlite_unicode => 1,
                RaiseError => 1
            }
        }
    );

    #$self->{_dbh}->storage->debug(1);

    #set pbkdf2 in $self{_pbkdf2}
    $self->_set_crypt;

    # Configure the application
    $self->secrets($config->{secrets});

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('Auth#loginForm')->name('create_login_form');
    $r->post('/login')->to(controller => 'Auth', action => 'login')->name('login');
    $r->get('/logout')->to(controller => 'Auth', action => 'logout')->name('logout');
    #
    $r->get('/signup')->to('User#signupForm')->name('create_signup_form');
    $r->post('/signup')->to(controller => 'User', action => 'signup')->name('signup');

    my $rn = $r->under('/')->to('Auth#check');
    $rn->get('/main')->to('User#showNotes')->name('show_notes');
    $rn->get('/notes')->to('Note#getPreviousNotes')->name('get_previous_notes');
    $rn->post('/notes/create')->to('Note#create')->name('create_note');
    $rn->put('/notes/:id/update' => [id => qr/[a-f0-9]{16}/])->to('Note#update')->name('update_note');
    $rn->delete('/notes/:id/delete' => [id => qr/[a-f0-9]{16}/])->to('Note#delete')->name('delete_note');
    $rn->get('/notes/:id' => [id => qr/[a-f0-9]{16}/])->to('Note#getNote')->name('get_note');
    $rn->get('/notes/:id/image' => [id => qr/[a-f0-9]{16}/])->to('Note#getNoteImage')->name('get_note_image');
}

sub _set_db_handler {
    my $self = shift;
    my $config = shift; 
    my $DB = Notes::DB->configure($config);
    $self->{_dbh} = $DB->init();
    return $self;
}
sub _set_crypt {
    my $self = shift;
    $self->{_pbkdf2} =Crypt::PBKDF2->new(
        hash_class => 'HMACSHA1',
        iterations => 1000,
        output_len => 20,
        salt_len => 4,
    );
}

1;
