#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

my $file = 'config/docker/compose.yml';
ok( -f $file, 'compose config exists' );

open my $fh, '<', $file or die "Unable to read $file: $!";
my $text = do { local $/; <$fh> };
close $fh;

like( $text, qr/^services:\n  cloudflare:\n/m, 'compose declares the cloudflare service' );
like( $text, qr/image: cloudflare\/cloudflared:latest/, 'compose uses cloudflared latest image' );
like( $text, qr/- \.\/tunnel:\/var\/cloudflared/, 'compose mounts the project tunnel directory' );
like( $text, qr/--post-quantum/, 'compose uses the corrected post-quantum flag spelling' );
like( $text, qr/\$\{DOMAIN_ID\}/, 'compose reads DOMAIN_ID from env' );

done_testing;
