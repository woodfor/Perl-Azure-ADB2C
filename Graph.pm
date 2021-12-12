package Graph;
  use Moo;
  use Types::Standard qw/Str Int InstanceOf CodeRef Object Any/;
  use JSON::MaybeXS;
  use HTTP::Tiny;
  use lib qw(../../lib);
  use Cache::FileCache;
  use LWP::UserAgent;
  use Data::Dumper;

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
      LWP::UserAgent->new(agent => "Graph/$VERSION", timeout => $self->timeout)
    }
  );

  has cache => (is => 'rw', required => 1, lazy => 1,
    default     => sub {
      my $self = shift;
      new Cache::FileCache();
    }
  );

  has client_id => (
    is => 'ro',
    isa => Str,
    required => 1,
  );

  has secret => (
    is => 'ro',
    isa => Str,
    required => 1,
  );

  has tenant_id => (
    is => 'ro',
    isa => Str,
    required => 1,
  );

  has tenant_name => (
    is => 'ro',
    isa => Str,
    required => 1,
  );

  has graph_endpoint => (
    is => 'ro',
    isa => Str,
    lazy => 1,
    default => sub {
      my $self = shift;
      sprintf 'https://login.microsoftonline.com/%s/oauth2/v2.0/token', $self->tenant_id;
    }
  );

  has graph_user_endpoint => (
    is => 'ro',
    isa => Str,
    lazy => 1,
    default => sub {
      my $self = shift;
      'https://graph.microsoft.com/v1.0/users';
    }
  );

  has graph_group_endpoint => (
    is => 'ro',
    isa => Str,
    lazy => 1,
    default => sub {
      my $self = shift;
      'https://graph.microsoft.com/v1.0/groups';
    }
  );

sub access_token {
    my $self = shift; 
    return $self->_refresh;;
  }

has resp_code => (
    is => 'rw',
    isa => Int,
    lazy => 1,
    default => sub { 404 }
);
has resp_content=> (
    is => 'rw',
    isa => Any,
    lazy => 1,
);

has current_creds => (is => 'rw');

has expiration => (
    is => 'rw',
    isa => Int,
    lazy => 1,
    default => sub { 0 }
);

sub createUser {
  my ($self, %args) = @_;
  my $token = $self->access_token;
  my $ua = $self->ua;
  my $req = HTTP::Request->new(POST => $self->graph_user_endpoint);
  my $auth = sprintf 'Bearer %s', $token;
  $req->header('Content-Type'=>'application/json', Authorization => $auth );
  my $json = encode_json { 
      'displayName' => $args{DisplayName},
      'identities' => [
          {
              'signInType' => 'emailAddress',
              'issuer' => $self->{tenant_name} . ".onmicrosoft.com",
              'issuerAssignedId' => $args{Email}
          }
      ],
      'passwordProfile' => {
          'password' => $args{Password},
          'forceChangePasswordNextSignIn' => 'false'
      },
      'passwordPolicies' => 'DisablePasswordExpiration'
  };
  $req->content($json);
  my $res = $ua->request($req);
  $self->resp_code($res->code); #201 means success
  $self->resp_content(decode_json($res->content));
}

sub createUserByName {
    my ($self, %args) = @_;
    if(!defined $args{DisplayName} || !defined $args{UserName} || !defined $args{Password}) { 
        GAPlog::Abort(ERR_MSG=>"Missing display name, username and/or password!");
    }

    my $pwdPolicies = "DisablePasswordExpiration";
    $pwdPolicies = $args{PwdPolicies} if(defined $args{PwdPolicies} & $args{PwdPolicies} ne "");

    my $token = $self->access_token;
    my $ua = $self->ua;
    my $req = HTTP::Request->new(POST=>$self->graph_user_endpoint);
    my $auth = sprintf 'Bearer %s', $token;
    $req->header('Content-Type'=>'application/json', Authorization=>$auth);

    my $json = encode_json { 
        'displayName' => $args{DisplayName},
        'identities' => [
            {
                'signInType' => 'userName',
                'issuer' => $self->{tenant_name} . ".onmicrosoft.com",
            'issuerAssignedId' => $args{UserName}
            }
        ],
        'passwordProfile' => {
            'password' => $args{Password},
            'forceChangePasswordNextSignIn' => 'false'
        },
        'passwordPolicies' => $pwdPolicies,
        'companyName' => $args{CompanyName},
        'employeeId' => $args{PersonID},
    };
    $req->content($json);
    my $res = $ua->request($req);
    $self->resp_code($res->code); # 201 means success.
    $self->resp_content(decode_json($res->content)); 
}

sub createUserByNameAndEmail {
  my ($self, %args) = @_;
  my $token = $self->access_token;
  my $ua = $self->ua;
  my $req = HTTP::Request->new(POST => $self->graph_user_endpoint);
  my $auth = sprintf 'Bearer %s', $token;
  $req->header('Content-Type'=>'application/json', Authorization => $auth );
  my $json = encode_json { 
      'displayName' => $args{DisplayName},
      'identities' => [
          {
              'signInType' => 'userName',
              'issuer' => $self->{tenant_name} . ".onmicrosoft.com",
              'issuerAssignedId' => $args{UserName}
          },
          {
              'signInType' => 'emailAddress',
              'issuer' => $self->{tenant_name} . ".onmicrosoft.com",
              'issuerAssignedId' => $args{Email}
          }

      ],
      'passwordProfile' => {
          'password' => $args{Password},
          'forceChangePasswordNextSignIn' => 'false'
      },
      'passwordPolicies' => 'DisablePasswordExpiration',
  };
  $req->content($json);
  my $res = $ua->request($req);
  $self->resp_code($res->code); #201 means success
  $self->resp_content(decode_json($res->content)); 
  if($res->code ne '201'){
    GAPlog::stdLog("Graph:createUserByNameAndEmail, Email:$args{Email}", $res->content);
  }
}

sub deleteUser {
    my ($self, %args) = @_;
    if(! defined $args{UID}){
        GAPlog::Abort(ERR_MSG=>'No UID supplied');
    }
    my $res = $self->ua->delete((sprintf '%s/%s', $self->graph_user_endpoint, $args{UID}), {
        headers=>{
            Authorization => sprintf('Bearer %s', $self->access_token),
        }
    });
    $self->resp_code($res->{status}); #204 means succss
    $self->resp_content($res->{content});
}
sub getUser {
    my ($self, %args) = @_;
    if(! defined $args{UID}){
        GAPlog::Abort(ERR_MSG=>'No UID supplied');
    }
    my $res = $self->ua->get((sprintf '%s/%s', $self->graph_user_endpoint, $args{UID}), {
        headers=>{
            Authorization => sprintf('Bearer %s', $self->access_token),
        }
    });
    $self->resp_code($res->{status}); # 204 means success.
    $self->resp_content($res->{content});
}
sub updateUser {
    my ($self, %args) = @_;
    if(! defined $args{UID} || !defined $args{UPT_FLD}){ 
        GAPlog::Abort(ERR_MSG=>'Graph::updateUser, No UID or UPT_FLD supplied');
    }
    my $token = $self->access_token;
    my $ua = $self->ua;
    my $req = HTTP::Request->new(PATCH => $self->graph_user_endpoint . "/$args{UID}");
    my $auth = sprintf 'Bearer %s', $token;
    $req->header('Content-Type'=>'application/json', Authorization => $auth );
    my $content = $args{UPT_FLD};
    $req->content(encode_json($content));
    my $res = $ua->request($req);
    $self->resp_code($res->code); #204 means succss
    $self->resp_content($res->content); 
}

  sub _refresh_from_cache {
    my $self = shift; 
    return $self->cache->get($self->client_id);
  }

  sub _save_to_cache {
    my $self = shift;
    $self->cache->set($self->client_id, $self->current_creds, $self->expiration);
  }

  sub get_access_token {
    my $self = shift;
    my $device_response = $self->ua->post(
      $self->graph_endpoint,
      {
        client_id => $self->client_id,
        scope => 'https://graph.microsoft.com/.default',
        client_secret  => $self->secret,
        grant_type => 'client_credentials',
      },{
          headers =>{ 
              'Content-Type' => 'application/x-www-form-urlencoded', 
          }
      }
    );

    if (not $device_response->{ success }) {
        GAPlog::Abort(ERR_MSG=>$device_response->{content});
    }

    return decode_json($device_response->{ content });
  }

sub _refresh {
    my $self = shift;
    if (not defined $self->current_creds) {
      if(defined (my $token = $self->_refresh_from_cache)) {
          $self->current_creds($token);
          return $token;
      }
    }

    my $token = $self->get_access_token;
    $self->expiration($token->{expires_in});
    $self->current_creds($token->{access_token});
    $self->_save_to_cache;
    return $token->{access_token};
  }


1;
