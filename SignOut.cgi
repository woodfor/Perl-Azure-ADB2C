#!/usr/bin/perl

use strict;
use Data::Dumper;
use CGI;
use File::Basename;
use JSON;
use lib dirname (__FILE__);

use LoginOut;

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

#1. clear your sign in session

#2. logout at Azure
my $mode = $cgi->param('mode') || 'Logout';
my $lang = 'EN';
$lang = $cgi->param('Lang');

my $state = {
	Mode => $mode,
	Lang => $lang,
};
my $auth = LoginOut->new(
	client_id => $cfg->{B2C_APP_ID},
	tenant_id => $cfg->{B2C_TENANT_NAME},
	policy => $cfg->{B2C_POLICY},
	redirect_uri => $cfg->{B2C_REDIRECT_URL},
	state => encode_json($state),
);
my $url = $auth->signout; 
print "Location: $url\n\n";
exit;