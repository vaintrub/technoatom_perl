package Notes::Controller::User;

use Mojo::Base qw(Mojolicious::Controller);
use Email::Valid;

use Mojo::Log;
my $log = Mojo::Log->new;

sub showNotes {
    my $self = shift;
    $self->render(login => $self->session('login'), warning => $self->flash('warning'), note_text => undef);
}

sub signupForm {
    my $self = shift;
    $self->render(error => $self->flash('error'), message => $self->flash('message'));
}

sub signup {
    my $self = shift;

    my $login = $self->param('login');
    my $email = $self->param('email');
    my $password = $self->param('password');
    my $confirm_password = $self->param('conf_password');

    ##############  Validation is occured in client ################
    
    #if (! $password || ! $confirm_password || ! $login) {
    #    $self->flash( error => 'Username, Password, are the mandatory fields.');
    #    $self->redirect_to('create_signup_form');
    #}
    #unless (validate_login($login)) {
    #    $self->flash(error => 'Login is not Valid.');
    #    $self->redirect_to('create_signup_form');
    #}
    #if ($password ne $confirm_password) {
    #    $self->flash( error => 'Password and Confirm Password must be same.');
    #    $self->redirect_to('create_signup_form');
    #}
    #if($email && !(Email::Valid->address($email))) {
    #    $self->flash( error => 'Email is not Valid.');
    #    $self->redirect_to('create_signup_form');
    #}

    my $pbkdf2 = $self->app->{_pbkdf2};
    my $dbh = $self->app->{_dbh};

    my $user = $dbh->resultset('User')->find({login => $login});

    if(!$user) {
        eval {
            $dbh->resultset('User')->create({
                login => $login,
                email => $email,
                password => $pbkdf2->generate($password),
            });
        };
        if ($@) {
            $self->flash( error => 'Error in db query. Please check sqlite logs.');
            $self->redirect_to('create_signup_form');
        }
        else {
            $self->session(
                id_user => $dbh->storage->dbh->last_insert_id(),
                login => $login
            )->redirect_to('show_notes');

            #$self->flash( message => 'User added to the database successfully.');
            #$self->redirect_to('create_signup_form');
        }
    } else {
        $self->flash( error => 'Username already exists.');
        $self->redirect_to('create_signup_form');
    }
}

#sub validate_login {
#    my ($login) = @_;
#    
#    if ($login =~ /^[a-zA-Z]+$/ ) {
#        return 1;
#    }
#    else {  
#        return 0;
#    }
#}



1;
