#!/usr/bin/env perl
use strict;
use warnings;

use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON::PP qw(decode_json);
use Test::More;

use lib 'lib';
use Cloudflare::Manager;

sub harness {
    my (%args) = @_;
    my $cwd = tempdir( CLEANUP => 1 );
    my @calls;
    my $stdout = q{};
    my $stderr = q{};
    open my $stdout_fh, '>', \$stdout or die $!;
    open my $stderr_fh, '>', \$stderr or die $!;

    my $runner = Cloudflare::Manager->new(
        cwd           => $cwd,
        stdout_fh     => $stdout_fh,
        stderr_fh     => $stderr_fh,
        system_runner => $args{system_runner} || sub {
            push @calls, [@_];
            return 0;
        },
    );

    return ( $runner, $cwd, \@calls, \$stdout, \$stderr );
}

{
    my ( $runner, $cwd, $calls ) = harness();
    my $result = $runner->execute_login();
    is( $result->{mode}, 'login', 'login returns login mode' );
    ok( -d File::Spec->catdir( $cwd, 'tunnel' ), 'login creates tunnel dir' );
    is_deeply(
        $calls->[0],
        [
            'docker', 'run', '-u', 'root', '--rm', '-it',
            '-v', File::Spec->catdir( $cwd, 'tunnel' ) . ':/root/.cloudflared',
            'cloudflare/cloudflared:latest',
            'tunnel', 'login'
        ],
        'login runs the expected cloudflared command'
    );
}

{
    my ( $runner, $cwd, $calls ) = harness();
    _write(
        File::Spec->catfile( $cwd, '.env' ),
        "# project values\nOTHER=keep\n"
    );
    my $result = $runner->execute_create('demo-tunnel');
    is( $result->{domain_id}, 'demo-tunnel', 'create returns explicit domain id' );
    like( _slurp( File::Spec->catfile( $cwd, '.env' ) ), qr/^OTHER=keep$/m, 'create preserves existing env lines' );
    like( _slurp( File::Spec->catfile( $cwd, '.env' ) ), qr/^CLOUDFLARE_DOMAIN_ID=demo-tunnel$/m, 'create stores Cloudflare domain id' );
    like( _slurp( File::Spec->catfile( $cwd, '.env' ) ), qr/^DOMAIN_ID=demo-tunnel$/m, 'create stores DOMAIN_ID alias for compose use' );
    is( $calls->[0][-2], 'create', 'create command includes cloudflared create subcommand' );
    is( $calls->[0][-1], 'demo-tunnel', 'create command passes the explicit id' );
}

{
    my ( $runner, $cwd, $calls ) = harness();
    _write( File::Spec->catfile( $cwd, '.env' ), "CLOUDFLARE_DOMAIN_ID=from-env\n" );
    my $result = $runner->execute_create();
    is( $result->{domain_id}, 'from-env', 'create falls back to .env domain id' );
    is( $calls->[0][-1], 'from-env', 'create command uses env fallback value' );
}

{
    my ( $runner, $cwd ) = harness();
    _write( File::Spec->catfile( $cwd, '.env' ), "WEB_CONTAINER=nginx\nWEB_CONTAINER_PORT=8080\n" );
    my $result = $runner->execute_uuid( 'uuid-123', 'demo-tunnel' );
    is( $result->{uuid}, 'uuid-123', 'uuid command returns uuid' );
    is( $result->{web_container}, 'nginx', 'uuid uses env fallback for container' );
    is( $result->{web_container_port}, '8080', 'uuid uses env fallback for port' );
    my $config = _slurp( File::Spec->catfile( $cwd, 'tunnel', 'config.yml' ) );
    like( $config, qr/^tunnel: uuid-123$/m, 'uuid writes tunnel id into config' );
    like( $config, qr/^url: http:\/\/nginx:8080$/m, 'uuid writes target web container url' );
    like( $config, qr{^credentials-file: /etc/cloudflared/uuid-123\.json$}m, 'uuid writes runtime credentials path' );
    like( _slurp( File::Spec->catfile( $cwd, '.env' ) ), qr/^UUID=uuid-123$/m, 'uuid stores UUID in env file' );
}

{
    my ( $runner, $cwd ) = harness();
    my $result = $runner->execute_uuid( 'uuid-456', 'demo-tunnel', 'web', 80 );
    is( $result->{web_container}, 'web', 'uuid accepts explicit web container' );
    is( $result->{web_container_port}, 80, 'uuid accepts explicit web port' );
    like( _slurp( File::Spec->catfile( $cwd, '.env' ) ), qr/^WEB_CONTAINER=web$/m, 'uuid stores explicit web container' );
    like( _slurp( File::Spec->catfile( $cwd, '.env' ) ), qr/^WEB_CONTAINER_PORT=80$/m, 'uuid stores explicit web port' );
}

{
    my ( $runner, $cwd, $calls ) = harness();
    _write(
        File::Spec->catfile( $cwd, '.env' ),
        "CLOUDFLARE_DOMAIN_ID=demo-tunnel\nCLOUDFLARE_DOMAIN_NAME=app.example.com\n"
    );
    my $result = $runner->execute_dns();
    is( $result->{domain_name}, 'app.example.com', 'dns uses env fallback hostname' );
    is_deeply(
        $calls->[0],
        [
            'docker', 'run', '-u', 'root', '--rm', '-it',
            '-v', File::Spec->catdir( $cwd, 'tunnel' ) . ':/root/.cloudflared',
            'cloudflare/cloudflared:latest',
            'tunnel', 'route', 'dns', 'demo-tunnel', 'app.example.com'
        ],
        'dns runs the expected route dns command'
    );
    like( _slurp( File::Spec->catfile( $cwd, '.env' ) ), qr/^DOMAIN_NAME=app.example.com$/m, 'dns stores DOMAIN_NAME alias' );
}

{
    my ( $runner, $cwd, undef, $stdout, $stderr ) = harness();
    my $code = $runner->main_login();
    is( $code, 0, 'main_login returns success code' );
    is( $$stderr, q{}, 'main_login leaves stderr empty' );
    my $json = decode_json($$stdout);
    is( $json->{mode}, 'login', 'main_login prints JSON' );
}

{
    my ( $runner, undef, undef, $stdout, $stderr ) = harness();
    my $code = $runner->main_create( 'one', 'two' );
    is( $code, 2, 'main_create returns nonzero on usage error' );
    is( $$stdout, q{}, 'main_create error leaves stdout empty' );
    like( $$stderr, qr/^Usage: dashboard cloudflare\.create <DOMAIN_ID>$/, 'main_create prints usage error' );
}

{
    my ( $runner, $cwd, undef, $stdout, $stderr ) = harness();
    _write( File::Spec->catfile( $cwd, '.env' ), "CLOUDFLARE_DOMAIN_ID=demo-tunnel\n" );
    my $code = $runner->main_dns();
    is( $code, 2, 'main_dns fails without required values' );
    is( $$stdout, q{}, 'main_dns missing args leaves stdout empty' );
    like( $$stderr, qr/DOMAIN_NAME is required/, 'main_dns reports missing domain name' );
}

{
    my @calls;
    my ( $runner ) = harness(
        system_runner => sub {
            push @calls, [@_];
            return 9;
        },
    );
    my $error = eval { $runner->execute_login(); 1 };
    ok( !$error, 'system failure causes execute_login to die' );
    like( $@, qr/exit code 9/, 'system failure names the failing exit code' );
}

{
    my ( $runner ) = harness();
    is( $runner->resolve_web_container( undef, {} ), 'web', 'default web container is web' );
    is( $runner->resolve_web_port( undef, {} ), 80, 'default web port is 80' );
    like(
        eval { $runner->resolve_domain_id( undef, {} ); 1 } ? q{} : $@,
        qr/CLOUDFLARE_DOMAIN_ID/,
        'missing domain id error points at env fallback'
    );
}

{
    my $cwd = tempdir( CLEANUP => 1 );
    my $runner = Cloudflare::Manager->new( cwd => $cwd );
    isa_ok( $runner, 'Cloudflare::Manager', 'constructor works without an injected system runner' );
    is( $runner->{system_runner}->('true'), 0, 'default system runner returns zero for a successful command' );
}

{
    my ( $runner, $cwd, undef, $stdout, $stderr ) = harness();
    my $code = $runner->main_uuid( 'uuid-main', 'demo-tunnel', 'app', 443 );
    is( $code, 0, 'main_uuid returns success code' );
    is( $$stderr, q{}, 'main_uuid leaves stderr empty on success' );
    my $json = decode_json($$stdout);
    is( $json->{uuid}, 'uuid-main', 'main_uuid prints JSON output' );
    like( _slurp( File::Spec->catfile( $cwd, 'tunnel', 'config.yml' ) ), qr/^url: http:\/\/app:443$/m, 'main_uuid writes the requested target URL' );
}

{
    my ( $runner ) = harness();
    like(
        eval { $runner->execute_login('extra'); 1 } ? q{} : $@,
        qr/^Usage: dashboard cloudflare\.login$/,
        'execute_login rejects unexpected arguments'
    );
    like(
        eval { $runner->execute_uuid(); 1 } ? q{} : $@,
        qr/^Usage: dashboard cloudflare\.uuid <UUID> <DOMAIN_ID> \[WEB_CONTAINER\] \[WEB_CONTAINER_PORT\]$/,
        'execute_uuid rejects a missing UUID argument list'
    );
    like(
        eval { $runner->execute_dns( 'one', 'two', 'three' ); 1 } ? q{} : $@,
        qr/^Usage: dashboard cloudflare\.dns <DOMAIN_ID> <DOMAIN_NAME>$/,
        'execute_dns rejects extra arguments'
    );
}

sub _write {
    my ( $file, $content ) = @_;
    my ( $volume, $dir ) = File::Spec->splitpath($file);
    make_path($dir) if $dir && !-d $dir;
    open my $fh, '>', $file or die "Unable to write $file: $!";
    print {$fh} $content;
    close $fh or die "Unable to close $file: $!";
}

sub _slurp {
    my ($file) = @_;
    open my $fh, '<', $file or die "Unable to read $file: $!";
    local $/;
    my $content = <$fh>;
    close $fh or die "Unable to close $file: $!";
    return $content;
}

done_testing;
