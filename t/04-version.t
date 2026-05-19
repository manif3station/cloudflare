#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

my $env_file = '.env';
my $changes  = 'Changes';

open my $env_fh, '<', $env_file or die "Unable to read $env_file: $!";
my $env_text = do { local $/; <$env_fh> };
close $env_fh;

open my $changes_fh, '<', $changes or die "Unable to read $changes: $!";
my $changes_text = do { local $/; <$changes_fh> };
close $changes_fh;

like( $env_text, qr/^VERSION=(\d+\.\d+)$/m, '.env declares VERSION=x.xx' );
my ($env_version) = $env_text =~ /^VERSION=(\d+\.\d+)$/m;
my ($changes_version) = $changes_text =~ /^(\d+\.\d+)\s+\d{4}-\d{2}-\d{2}$/m;

ok( defined $changes_version, 'Changes has a top release entry' );
is( $env_version, $changes_version, '.env VERSION matches the latest Changes entry' );

done_testing;
