#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard);
use HTTP::Tiny;
use Crypt::JWT qw(decode_jwt);
use LWP::Simple;
use Cache::FileCache;
use JSON;

my $cgi = new CGI;
my $cfg = 'config.json';

$cfg = do {
   open(my $fh, "<:encoding(UTF-8)", $cfg)
        or resp(200, 0, 'Cannot find config.json');
   local $/;
   <$fh>
};
$cfg = eval{decode_json($cfg)};
if(defined $@ && $@ ne ''){
    resp(200, 0, 'json format error ' . $@);
}

my $state = $cgi->param('state');
if(! defined $state || $state eq '' ){
    resp(200, 0, 'illegal request');
}
$state = decode_json($state);

if(defined (my $token = $cgi->param('id_token')) && $cgi->param('id_token') ne ""){
    my $key = $cfg->{B2C_DECODE_KEY_SIGNIN};
    my $certs = decode_json(get($key)); 
    my $data = decode_jwt(token=>$token, kid_keys=>$certs );
    my $res = 'OK';
    if($data->{aud} ne $cfg->{B2C_APP_ID}){
        $res='Invalid APP ID';
    }
    my $c = Cache::FileCache->new();
    my $cache = $c->get($data->{nonce});
    if(! defined $cache){
        resp(200, 0, 'AuthFailed');
    }else{
        resp(200, 1, 'Validation Passed ' . $cache);
        $c->remove($data->{nonce});
    }
}else{
    if($state->{Mode} eq 'Logout'){
        my $url = "signin.cgi?Lang=$state->{Lang}";
        print "Location: $url\n\n";
    }
}
exit;


sub resp {
    my $status = $_[0];
    my $success = $_[1];
    my $msg = $_[2];
    print $cgi->header(
        -type   => 'application/json',
        -status => $status,
        -charset => 'utf-8',
    );
    if(defined $success && defined $msg) {
        my $content = {
            'success' => $success,
            'message' => $msg,
        };
        print encode_json $content;
    }
    exit;
}


