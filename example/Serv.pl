package Serv;

use strict;
use warnings;
use threads;
use threads::shared;
use Socket;
use IO::Socket::INET;
use IO::Socket::SSL;
use Protocol::WebSocket::Handshake::Server;
use HTTP::Status qw(:constants);
use xclass;

our $VERSION = '1.0.0';

sub start {
    my (%options) = @_;
    my $serv = Tc('Serv', undef, $options{type}, 
        ARRAY => &share([]),
        HASH => &share({
            port => $options{port},
            type => $options{type},
            ssl_cert => $options{ssl_cert},
            ssl_key => $options{ssl_key},
            max_clients => $options{max_clients} // 100,
            clients => Hc({}),
            handle => $options{request_handler} // \&request_handler,
            http => $options{http_handler} // \&http_handler,
            sock => $options{sock_handler} // \&sock_handler,
            router => $options{router} // \&default_router,
            access_log => $options{access_log} // sub {
                my ($client, $request, $response) = @_;
                printf "[%s] %s %s - %d\n", 
                    scalar localtime, 
                    $request->{method}, 
                    $request->{path}, 
                    $response->{status};
            },
            ws_router => $options{ws_router} // \&default_ws_router,
            ws_log => $options{ws_log} // sub {
                my ($client, $message, $response) = @_;
                printf "[WS %s] %s -> %s\n", 
                    scalar localtime, 
                    $message->{type},
                    $response->{broadcast} ? 'broadcast' : 'unicast';
            },
            start_time => time(),

        }),
        CODE => sub {
            my ($serv) = @_;
            my $port = $serv->HASH->get('port');
            my $type = $serv->HASH->get('type');
            my $socket;
            if ($type eq 'https' || $type eq 'wss') {
                $socket = IO::Socket::SSL->new(
                    LocalPort => $serv->{port},
                    Listen => SOMAXCONN,
                    SSL_cert_file => $serv->{ssl_cert},
                    SSL_key_file => $serv->{ssl_key},
                    Reuse => 1,
                ) or die "Cannot create SSL socket: $!";
            } else {
                $socket = IO::Socket::INET->new(
                    LocalPort => $serv->{port},
                    Listen => SOMAXCONN,
                    Reuse => 1,
                ) or die "Cannot create socket: $!";
            }
            while (1) { # Server Loop
                my $sock = $socket->accept();
                next unless $sock;
                my $id = int($client_socket);
                $serv->{clients}->set(
                    $id => &share({
                        sock => $sock, 
                        thread => Tc('Serv::Client', $id,
                            HASH => share({
                                serv => $serv,
                                id => $id
                                sock => $sock
                            }),
                            CODE => sub {
                                my ($client)=@_;
                                my $id = $client->HASH->get('id');
                                my $sock = $client->HASH->get('sock');
                                my $serv = $client->HASH->get('serv');
                                my $type = $serv->HASH->get('type');
                                my $clients = $serv->HASH->get('clients');
                                if ($type eq 'ws' || $type eq 'wss') {
                                    my $hs = Protocol::WebSocket::Handshake::Server->new;
                                    $hs->parse(<$sock>);
                                    if ($hs->is_done) {
                                        print $sock $hs->to_string;
                                        while (1) { # Client Websocket Loop
                                            my $frame = $hs->build_frame;
                                            $frame->append(<$sock>);
                                            if ($frame->is_close) {
                                                last;
                                            }
                                            elsif ($frame->is_text || $frame->is_binary) {
                                                $client->HASH->set(
                                                    'request' => Tc(
                                                        "Serv::Request", 
                                                        $id,
                                                        hash => &share({
                                                            client => $client,
                                                            frame => $frame
                                                        }),
                                                        code => sub {
                                                            my ($request)=@_;
                                                            my $client = $request->HASH->get('client');
                                                            my $serv = $client->HASH->get('serv');
                                                            my $type = $serv->HASH->get('type');
                                                            my $call = $serv->HASH->get('handle');
                                                            $call->($type,$request); # request_handler('ws',$request);
                                                        }
                                                    )->start->detach
                                                );
                                            }
                                        }
                                    }
                                } else {
                                    while (my $document = <$sock>) {
                                        chomp $document;
                                        last if $document eq '';
                                        $client->HASH->set(
                                            'request' => Tc(
                                                "Serv::Request", 
                                                $id,
                                                hash => &share({
                                                    client => $client,
                                                    document => $document
                                                }), 
                                                code => sub {
                                                    my ($document)=@_;
                                                    my $client = $document->HASH->get('client');
                                                    my $serv = $client->HASH->get('serv');
                                                    my $type = $serv->HASH->get('type');
                                                    my $call = $serv->HASH->get('handle');
                                                    $call->($type,$document); # request_handler('http',$document);
                                                }
                                            )->start->detach
                                        );
                                    }
                                }
                                $sock->close();
                                $clients->delete($client_id);
                            }
                        )->start->detach)
                    }
                );
            }
        },
        %options
    );
    $serv->SCALAR->set(\$serv); ### Now ${Serv::http}, ${Serv::https}, ${Serv::ws} or ${Serv::wss} exist 
    $serv->on('before_stop',sub {
        my ($serv) = @_;
        $serv->{clients}->each(sub {
            my ($id, $client) = @_;
            my $request = $client->HASH->get('request');
            $request->stop() if $request;
            my $request = $client->HASH->get('request');
            $client->{thread}->stop();
        });
        $serv->stop();
    });
    return $serv
}

sub request_handler {
    my ($type,$request)=@_;
    my $client = $request->HASH->get('client');
    my $serv = $client->HASH->get('serv');
    my $sock = $client->HASH->get('sock');
    if ($type eq 'ws' || $type eq 'wss') {
        my $frame = $request->HASH->get('frame');
        my $handler = $serv->HASH->get('sock');
        $handler->($serv,$client,$frame,$sock);
    } else {
        my $document = $request->HASH->get('document');
        my $handler = $serv->HASH->get('http');
        $handler->($serv,$client,$document,$sock);
    }
}

sub sock_handler {
    my ($serv, $client, $frame, $sock) = @_;
    
    my $opcode = $frame->opcode;
    my $payload = $frame->payload;
    
    my $message = {
        type => $opcode == 1 ? 'text' : 'binary',
        data => $payload,
        client_id => $client->HASH->get('id'),
    };
    
    my $response = Hc({
        type => 'text',
        data => '',
        broadcast => 0,
    });
    
    my $ws_router = $serv->HASH->get('ws_router') // \&default_ws_router;
    $ws_router->($message, $response, $serv);
    
    if ($response->{broadcast}) {
        $serv->HASH->get('clients')->each(sub {
            my ($id, $cl) = @_;
            _send_ws_frame($cl->HASH->get('sock'), $response->{type}, $response->{data});
        });
    } else {
        _send_ws_frame($sock, $response->{type}, $response->{data});
    }
    
    $serv->HASH->get('ws_log')->($client, $message, $response) if $serv->HASH->get('ws_log');
}

sub _send_ws_frame {
    my ($sock, $type, $data) = @_;
    my $frame = Protocol::WebSocket::Frame->new(
        type => $type,
        buffer => $data,
    );
    $sock->print($frame->to_bytes);
}

sub default_ws_router {
    my ($message, $response, $serv) = @_;
    if ($message->{type} eq 'text') {
        my $data = eval { decode_json($message->{data}) };
        if ($@) {
            $response->{data} = encode_json({error => "Invalid JSON"});
        } elsif ($data->{action} eq 'echo') {
            $response->{data} = encode_json({action => 'echo', data => $data->{data}});
        } elsif ($data->{action} eq 'broadcast') {
            $response->{data} = encode_json({action => 'broadcast', data => $data->{data}});
            $response->{broadcast} = 1;
        } elsif ($data->{action} eq 'stats') {
            $response->{data} = encode_json({
                action => 'stats',
                clients => $serv->HASH->get('clients')->keys->count,
                uptime => time() - $serv->HASH->get('start_time'),
            });
        } else {
            $response->{data} = encode_json({error => "Unknown action"});
        }
    } else {
        $response->{type} = 'binary';
        $response->{data} = $message->{data};  # Echo binary data
    }
}

sub http_handler {
    my ($serv, $client, $document, $sock) = @_;
    
    my ($method, $path, $protocol) = split(' ', $document);
    my %headers;
    my $body = '';
    my $reading_body = 0;
    
    while (my $line = <$sock>) {
        chomp $line;
        if ($line eq '') {
            $reading_body = 1;
            next;
        }
        if ($reading_body) {
            $body .= $line;
        } else {
            my ($key, $value) = split(': ', $line, 2);
            $headers{lc($key)} = $value;
        }
    }
    
    my $request = {
        method => $method,
        path => $path,
        protocol => $protocol,
        headers => \%headers,
        body => $body,
    };
    
    my $response = Hc({
        status => 200,
        headers => Hc({
            'Content-Type' => 'text/html',
            'Server' => "Serv/$VERSION",
        }),
        body => '',
    });
    
    my $router = $serv->HASH->get('router') // \&default_router;
    $router->($request, $response);
    
    $sock->print(
        "HTTP/1.1 $response->{status} " . HTTP::Status::status_message($response->{status}) . "\r\n" .
        join('', map { "$_: $response->{headers}{$_}\r\n" } keys %{$response->{headers}}) .
        "\r\n" .
        $response->{body}
    );
    
    $serv->HASH->get('access_log')->($client, $request, $response) if $serv->HASH->get('access_log');
}

sub default_router {
    my ($request, $response) = @_;
    if ($request->{path} eq '/') {
        $response->{body} = "<html><body><h1>Welcome to Serv</h1></body></html>";
    } elsif ($request->{path} eq '/info') {
        $response->{headers}{'Content-Type'} = 'application/json';
        $response->{body} = encode_json({
            server => "Serv/$VERSION",
            time => time(),
            request => {
                method => $request->{method},
                path => $request->{path},
                headers => $request->{headers},
            },
        });
    } else {
        $response->{status} = 404;
        $response->{body} = "<html><body><h1>404 Not Found</h1></body></html>";
    }
}


1;
