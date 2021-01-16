package Notes::Controller::Auth;

use Mojo::Base qw(Mojolicious::Controller);

use Mojo::Log;
my $log = Mojo::Log->new;

sub loginForm {
    my $self = shift;
    $self->render(error => $self->flash('error'), message => $self->flash('message'));
}
sub login {
    my $self = shift;
    
    my $login = $self->param('login');
    my $password = $self->param('password');
   
    ############ Validation is occured in  Client ############
    
    #if (!$login || !$password) {
    #    $self->flash("Login and password is required!");
    #    $self->redirect_to('/');
    #}
    my $pbkdf2 = $self->app->{_pbkdf2};
    my $dbh = $self->app->{_dbh};
    my $user = $dbh->resultset('User')->find({'login' => $login});

    if($user) {
        if ($pbkdf2->validate($user->password, $password)) {
            $self->session(
                id_user => $user->id,
                login => $user->login
            )->redirect_to('show_notes');
        } else {
            $self->flash(error => "Wrong password.");
            $self->redirect_to('create_login_form');
        }
    } else {
        $self->flash(error => "User with this login does not exist.");
        $self->redirect_to('create_login_form');
    }
}

sub logout {
    my $self = shift;
    $self->session(id_user => '', login => '')->redirect_to('create_login_form');
}
sub check {
    my $self = shift;
    if ($self->session('id_user')) {
        return 1;
    } else {
        $self->flash(error => "You need to log in");
        $self->redirect_to('create_login_form');
    }
}




1;
