package Notes::Controller::Note;

use Mojo::Base qw(Mojolicious::Controller);
use Digest::CRC qw(crc64);

use Mojo::Log;
use Mojo::File;
my $log = Mojo::Log->new;
use Data::Dumper;
use Mojo::JSON qw(encode_json decode_json);
use HTML::Entities;

use utf8;

sub getPreviousNotes {  # get existing notes
    my $self = shift;
    my $dbh = $self->app->{_dbh};

    my $user = $dbh->resultset('User')->find($self->session('id_user'));
    my @notes;
    for my $note ($user->notes) {
        my $image_dir = $self->get_image_dir($note->id); 
        my $id = unpack ('H*', pack ('Q', $note->id));
        my $note_text = encode_entities($note->note_text, '<>&"');
        $note_text =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;/g;
        $note_text =~ s/^ /&nbsp;/g;
        my $obj = {
            id => $id,
            note_text => $note_text,
            raw_text => $note->note_text,
            image => -f $image_dir,
        };
        push @notes, $obj;
    }
    $self->render(json => \@notes);
}


sub getNoteImage {
    my $self = shift;
    my $note_id = unpack 'Q', pack 'H*' , $self->stash('id');
    my $image_dir = $self->get_image_dir($note_id);
    if (-f $image_dir) {
        $self->reply->file($image_dir);
    } else {
        $self->rendered(404);
    }
}
sub getNote { # return note by link
    my $self = shift;
    my $note_id = unpack 'Q', pack 'H*', $self->stash('id');
    my $dbh = $self->app->{_dbh};

    my $note = $dbh->resultset('Note')->find($note_id);
    if (!$note) {
       $self->render(
           template => 'User/showNotes', 
           login => $self->session('login'), 
           warning => "This note does not exist!", 
           note_text => undef
       );     
    } else {
        if ($self->session('id_user') == $note->id_user) {
            ###### This note belongs to the user who requested it ######
            $self->render(
                template => 'User/showNotes', 
                login => $self->session('login'), 
                warning => undef, 
                note_text => $note->note_text);
        } else {
            ###### Not belong ######
            $self->render(
                template => 'User/showNotes', 
                login => $self->session('login'), 
                warning => "This note is not yours, so if you want to change it you must add it by clicking the save button!", 
                note_text => $note->note_text
            );

        }
    }
}

sub create {
    my $self = shift;
    my $note_text = $self->param('note_text');
    my $note_image = $self->param('image');
    #TODO validate

    my $dbh = $self->app->{_dbh};

    ###### creating unique id ######
    my $create_time = time();
    my $id = '';
    my $try_count = 10;
    while (!$id or -f $self->get_image_dir($id)) {
        unless (--$try_count) {
            $id = undef;
            last;
        }
        $id = crc64($note_text.$create_time.$id);   
        $id = '' if ($dbh->resultset('Note')->find($id));
    }
    
    ###### add row in DB ######
    unless ($id) {
        die "Try latter"; #TODO
    } else {
        $dbh->resultset('Note')->create({
            id => $id,
            id_user => $self->session('id_user'),
            note_text => $note_text
        });
        $note_image->move_to($self->get_image_dir($id)) if $note_image;
    }
    my $note_id = unpack ('H*', pack ('Q', $id)); 
    $note_text = encode_entities($note_text, '<>&"');
    $note_text =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;/g;
    $note_text =~ s/^ /&nbsp;/g;

    $self->render(json => {
        id => $note_id, 
        note_text => $note_text, 
        raw_text => $self->param('note_text'),
        image => -f $self->get_image_dir($id)
    });
}

sub update {
    my $self = shift;
    my $note_text = $self->param('note_text');
    my $note_image = $self->param('image');
    my $note_id = unpack 'Q', pack 'H*', $self->stash('id');
    my $dbh = $self->app->{_dbh};
    my $image_dir =  $self->get_image_dir($note_id);

    my $note = $dbh->resultset('Note')->find($note_id);
    if ($note->id_user == $self->session('id_user')) {
        $note->update({note_text => $note_text});
        if ($note_image) { # update image
            Mojo::File->new($image_dir)->remove if -f $image_dir;
            $note_image->move_to($image_dir);
        }
    } else {
        die "Note does not belong to this user"; #TODO
    }

    $note_text = encode_entities($note_text, '<>&"');
    $note_text =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;/g;
    $note_text =~ s/^ /&nbsp;/g;

    $self->render(json => {
        id => $self->stash('id'), 
        note_text => $note_text, 
        raw_text => $self->param('note_text'),
        image => -f $image_dir 
    });
}

sub delete {
    my $self = shift;
    my $note_id = unpack 'Q', pack 'H*' ,$self->stash('id');
    my $image_dir = $self->get_image_dir($note_id);
    my $dbh = $self->app->{_dbh};
    if (-f $image_dir) {
        Mojo::File->new($image_dir)->remove();
    }
    $dbh->resultset('User')->find($self->session('id_user'))->notes->find($note_id)->delete(); #TODO handle error

    $self->render(json => 1);
}

sub get_image_dir {
    my $self = shift;
    my $image_id = shift;
    my $dir = $self->app->home->rel_file('storage')->rel_file('images') . '/' . $image_id . '.jpeg';
    return $dir;
}

1;
