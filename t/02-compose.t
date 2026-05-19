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
like( $text, qr/build:\n\s+context: \$\{cloudflare_DDDC\}\/cloudflare\n\s+dockerfile: Dockerfile/, 'compose builds the custom cloudflare image from cloudflare_DDDC/cloudflare' );
like( $text, qr/^    platform: linux\/amd64$/m, 'compose pins the cloudflare runtime to linux/amd64' );
unlike( $text, qr/^    image:/m, 'compose does not add a redundant image tag for the build-only service' );
like( $text, qr/^    user: root$/m, 'compose runs the startup wrapper as root so it can stage /etc/cloudflared' );
like( $text, qr/environment:\n\s+UUID: \$\{UUID\}/, 'compose exposes UUID in the environment' );
like( $text, qr/- \.\/tunnel:\/var\/cloudflared/, 'compose mounts the project tunnel directory' );
like( $text, qr/entrypoint:\n\s+- \/opt\/startup/, 'compose runs through the startup entrypoint' );
like( $text, qr/--post-quantum/, 'compose uses the corrected post-quantum flag spelling' );
like( $text, qr/command:\n\s+- --post-quantum\n\s+- tunnel\n\s+- run\n\s+- \$\{CLOUDFLARE_DOMAIN_ID\}/, 'compose uses the expected cloudflared command order' );
like( $text, qr/\$\{CLOUDFLARE_DOMAIN_ID\}/, 'compose reads CLOUDFLARE_DOMAIN_ID from env' );

my $dockerfile = 'config/docker/cloudflare/Dockerfile';
ok( -f $dockerfile, 'Dockerfile exists' );
open my $dockerfile_fh, '<', $dockerfile or die "Unable to read $dockerfile: $!";
my $dockerfile_text = do { local $/; <$dockerfile_fh> };
close $dockerfile_fh;

like( $dockerfile_text, qr/^FROM perl:5\.36 AS builder$/m, 'Dockerfile uses a Perl builder stage that matches cloudflared runtime glibc compatibility' );
like( $dockerfile_text, qr/cpanm --notest PAR::Packer/, 'Dockerfile installs PAR::Packer' );
like( $dockerfile_text, qr/pp -o \/build\/startup \/build\/startup\.pl/, 'Dockerfile compiles startup.pl with pp' );
like( $dockerfile_text, qr/cp \/usr\/lib\/x86_64-linux-gnu\/libcrypt\.so\.1 \/build\/runtime-libs\/usr\/lib\/x86_64-linux-gnu\/libcrypt\.so\.1/, 'Dockerfile stages libcrypt.so.1 for the runtime image' );
like( $dockerfile_text, qr/COPY --from=builder \/build\/runtime-libs\/ \//, 'Dockerfile copies runtime shared libraries into the final image' );
like( $dockerfile_text, qr/^FROM cloudflare\/cloudflared:latest$/m, 'Dockerfile uses cloudflared as the runtime stage' );
like( $dockerfile_text, qr/COPY --from=builder --chmod=755 \/build\/startup \/opt\/startup/, 'Dockerfile copies the compiled startup binary into the runtime image with the executable bit set' );

my $startup = 'config/docker/cloudflare/startup.pl';
ok( -f $startup, 'startup.pl exists' );
open my $startup_fh, '<', $startup or die "Unable to read $startup: $!";
my $startup_text = do { local $/; <$startup_fh> };
close $startup_fh;

like( $startup_text, qr/^#!\/usr\/bin\/env perl$/m, 'startup.pl uses Perl' );
like( $startup_text, qr/use File::Copy qw\(copy\);/, 'startup.pl uses File::Copy' );
like( $startup_text, qr/use File::Path qw\(make_path\);/, 'startup.pl uses File::Path' );
like( $startup_text, qr/\$ENV\{UUID\}/, 'startup.pl reads UUID from the environment' );
like( $startup_text, qr/copy\( "\/var\/cloudflared\/\$uuid\.json", "\/etc\/cloudflared\/\$uuid\.json" \)/, 'startup.pl copies the UUID credential file' );
like( $startup_text, qr/copy\( '\/var\/cloudflared\/cert\.pem', '\/etc\/cloudflared\/cert\.pem' \)/, 'startup.pl copies cert.pem' );
like( $startup_text, qr/copy\( '\/var\/cloudflared\/config\.yml', '\/etc\/cloudflared\/config\.yml' \)/, 'startup.pl copies config.yml' );
like( $startup_text, qr/chown 0, 0, "\/etc\/cloudflared\/\$uuid\.json"/, 'startup.pl chowns the UUID credential file to root' );
like( $startup_text, qr/exec 'cloudflared', '--no-autoupdate', \@ARGV/, 'startup.pl execs cloudflared without autoupdate' );

done_testing;
