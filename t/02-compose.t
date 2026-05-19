#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

my $file = 'config/docker/cloudflare/compose.yml';
ok( -f $file, 'compose config exists' );

open my $fh, '<', $file or die "Unable to read $file: $!";
my $text = do { local $/; <$fh> };
close $fh;

like( $text, qr/^services:\n  cloudflare:\n/m, 'compose declares the cloudflare service' );
like( $text, qr/image: cloudflare\/cloudflared:latest/, 'compose uses cloudflared latest image' );
like( $text, qr/environment:\n\s+UUID: \$\{UUID\}/, 'compose exposes UUID in the environment' );
like( $text, qr/- \.\/tunnel:\/var\/cloudflared/, 'compose mounts the project tunnel directory' );
like( $text, qr/- \.\/config\/docker\/cloudflare\/startup:\/opt\/startup:ro/, 'compose mounts the shipped startup wrapper' );
like( $text, qr/entrypoint:\n\s+- \/opt\/startup/, 'compose runs through the startup entrypoint' );
like( $text, qr/\/etc\/cloudflared\/config\.yml/, 'compose runs cloudflared against the copied etc config' );
like( $text, qr/--post-quantum/, 'compose uses the corrected post-quantum flag spelling' );
like( $text, qr/\$\{CLOUDFLARE_DOMAIN_ID\}/, 'compose reads CLOUDFLARE_DOMAIN_ID from env' );

my $startup = 'config/docker/cloudflare/startup';
ok( -f $startup, 'startup script exists' );
open my $startup_fh, '<', $startup or die "Unable to read $startup: $!";
my $startup_text = do { local $/; <$startup_fh> };
close $startup_fh;

like( $startup_text, qr/^#!\/bin\/sh$/m, 'startup script uses sh' );
like( $startup_text, qr/cp "\/var\/cloudflared\/\$\{UUID\}\.json" "\/etc\/cloudflared\/\$\{UUID\}\.json"/, 'startup script copies the UUID credential file' );
like( $startup_text, qr/cp \/var\/cloudflared\/cert\.pem \/etc\/cloudflared\/cert\.pem/, 'startup script copies cert.pem' );
like( $startup_text, qr/cp \/var\/cloudflared\/config\.yml \/etc\/cloudflared\/config\.yml/, 'startup script copies config.yml' );
like( $startup_text, qr/chmod \+x \/opt\/startup/, 'startup script makes /opt/startup executable' );
like( $startup_text, qr/exec cloudflared --no-autoupdate "\$@"/, 'startup script execs cloudflared without autoupdate' );

done_testing;
