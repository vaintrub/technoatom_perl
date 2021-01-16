#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';

use EV;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

use Digest::MD5 qw/md5 md5_hex/;
use UUID::Tiny qw/:std/;
use List::Util qw/first shuffle/;
use POSIX;
use Getopt::Long;

use constant HELO_ARBT => 'ARBT';
use constant HELO_RESP => 'HELO';

use constant ARBT_MODE_INIT     => 'INIT';
use constant ARBT_MODE_RUN      => 'RUN';
use constant ARBT_MODE_FINISH   => 'FINISH';

use constant RESP_CODE_OK                       => 0;
use constant RESP_CODE_ERR_MD5                  => 1;
use constant RESP_CODE_ERR_UNKNOWN_FILENAME     => 2;
use constant RESP_CODE_ERR_LESS_PEERS           => 3;
use constant RESP_CODE_ERR_UNKNOWN_PEER         => 252;
use constant RESP_CODE_ERR_ILLEGAL_MODE         => 253;
use constant RESP_CODE_ERR_UNKNOWN_MSG          => 254;
use constant RESP_CODE_ERR_FATAL                => 255;

use constant MSG_GET_PEERS        => 1;
use constant MSG_GET_FILES        => 2;
use constant MSG_CHECK_FILE       => 3;

my %MSG_HANDLERS = (
    MSG_GET_PEERS()        => \&msg_get_peers,
    MSG_GET_FILES()        => \&msg_get_files,
    MSG_CHECK_FILE()       => \&msg_check_file,
);

my $DEBUG = 0;
my $ALLIN = 0;
my $INIT_TIMEOUT = 180;
my $RUN_TIMEOUT = 600;
my $PEERS_PER_RESP = 2;
my $FILES_PER_PEER = 2;
my $MIN_PEERS_POOL_SIZE = 3;
my $CHUNK_SIZE = 1024;
my $WAIT_GENERATION_TIMEOUT = 2;

GetOptions(
    'debug!'         => \$DEBUG,
    'allin!'         => \$ALLIN,
    'init_timeout=i' => \$INIT_TIMEOUT,
    'run_timeout=i'  => \$RUN_TIMEOUT,
    'ppr=i'          => \$PEERS_PER_RESP,
    'fpp=i'          => \$FILES_PER_PEER,
    'min_peers=i'      => \$MIN_PEERS_POOL_SIZE,
    'chunk_size'     => \$CHUNK_SIZE,
);

my @FILES_POOL;
my @CHUNKS_POOL;
my %PEERS_POOL;
my %PEERS_FILES;
my $INIT_MODE_TIMER;
my @INIT_CONNECTS;
my $RUN_MODE_TIMER;

my $IN_FILE_GENERATION = 0;
my $CURRENT_CHUNK_IDX = 0;
my $TOTAL_CHUNKS = 0;
my $CHUNKS_PER_PEER = 0;

my $CURRENT_MODE = '';
_switch_mode(ARBT_MODE_INIT);

my %connects = ();

=cut
Handshake
REQ:  ARBT$tokenL       a4L
RESP: HELO$tokenL       a4L
=cut

tcp_server undef, 9999, sub {
    my ($fh, $host, $port) = @_;

    my $hdl = AnyEvent::Handle->new(fh => $fh, no_delay => 1);
    $connects{$hdl} = [ $hdl, $host, $port ];
    _log_in($hdl, "Accept connect");

    my $token = int(rand(0xFFFFFFFF));
    _log_out($hdl, "HELO '".HELO_ARBT."$token'");

    $hdl->on_error(sub {
        my ($hdl, $fatal, $message) = @_;
        _log_sys($hdl, ($fatal ? "FATAL" : "ERROR")." $message");
        delete $connects{$hdl};
    });

    $hdl->push_write(pack("a4L", 'ARBT', $token));
    $hdl->push_read(chunk => 8, sub {
        my ($hdl, $data) = @_;
        my ($helo, $client_token) = eval { unpack("a4L", $data) }; 
        if($helo eq HELO_RESP && $client_token == $token) {
            _log_in($hdl, "HELO '$helo$token'");
            process($hdl);
        } else {
            _log_out($hdl, "HELO ERROR '$helo$client_token'");
            delete $connects{$hdl};
            undef $hdl;
        }
    });
}, sub { 100 };

EV::loop();

=cut
General request
REQ:  $mesg1$req_data   Ca*
RESP: $code1$resp_data  Ca*
=cut

sub process {
    my ($hdl) = @_;

    $hdl->push_read(chunk => 1+4, sub {
        my ($hdl, $data) = @_;
        my ($msg, $msg_len) = unpack("CL", $data);
        _log_in($hdl, "Get msg '$msg' (len: $msg_len)");

        my $msg_handler = $MSG_HANDLERS{$msg};
        if($msg_handler) {
            $msg_handler->($hdl);
        } else {
            _log_out($hdl, "Unknown msg '$msg'");
            response($hdl, RESP_CODE_ERR_UNKNOWN_MSG);
        }
    });
}

sub response {
    my ($hdl, $code, $payload) = @_;
    $hdl->push_write(pack("CL/a*", $code, $payload // ''));
    _log_out($hdl, "Response code: $code");
    _log_out($hdl, sprintf "Response payload length: %d", length($payload)) if $payload;
    _log_out($hdl, sprintf "Response payload: %vX", $payload) if $payload && $DEBUG;

    delete $connects{$hdl};
    undef $hdl;
}

=cut
MSG_GET_PEERS
REQ:  $uuid_bin16$ip_net4$port2                   a16a4S
RESP: $peers_cnt2[$uuid_bin16$ip_net4$port2]      S(a16a4S)*
=cut

sub msg_get_peers {
    my ($hdl) = @_;
    $hdl->push_read(chunk => 16+4+2, sub {
        my ($hdl, $data) = @_;
        return response($hdl, RESP_CODE_ERR_ILLEGAL_MODE) if $CURRENT_MODE ne ARBT_MODE_INIT;

        my ($uuid, $ip, $port) = unpack("a16a4S", $data);
        $ip = AnyEvent::Socket::ntoa($ip);
        $uuid = uuid_to_string($uuid);

        _log_in($hdl, "Receive peer: UUID=$uuid IP=$ip PORT=$port");

        $PEERS_POOL{$uuid} = { uuid => $uuid, ip => $ip, port => $port, last_update => AnyEvent::now };
        push @INIT_CONNECTS, [ $hdl, $uuid ];
        _generate_file() for 1..$FILES_PER_PEER;

        my $timer_cb; $timer_cb = sub {
            if($IN_FILE_GENERATION) {
                _log_sys(undef, "Stay in files generation. Wait $WAIT_GENERATION_TIMEOUT secs more.");
                $INIT_MODE_TIMER = AnyEvent->timer(after => $WAIT_GENERATION_TIMEOUT, cb => $timer_cb);
                return;
            }
            undef $INIT_MODE_TIMER;

            _log_sys(undef, "Init period has ended.");
            if(keys %PEERS_POOL >= $MIN_PEERS_POOL_SIZE) {
                _switch_mode(ARBT_MODE_RUN);
                $TOTAL_CHUNKS = @CHUNKS_POOL;
                $CHUNKS_PER_PEER = $ALLIN ? $TOTAL_CHUNKS : POSIX::ceil($TOTAL_CHUNKS / (keys %PEERS_POOL));
                @CHUNKS_POOL = shuffle @CHUNKS_POOL;

                _log_sys(undef, "Total peers: ".(scalar keys %PEERS_POOL).". Total chunks: $TOTAL_CHUNKS. Chunks per peer: $CHUNKS_PER_PEER");
                
                my $pos   = 0;
                my @uuids = keys %PEERS_POOL;
                while(my $conn_data = shift @INIT_CONNECTS) {
                    my ($hdl, $uuid) = @$conn_data;
                    my @selected_peers = ();
                    while(@selected_peers < $PEERS_PER_RESP) {
                        if($uuids[$pos] ne $uuid) {
                            push @selected_peers, $uuids[$pos];
                        }
                        $pos++;
                        $pos = 0 unless $pos < @uuids;
                    }

                    my $payload = pack('S', $PEERS_PER_RESP); 
                    for(@selected_peers) {
                        my $peer = $PEERS_POOL{$_};
                        $payload .= pack("a16a4S", string_to_uuid($_), AnyEvent::Socket::aton($peer->{ip}), $peer->{port})
                    }
                    response($hdl, RESP_CODE_OK, $payload);
                }
                $RUN_MODE_TIMER = AnyEvent->timer(after => $RUN_TIMEOUT, cb => \&finish_cb);
            } else {
                _switch_mode(ARBT_MODE_INIT);
                while(my $conn_data = shift @INIT_CONNECTS) {
                    response($conn_data->[0], RESP_CODE_ERR_LESS_PEERS);
                }
            }
        };
        _log_sys($hdl, "Run init timer. Timeout $INIT_TIMEOUT secs") unless $INIT_MODE_TIMER;
        $INIT_MODE_TIMER ||= AnyEvent->timer(after => $INIT_TIMEOUT, cb => $timer_cb);
    });
}

=cut
MSG_GET_FILES
REQ:  $uuid_bin16                                                                       a16
RESP: $chunks_cnt2[$fileid32$file_chunks_cnt1$chunk_num1$chunk_len2$chunk_bindata]      S(a32CCS/a*)*
=cut

sub msg_get_files {
    my ($hdl) = @_;

    $hdl->push_read(chunk => 16, sub {
        my ($hdl, $data) = @_;
        return response($hdl, RESP_CODE_ERR_ILLEGAL_MODE) if $CURRENT_MODE ne ARBT_MODE_RUN;

        my $uuid = unpack("a16", $data);
        $uuid = uuid_to_string($uuid);
        return response($hdl, RESP_CODE_ERR_UNKNOWN_PEER) unless $PEERS_POOL{$uuid};

        _log_in($hdl, "Request for files: UUID=$uuid");

        my $payload = pack("S", $CHUNKS_PER_PEER);
        if(my $peer_files = $PEERS_FILES{$uuid}) {
            for my $filename (keys %$peer_files) {
                my $file = first { $filename eq $_->{filename} } @FILES_POOL;
                for my $chunk_idx (keys %{$peer_files->{$filename}}) {
                    my $data  = substr $file->{data}, $chunk_idx * $CHUNK_SIZE, $CHUNK_SIZE;
                    $payload .= pack("a32CCS/a*", $file->{filename}, $file->{chunks}, $chunk_idx, $data);
                }
            }
        } else {
            for(1..$CHUNKS_PER_PEER) {
                my $chunk = $CHUNKS_POOL[$CURRENT_CHUNK_IDX];

                my $file = first { $chunk->{filename} eq $_->{filename} } @FILES_POOL;
                my $chunk_idx = $chunk->{chunk_idx};

                my $data  = substr $file->{data}, $chunk_idx * $CHUNK_SIZE, $CHUNK_SIZE;
                $payload .= pack("a32CCS/a*", $file->{filename}, $file->{chunks}, $chunk_idx, $data);

                $PEERS_FILES{$uuid}{$file->{filename}}{$chunk_idx} = 1;

                $CURRENT_CHUNK_IDX++;
                $CURRENT_CHUNK_IDX = 0 unless $CURRENT_CHUNK_IDX < @CHUNKS_POOL;
            }
        }

        response($hdl, RESP_CODE_OK, $payload);
    });
}

=cut
MSG_CHECK_FILE
REQ:  $uuid_bin16$fileid32$md5data16         a16a32a16
RESP:
=cut

sub msg_check_file {
    my ($hdl) = @_;

    $hdl->push_read(chunk => 16, sub {
        my ($hdl, $data) = @_;
        return response($hdl, RESP_CODE_ERR_ILLEGAL_MODE) if $CURRENT_MODE ne ARBT_MODE_RUN;

        my $uuid = unpack("a16", $data);
        $uuid = uuid_to_string($uuid);
        return response($hdl, RESP_CODE_ERR_UNKNOWN_PEER) unless $PEERS_POOL{$uuid};

        _log_in($hdl, "Request for file check: UUID=$uuid");

        $hdl->push_read(chunk => 32 + 16, sub {
            my ($hdl, $data) = @_;
            my ($filename, $data_md5) = unpack("a32a16", $data);
            my $data_md5hex = unpack("h*", pack("a*", $data_md5));

            my $file = first { $_->{filename} eq $filename } @FILES_POOL;
            if($file) {
                if($data_md5 eq $file->{data_md5}) {
                    $PEERS_POOL{$uuid}{files}{$filename} = 1;
                    $PEERS_POOL{$uuid}{last_update} = AnyEvent::now;
                    _log_sys($hdl, "Check file $filename OK");
                    response($hdl, RESP_CODE_OK);
                } else {
                    $PEERS_POOL{$uuid}{files}{$filename} = 0;
                    $PEERS_POOL{$uuid}{last_update} = AnyEvent::now;
                    _log_sys($hdl, "Check file $filename ERROR MD5 $data_md5hex != $file->{data_md5hex}");
                    response($hdl, RESP_CODE_ERR_MD5);
                }
            } else {
                _log_sys($hdl, "Unknown file $filename");
                response($hdl, RESP_CODE_ERR_UNKNOWN_FILENAME);
            }
        });
    });
}

sub finish_cb {
    _switch_mode(ARBT_MODE_FINISH);

    my %result = ();
    for my $uuid (keys %PEERS_POOL) {
        $result{$uuid}{last_update} = $PEERS_POOL{$uuid}{last_update};
        $result{$uuid}{$_} = 0 for qw/ok error na/;
        for my $file (@FILES_POOL) {
            my $r = $PEERS_POOL{$uuid}{files}{$file->{filename}};
            if($r) { 
                $result{$uuid}{ok}++;
            } elsif(defined $r) {
                $result{$uuid}{error}++;
            } else {
                $result{$uuid}{na}++;
            }
        }
    }

    _log_sys(undef, "RESULTS TABLE");
    my $idx = 1;
    for my $uuid (sort { $result{$b}{ok} <=> $result{$a}{ok} || $result{$a}{last_update} <=> $result{$b}{last_update} } keys %result) {
        _log_sys(undef, sprintf "%d. [%s:%d] UUID %s. OK %d. ERROR %d. NA %d. Last update %d", 
                $idx++, $PEERS_POOL{$uuid}{ip}, $PEERS_POOL{$uuid}{port}, $uuid, 
                (map { $result{$uuid}{$_} } qw/ok error na last_update/));
    }
    _log_sys(undef, "Total files: ".(scalar @FILES_POOL));
    exit;
}

my %URANDOM_HANDLERS = ();
sub _generate_file {
    my ($cb) = @_;

    open(my $fh, '<', '/dev/urandom') or die "Can't read urandom: $!";
    my $hdl = AnyEvent::Handle->new(fh => $fh);
    $URANDOM_HANDLERS{$hdl} = $hdl;

    my $chunks = int(rand(9)) + 8; #from 8 to 16;

    $IN_FILE_GENERATION++;
    $hdl->push_read(chunk => 16, sub {
        my ($hdl, $data) = @_;
        my $filename = unpack("H*", $data);
        $hdl->push_read(chunk => $CHUNK_SIZE*$chunks, sub {
            my ($hdl, $data) = @_;
            push @FILES_POOL, {
                filename     => $filename,
                data         => $data,
                chunks       => $chunks,
                data_md5     => md5($data),
                data_md5hex  => md5_hex($data),
            };
            push @CHUNKS_POOL, map { +{ filename => $filename, chunk_idx => $_ } } 0..($chunks-1);

            _log_sys(undef, "File generated. Name=$filename. Chunks=$chunks. Data lenght=".length($data).". Data md5=".md5_hex($data));
            $IN_FILE_GENERATION--;
            delete $URANDOM_HANDLERS{$hdl};
        });
    });
}

sub _switch_mode {
    my ($mode) = @_;
    return if $CURRENT_MODE eq $mode;
    $CURRENT_MODE = $mode;

    if($CURRENT_MODE eq ARBT_MODE_INIT) {
        undef %PEERS_POOL;
        undef @FILES_POOL;
        undef @CHUNKS_POOL;
        undef %PEERS_FILES;
        $TOTAL_CHUNKS = 0;
        $CURRENT_CHUNK_IDX = 0;
        $CHUNKS_PER_PEER = 0;
    }
    _log_sys(undef, "Mode swithced to '$CURRENT_MODE'");  
}

sub _log_sys { _log("=", @_) } 
sub _log_out { _log(">", @_) }
sub _log_in  { _log("<", @_) }

sub _log {
    my ($mode, $hdl, $msg) = @_;
    my $prefix = $mode x 3;
    if($hdl) {
        (undef, my $ip, my $port) = @{$connects{$hdl}};
        $prefix .= " [$ip:$port]";
    } 
    say $prefix." ".$msg;
}
