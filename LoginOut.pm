package LoginOut;
  use Moo;
  use Types::Standard qw/Str Int InstanceOf CodeRef Object Any/;
  use JSON::MaybeXS;
  use Cache::FileCache;
  use CGI qw(:standard);

  our $VERSION = '0.01';

  has timeout => (
    is => 'ro',
    isa => Int,
    default => 10
  );

  has ua => (
    is => 'ro',
    isa => Object,
    lazy => 1,
    default => sub{
      my $self = shift;
      LWP::UserAgent->new(agent => "B2C/$VERSION", timeout => $self->timeout)
    }
  );

  has cache => (is => 'rw', required => 1, lazy => 1,
    default     => sub {
      my $self = shift;
      new Cache::FileCache();
    }
  );


  has resource_id => (
    is => 'ro',
    isa => Str,
    # required => 1,
  );

  has message_handler => (
    is => 'ro',
    isa => CodeRef,
    # required => 1,
  );

  has tenant_id => (
    is => 'ro',
    isa => Str,
    required => 1,
    default => sub {
      $ENV{AZURE_TENANT_ID}
    }
  );
  has state => (
    is => 'ro',
    isa => Str,
    required => 1,
  );
  has policy => (
    is => 'ro',
    isa => Str,
    required => 1, 
  );
  has redirect_uri => (
    is => 'ro',
    isa => Str,
    required => 1,
  );

  has lang => (
    is => 'ro',
    isa => Str,
    required => 0,
    default => sub {
      'en'
    }
  );

  has client_id => (
    is => 'ro',
    isa => Str,
    required => 1,
    default => sub {
      $ENV{AZURE_CLIENT_ID}
    }
  );

  has ad_url => (
    is => 'ro',
    isa => Str,
    lazy => 1,
    default => sub {
      my $self = shift;
      sprintf 'https://%s.b2clogin.com/%s.onmicrosoft.com', $self->tenant_id, $self->tenant_id;
    },
  );

  has sign_endpoint => (
    is => 'ro',
    isa => Str,
    lazy => 1,
    default => sub {
      my $self = shift;
      sprintf '%s/%s/oauth2/v2.0/authorize', $self->ad_url, $self->policy;
    }
  );

  has signout_endpoint => (
    is => 'ro',
    isa => Str,
    lazy => 1,
    default => sub {
      my $self = shift;
      sprintf '%s/%s/oauth2/v2.0/logout', $self->ad_url, $self->policy;
    }
  );

  has device_endpoint => (
    is => 'ro',
    isa => Str,
    lazy => 1,
    default => sub {
      my $self = shift;
      sprintf '%s/%s/oauth2/devicecode', $self->ad_url, $self->tenant_id;
    }
  );

  has token_endpoint => (
    is => 'ro',
    isa => Str,
    lazy => 1,
    default => sub {
      my $self = shift;
      sprintf "%s/%s/oauth2/token", $self->ad_url, $self->tenant_id;
    }
  );

  has expiration => (
    is => 'rw',
    isa => Int,
    lazy => 1,
    default => sub { 0 }
  );

sub signin {
    my $self = shift;
    srand(time());
    my @set = ('0' .. '9', 'A' .. 'Z');
    my $token = join '' =>map $set[rand @set], 1..64;
    $self->cache->set($token, '1', '30 m');
    my $url = sprintf $self->sign_endpoint . 
        '?client_id=%s&response_type=%s&redirect_uri=%s&response_mode=%s&scope=%s&nonce=%s&state=%s&ui_locales=%s' , 
        $self->client_id, 'id_token', $self->redirect_uri,
        'query', 'openid', $token, $self->state, $self->lang;
    return $url;
  }

  sub signout {
    my $self = shift;
    my $url = sprintf $self->signout_endpoint . 
        '?post_logout_redirect_uri=%s&state=%s' , 
        $self->redirect_uri, $self->state;
    return $url;
  }



1;
