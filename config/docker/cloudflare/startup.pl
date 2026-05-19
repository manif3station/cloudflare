#!/usr/bin/env perl
use strict;
use warnings;

use File::Copy qw(copy);
use File::Path qw(make_path);

my $uuid = $ENV{UUID} // q{};
die "UUID environment variable is required\n" if $uuid eq q{};

make_path('/etc/cloudflared');

copy( "/var/cloudflared/$uuid.json", "/etc/cloudflared/$uuid.json" )
  or die "Unable to copy /var/cloudflared/$uuid.json: $!";
copy( '/var/cloudflared/cert.pem', '/etc/cloudflared/cert.pem' )
  or die "Unable to copy /var/cloudflared/cert.pem: $!";
copy( '/var/cloudflared/config.yml', '/etc/cloudflared/config.yml' )
  or die "Unable to copy /var/cloudflared/config.yml: $!";

chown 0, 0, "/etc/cloudflared/$uuid.json"
  or die "Unable to chown /etc/cloudflared/$uuid.json: $!";
chown 0, 0, '/etc/cloudflared/cert.pem'
  or die "Unable to chown /etc/cloudflared/cert.pem: $!";
chown 0, 0, '/etc/cloudflared/config.yml'
  or die "Unable to chown /etc/cloudflared/config.yml: $!";

exec 'cloudflared', '--no-autoupdate', @ARGV
  or die "Unable to exec cloudflared: $!";
