#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(say state);
use Getopt::Long;
use Data::Dumper;
use Digest::MD5 qw/md5 md5_hex/;
use List::Util qw(first shuffle);
use UUID::Tiny ':std';

use EV;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

use constant HELO_PEER => 'PEER';
use constant HELO_RESP => 'HELO';

use constant RESP_CODE_OK                       => 0;
use constant RESP_CODE_ERR_UNKNOWN_MSG          => 254;
use constant RESP_CODE_ERR_FATAL                => 255;

use constant MSG_GET_PEERS        => 1;
use constant MSG_GET_FILES        => 2;
use constant MSG_CHECK_FILE       => 3;

my $CONFIG = {
    arbiter => '127.0.0.1:9999',
    listen  => '127.0.0.1:10000',
    chunks  => 2,
    debug => 0 
};

GetOptions($CONFIG, qw/
    arbiter=s
    listen=s
    chunks=i
    debug
/);
my %MSG_RES_HANDLERS = (
    MSG_GET_PEERS() => \&res_get_peers,
    MSG_GET_FILES() => \&res_get_files
); 

my ($ARBT_H, $ARBT_P) = parse_hostport($CONFIG->{arbiter});
my ($LSTN_H, $LSTN_P) = parse_hostport($CONFIG->{listen});
my $SELF_UUID = create_uuid();
my $CHUNKS_PER_PEER = $CONFIG->{chunks};
my $ALL_FILES_COLLECTED = 0;

my %connects = ();# Node's handles which i keep
my %recv_peers;   # I save peers which was received from someone in order to not send it back
my %MY_FILES = ();# Self collected files
my %PEERS_POOL;   # Peers I know about Example (uuid => {chunks => ..., peers => ...}) Chunks and peers are sent by me
my %UUID_BY_IP;   # (listenIP:listenPORT => uuid)
my @CHUNKS_POOL;
my @FILES_FOR_CHECK;
# req_get_peers and req_get_files execute with connection. 
# request_chain (host, port, [ref_code, ...]);
request_chain($ARBT_H, $ARBT_P, [\&req_get_peers, \&req_get_files]); # Start

tcp_server $LSTN_H, $LSTN_P, sub {
    my ($fh, $host, $port) = @_;
    my $hdl = AnyEvent::Handle->new(fh => $fh, no_delay => 1);    
    $connects{$hdl} = [$hdl, $host, $port];
    _log_in($hdl, "Accept connect");
    my $token = int(rand(0xFFFFFFFF));
    $hdl->timeout(10);
    $hdl->on_error(sub {
        my ($hdl, $fatal, $message) = @_;
            _log_sys($hdl, ($fatal ? "FATAL" : "ERROR")." $message");
            delete $connects{$hdl};
    });
    $hdl->push_write(pack 'a4L', HELO_PEER, $token);
    #_log_out($hdl, "HELO: ".HELO_PEER."$token");
    $hdl->push_read(chunk => 4+4, sub {
        my ($hdl, $data) = @_;
        my ($helo, $client_token) = eval {unpack 'a4L', $data};
        if ($helo eq HELO_RESP && $client_token == $token) {
            #_log_in($hdl, "HELO: $helo$client_token");
            process_res($hdl);
        } else {
            _log_in($hdl, "HELO ERROR: $helo$client_token");
            delete $connects{$hdl};
            undef $hdl;
        }
    });
};

# Sequential execution of asynchronous functions
# Because arbiter, for example, can sleep after some msg 
sub request_chain {
    my ($host, $port, $chain_func) = @_;
    my $uuid = $UUID_BY_IP{format_hostport($host, $port)} || undef;
    my $req_chain; $req_chain = sub {
        return unless my $cb = shift @$chain_func;
        tcp_connect $host, $port, sub {
            #TODO handle error better
            my ($fh) = @_ or die "Can't connect to the node: $!";
            my $hdl = AnyEvent::Handle->new(fh => $fh, no_delay => 1);
            $hdl->on_eof(sub {   #TODO Do not work!
                my ($hdl) = @_;
                _log_sys(undef, "Close after response");
                delete $connects{$hdl};
                undef $hdl;
            });
            $connects{$hdl} = [$hdl, $host, $port];
            $hdl->push_read(chunk => 4+4, sub {
                my ($hdl, $data) = @_;
                my ($helo, $token) = eval{ unpack 'a4L', $data };
                _log_in($hdl, "HELO: $helo$token");
                $hdl->push_write(pack 'a4L', HELO_RESP, $token);
                #_log_out($hdl, "HELO: ".HELO_RESP."$token");
                $cb->($hdl, $uuid, $req_chain) if $cb;
            });
        };
    }; $req_chain->();
}

EV::loop();

sub process_res {
    my ($hdl) = @_;
    $hdl->push_read(chunk => 1+4, sub {
        my ($hdl, $data) = @_;
        my ($msg_id, $msg_len) = unpack 'CL', $data;
        my $msg_handler = $MSG_RES_HANDLERS{$msg_id};
        if ($msg_handler) {
            _log_in($hdl, "Got msg($msg_id)");
            $msg_handler->($hdl);
        } else {
            _log_in($hdl, "Unknown msg ($msg_id)");
            response($hdl, RESP_CODE_ERR_UNKNOWN_MSG);
        }
    });
}
sub response {
    my ($hdl, $res_code, $payload) = @_;
    $hdl->push_write(pack 'CL/a*', $res_code, $payload || '');
    _log_out($hdl, "Response sent: $res_code");
    delete $connects{$hdl};
    $hdl->destroy;
}
sub request {
    my ($hdl, $msg_id, $payload) = @_;
    $hdl->push_write(pack 'CL/a*', $msg_id, $payload || '');
    _log_out($hdl, "Sent msg($msg_id)");
}
sub save_chunk {
    my ($hdl, $file_id, $file_chunks_cnt, $chunk_num, $chunk_len, $data) = @_;
    # New file
    unless ($MY_FILES{$file_id}) {
        $MY_FILES{$file_id}{is_checked} = 0;
        $MY_FILES{$file_id}{num_collected} = 0;
        $MY_FILES{$file_id}{chunks_cnt} = $file_chunks_cnt;
    }
    unless ($MY_FILES{$file_id}{chunks}{$chunk_num}) {
        $MY_FILES{$file_id}{chunks}{$chunk_num} = {data => $data, chunk_len => $chunk_len};
        push @CHUNKS_POOL, {
                id => $file_id, 
                chunks_cnt => $file_chunks_cnt, 
                chunk_num => $chunk_num, 
                chunk_len => $chunk_len, 
                data => $data
            };
        $MY_FILES{$file_id}{num_collected}++;
        if ($MY_FILES{$file_id}{is_checked} != 1 && $MY_FILES{$file_id}{num_collected} == $MY_FILES{$file_id}{chunks_cnt}) { # Check that file is full
            push @FILES_FOR_CHECK, {
                    id => $file_id, 
                    chunks => $MY_FILES{$file_id}{chunks}, 
                    chunks_cnt => $MY_FILES{$file_id}{chunks_cnt}
                };
            request_chain($ARBT_H, $ARBT_P, [\&req_check_file]);        
        }
    }
}
#### FOR MAKING REQUESTS  ####
sub req_get_peers {
    my ($hdl, $uuid, $cb) = @_;
    my $payload = pack 'a16a4S', $SELF_UUID, AnyEvent::Socket::aton($LSTN_H), $LSTN_P ;        
    request($hdl, MSG_GET_PEERS, $payload); # Make request
    $hdl->push_read(chunk => 1+4+2, sub { # Handle response
        my ($hdl, $data) = @_;
        my ($code, $msg_len, $cnt_peers) = unpack 'CLS', $data;
        #TODO code check
        _log_in($hdl, "Response recv: code-$code, msg_len-$msg_len, cnt_peers-$cnt_peers");
        for (1..$cnt_peers) {
            $hdl->push_read(chunk => 16+4+2, sub {
                my ($hdl, $data) = @_;
                my ($peer_uuid, $peer_ip, $peer_port) = unpack 'a16a4S', $data; 
                $peer_uuid = uuid_to_string($peer_uuid);
                $peer_ip = AnyEvent::Socket::ntoa($peer_ip);
                _log_in(undef, "uuid-$peer_uuid, ip-$peer_ip, port-$peer_port");
                $PEERS_POOL{$uuid}{peers}{$peer_uuid} = 1 if $uuid; # This peer was received from $host$port TODO make better
                unless ($PEERS_POOL{$peer_uuid}) {
                    $UUID_BY_IP{format_hostport($peer_ip, $peer_port)} = $peer_uuid; 
                    request_chain($peer_ip, $peer_port, [\&req_get_peers, \&req_get_files]);
                }
            });    
        }
        $cb->() if $cb;
    });
}
sub req_get_files {
    my ($hdl, $uuid,  $cb) = @_;
    my $payload = pack 'a16', $SELF_UUID;
    request($hdl, MSG_GET_FILES, $payload);
    $hdl->push_read(chunk => 1+4+2, sub {
        my ($hdl, $data) = @_;
        my ($code, $msg_len, $cnt_files) = unpack 'CLS', $data;
        #TODO check code
        _log_in($hdl, "Response recv: code-$code, msg_len-$msg_len, cnt_files-$cnt_files");
        my $next; $next = sub {
            my ($hdl) = @_;
            return unless $cnt_files--;
            $hdl->push_read(chunk => 32+1+1+2, sub {
                my ($hdl, $data) = @_;
                my ($file_id, $file_chunks_cnt, $chunk_num, $chunk_len) = unpack 'a32CCS', $data;
                #_log_in(undef, "file_id-$file_id, cnt-$file_chunks_cnt, num-$chunk_num, len-$chunk_len");
                $PEERS_POOL{$uuid}{chunks}{$file_id}{$chunk_num} = 1 if $uuid;# Save from whom the chunk was received                 
                $hdl->push_read(chunk => $chunk_len, sub {
                    my ($hdl, $data) = @_;
                    $data = unpack 'a*', $data;
                    save_chunk($hdl, $file_id, $file_chunks_cnt, $chunk_num, $chunk_len, $data);
                    $next->($hdl);
                });
            });
        }; $next->($hdl);
        re_req_files($hdl, $uuid); # Again requests for files
        $cb->() if $cb;
    });
}
sub re_req_files {
    my ($hdl, $uuid) = @_;
    return unless $uuid;
    #TODO make better chech collected files!!
    if ($ALL_FILES_COLLECTED) {
        _log_sys(undef, "All files are collected");
        return;
    } else {
        _log_sys(undef, "Again req for files");
        my ($host, $port) = parse_hostport(first {$uuid eq $UUID_BY_IP{$_}} keys %UUID_BY_IP);
        request_chain($host, $port, [\&req_get_files]);    
    }
}
sub req_check_file {
    my ($hdl, $uuid, $cb) = @_;
    my $next; $next = sub {
        my $file;
        unless ($file = shift @FILES_FOR_CHECK) {
            $cb->() if $cb;
            return;
        }
        my $full_file;
        for (0..$file->{chunks_cnt}-1) {
            $full_file .= $file->{chunks}->{$_}->{data};    
        }
        my $payload = pack 'a16', $SELF_UUID;
        $payload .= pack 'a32a16', $file->{id}, md5($full_file);
        request($hdl, MSG_CHECK_FILE, $payload);
        $hdl->push_read(chunk => 1+4, sub {
            my ($hdl, $data) = @_;
            my ($code, $msg_len) = unpack 'CL', $data;
            if ($code == 0) {
                #TODO handle better
                $MY_FILES{$file->{id}}{is_checked} = 1;
                $ALL_FILES_COLLECTED = 1;
                for my $file_id (keys %MY_FILES) {
                    $ALL_FILES_COLLECTED = 0 unless ($MY_FILES{$file_id}{is_checked});
                }
                _log_sys(undef, "CHECK_OK");
            } else {
                _log_sys(undef, "CHECK_NOT_OK");
            }
            $next->();
        });
    }; $next->();
}
#### FOR MAKING RESPONSES ####
sub res_get_peers {
    my ($hdl) = @_;
    $hdl->push_read(chunk => 16+4+2, sub {
        my ($hdl, $data) = @_;
        my ($peer_uuid, $peer_ip, $peer_port) = unpack 'a16a4S', $data;
        $peer_uuid = uuid_to_string($peer_uuid);
        $peer_ip = AnyEvent::Socket::ntoa($peer_ip);
        my $payload;
        my $cnt_peers;
        my $host_port = format_hostport($peer_ip, $peer_port);
        for my $hp (keys %UUID_BY_IP) {
            if ($hp ne $host_port && !$PEERS_POOL{$UUID_BY_IP{$host_port}}{peers}{$hp}) {
                $cnt_peers++;
                my ($host, $port) = parse_hostport($hp);
                $payload .= pack 'a16a4S', string_to_uuid($UUID_BY_IP{$hp}), AnyEvent::Socket::aton($host), $port;    
            }
        }
        response($hdl, RESP_CODE_OK, pack 'Sa*', $cnt_peers || 0, $payload || '');
        unless ($PEERS_POOL{$peer_uuid}) {
            $UUID_BY_IP{$host_port} = $peer_uuid;
            request_chain($peer_ip, $peer_port, [\&req_get_peers, \&req_get_files]);
             #TODO There's problem that this request often comes earlier than response above
            # So ($peer_ip:$peer_port) sends peers in response without knowing which peers was received from this peer 
        }
    });
}
sub res_get_files {
    my ($hdl) = @_;
    $hdl->push_read(chunk => 16, sub {
        my ($hdl, $data) = @_;
        my ($peer_uuid) = unpack 'a16', $data;
        $peer_uuid = uuid_to_string($peer_uuid);
        my $payload; 
        my $count = 0;
        #@CHUNKS_POOL = shuffle @CHUNKS_POOL;
        for my $chunk (@CHUNKS_POOL) {
            #which files was already sent and received
            unless ($PEERS_POOL{$peer_uuid}{chunks}{$chunk->{id}}{$chunk->{chunk_num}}) {
                $payload .= pack("a32CCS/a*", $chunk->{id}, $chunk->{chunks_cnt}, $chunk->{chunk_num}, $chunk->{data});
                $PEERS_POOL{$peer_uuid}{chunks}{$chunk->{id}}{$chunk->{chunk_num}} = 1;
                last if ++$count == $CHUNKS_PER_PEER;
            }
        }
        response($hdl, RESP_CODE_OK, pack 'Sa*', $count, $payload || '');
    });
}
###########################
sub _log_in {_log('<', @_)}
sub _log_out {_log('>', @_)}
sub _log_sys {_log('=', @_)}
sub _log {
    my ($mode, $hdl, $msg) = @_;
    my $prefix = $mode x 3; 
    if ($hdl) {
        (undef, my $ip, my $port) = @{$connects{$hdl}};    
        $prefix .= " [$ip:$port]";
    }
    say $prefix. " " .$msg if $CONFIG->{debug};
}





















