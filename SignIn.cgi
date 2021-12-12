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

my $state = {
	Mode=>'Signin',
	Lang=>'EN',
	AzureLang=>'en',
};
if(defined (my $mode = $cgi->param('mode')) && defined (my $id = $cgi->param('id'))){
	$state = {
		Mode => $mode, 
		ID => $id,
		Lang => 'EN'
	};
}
if(defined $cgi->param('Lang') && $cgi->param('Lang') ne ''){
	my $lang = $cgi->param('Lang');
	$state->{Lang} = $cgi->param('Lang');
	if($lang eq 'EN'){
		$state->{AzureLang} = 'en';
	}elsif($lang eq 'CN'){
		$state->{AzureLang} = 'zh-hans';
	}elsif($lang eq 'VI'){
		$state->{AzureLang} = 'vi-VN';
	}elsif($lang eq 'HK'){
		$state->{AzureLang} = 'zh-Hant';
	}
}
my $auth = LoginOut->new(
	client_id => $cfg->{B2C_APP_ID},
	tenant_id => $cfg->{B2C_TENANT_NAME},
	policy => $cfg->{B2C_POLICY},
	redirect_uri => $cfg->{B2C_REDIRECT_URL},
	state => encode_json($state),
	lang=>$state->{AzureLang},
);
my $url = $auth->signin; 
print "Location: $url\n\n";
exit;