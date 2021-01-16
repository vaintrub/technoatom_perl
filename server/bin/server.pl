#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';

use Data::Dumper;
use IO::Socket;
use IO::Select;
use utf8;
use Encode qw(decode encode);
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

#CONSTANTS
my $LENMSG= 10; #Lengtn message in sysread
my $N = 100; # Number of messages in Queue

my $server = IO::Socket::INET->new(Proto => 'tcp', LocalPort => 9798, Listen => 10, Reuse => 1 );
my $handles = IO::Select->new($server);

my @msgQueue = (); #Queue of messages
my %read_buff = (); #message buffer to keep track of completed messages
my %read_cb = (); #Callbacks for reading
my %write_cb = (); #Callbacks for writing

my %consumers = ();
my %producers = ();

sub close_connection {
    my ($hdl) = @_;
    return sub {
        $handles->remove($hdl);
        $hdl->close();
    }
}
sub push_read {
    my ($hdl, $cb) = @_;
    $handles->add($hdl);
    push @{$read_cb{$hdl}}, $cb;
    
}

sub push_write {
    my ($hdl, $msg, $cb) = @_;
    push @{$write_cb{$hdl}}, [$msg, $cb];
    
}
sub producer {
    my ($hdl, $message) = @_;
    my ($type, $msg) = ($message =~ /^\s*msg\s*{\s*type\s*=>\s*(.+)\s*,\s*msg\s*=>\s*(.+)\s*}\s*$/);
    if ($type && $msg) {
            for (keys %consumers) {
                if ($consumers{$_}->{type} eq $type) {
                    push_write($_, "msg(feader => $producers{$hdl}->{name}, type => $type, msg => $msg)\n");
                }
            }
            if (@msgQueue < 100) {
                push @msgQueue, {'feeder' => $producers{$hdl}->{name}, 'type' => $type, 'msg' => $msg};
            } else {
                shift @msgQueue;
                push @msgQueue, {'feeder' => $producers{$hdl}->{name}, 'type' => $type, 'msg' => $msg};
            }
            #print Dumper(\@msgQueue)."\n";
    } else {
        push_write($hdl, "", close_connection($hdl));
    }
    push_read($hdl, \&producer);
}
sub define{
    my ($hdl, $connect_msg) = @_;
    my ($stream, $arg, $param) = ($connect_msg =~ /^\s*connect\s*{\s*stream\s*=>\s*(in|out)\s*,\s*(name|type)\s*=>\s*(.+)\s*}\s*$/);
    if ($stream && $arg && $param) {
            if ($stream eq "in" && $arg eq "name") {
                #producer
                my $existName = 0;
                for my $key (keys %producers){
                    $existName = 1 if ($producers{$key}->{name} eq $param);
                }
                unless ($existName) {
                    warn $hdl->peerhost.":".$hdl->peerport." connected as feeder";
                    $producers{$hdl} = {'name' => $param}; 
                    push_read($hdl, \&producer);
                } else {
                    push_write($hdl, "", close_connection($hdl));
                }
                            
            } elsif ($stream eq "out" && $arg eq "type") {
                #consumer
                warn $hdl->peerhost.":".$hdl->peerport." connected as reader";
                $consumers{$hdl} = {'type' => $param};
                for (@msgQueue) {
                    if ($_->{type} eq $param) {
                        push_write($hdl,"msg(feader => $_->{feeder}, type => $_->{type}, msg => $_->{msg})\n");
                    }
                }
             }
    } else {
        push_write($hdl, "", close_connection($hdl));
    }

}

while (1) {
    for my $socket ($handles->can_read(1)) {
        if ($socket == $server) {
            my $client = $server->accept();
            my $flags = fcntl($client, F_GETFL, 0) or die "Can't get flags from the socket: $!";
            $flags = fcntl($client, F_SETFL, $flags | O_NONBLOCK) or die "Can't set flags to the socket: $!";
            push_read($client, \&define);
        } else {
            my $cnt = sysread($socket, my $buff, $LENMSG);
            if ($cnt) {
                $read_buff{$socket} .= $buff;
                if ($read_buff{$socket} =~ s/(.*\n)//) {
                    my $read_cb = delete $read_cb{$socket};
                    for my $cb (@$read_cb) {
                        $cb->($socket, $1);
                    }
                }
            } elsif ($!{EAGAIN}) {
                #socket not ready for reading
                next;
            } else {
                #socket was closed
                warn $socket->peerhost.":".$socket->peerport." closed connection";
                delete $producers{$socket};
                delete $consumers{$socket};
                $handles->remove($socket);
                $socket->close();
                delete $read_buff{$socket};
            }
        }
    }

    for my $socket ($handles->can_write(1)) {
        if (defined $write_cb{$socket}) {
            my $write_cb = delete $write_cb{$socket};

            while (@$write_cb) {
                my $written = shift @$write_cb;
                my $msg = $written->[0];
                my $cb = $written->[1];
                if ($msg) {
                    syswrite($socket, $msg);
                }
                $cb->() if $cb;
            }
        }
    }
}




