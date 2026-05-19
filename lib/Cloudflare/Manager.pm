package Cloudflare::Manager;

use strict;
use warnings;

use Cwd qw(getcwd);
use File::Path qw(make_path);
use File::Spec;
use JSON::PP qw(encode_json);

sub new {
    my ( $class, %args ) = @_;
    return bless {
        cwd           => $args{cwd} || getcwd(),
        stdout_fh     => $args{stdout_fh} || \*STDOUT,
        stderr_fh     => $args{stderr_fh} || \*STDERR,
        system_runner => $args{system_runner} || sub { system(@_); return $? >> 8; },
    }, $class;
}

sub main_login  { return shift->_run_main( 'login',  @_ ) }
sub main_create { return shift->_run_main( 'create', @_ ) }
sub main_uuid   { return shift->_run_main( 'uuid',   @_ ) }
sub main_dns    { return shift->_run_main( 'dns',    @_ ) }

sub _run_main {
    my ( $class, $mode, @argv ) = @_;
    my $self = ref($class) ? $class : $class->new;
    my $code = eval {
        my $method = "execute_$mode";
        my $result = $self->$method(@argv);
        print { $self->{stdout_fh} } encode_json($result) . "\n";
        return 0;
    };
    if ( my $error = $@ ) {
        chomp $error;
        print { $self->{stderr_fh} } "$error\n";
        return 2;
    }
    return $code;
}

sub execute_login {
    my ( $self, @argv ) = @_;
    die "Usage: dashboard cloudflare.login\n" if @argv;
    my $tunnel_dir = $self->ensure_tunnel_dir;
    my @cmd = $self->docker_command( 'tunnel', 'login' );
    $self->run_system(@cmd);
    return {
        mode       => 'login',
        tunnel_dir => $tunnel_dir,
        env_file   => $self->project_env_file,
        command    => \@cmd,
    };
}

sub execute_create {
    my ( $self, @argv ) = @_;
    die "Usage: dashboard cloudflare.create <DOMAIN_ID>\n" if @argv > 1;
    my $state = $self->read_env_state;
    my $domain_id = $self->resolve_domain_id( $argv[0], $state->{map} );
    $self->ensure_tunnel_dir;
    $self->write_env_values(
        $state,
        {
            CLOUDFLARE_DOMAIN_ID => $domain_id,
            DOMAIN_ID            => $domain_id,
        }
    );
    my @cmd = $self->docker_command( 'tunnel', 'create', $domain_id );
    $self->run_system(@cmd);
    return {
        mode       => 'create',
        domain_id  => $domain_id,
        tunnel_dir => $self->tunnel_dir,
        env_file   => $self->project_env_file,
        command    => \@cmd,
    };
}

sub execute_uuid {
    my ( $self, @argv ) = @_;
    die "Usage: dashboard cloudflare.uuid <UUID> <DOMAIN_ID> [WEB_CONTAINER] [WEB_CONTAINER_PORT]\n"
      if !@argv || @argv > 4;

    my $uuid = shift @argv;
    die "UUID is required\n" if !defined $uuid || $uuid eq q{};

    my $state = $self->read_env_state;
    my $domain_id = $self->resolve_domain_id( shift @argv, $state->{map} );
    my $web_container = $self->resolve_web_container( shift @argv, $state->{map} );
    my $web_port      = $self->resolve_web_port( shift @argv, $state->{map} );

    $self->ensure_tunnel_dir;
    $self->write_env_values(
        $state,
        {
            UUID                 => $uuid,
            CLOUDFLARE_DOMAIN_ID => $domain_id,
            DOMAIN_ID            => $domain_id,
            WEB_CONTAINER        => $web_container,
            WEB_CONTAINER_PORT   => $web_port,
        }
    );
    my $config_path = $self->write_tunnel_config( $uuid, $web_container, $web_port );

    return {
        mode               => 'uuid',
        uuid               => $uuid,
        domain_id          => $domain_id,
        web_container      => $web_container,
        web_container_port => $web_port,
        config_file        => $config_path,
        env_file           => $self->project_env_file,
    };
}

sub execute_dns {
    my ( $self, @argv ) = @_;
    die "Usage: dashboard cloudflare.dns <DOMAIN_ID> <DOMAIN_NAME>\n" if @argv > 2;
    my $state = $self->read_env_state;
    my $domain_id = $self->resolve_domain_id( shift @argv, $state->{map} );
    my $domain_name = $self->resolve_domain_name( shift @argv, $state->{map} );

    $self->ensure_tunnel_dir;
    $self->write_env_values(
        $state,
        {
            CLOUDFLARE_DOMAIN_ID   => $domain_id,
            DOMAIN_ID              => $domain_id,
            CLOUDFLARE_DOMAIN_NAME => $domain_name,
            DOMAIN_NAME            => $domain_name,
        }
    );
    my @cmd = $self->docker_command( 'tunnel', 'route', 'dns', $domain_id, $domain_name );
    $self->run_system(@cmd);
    return {
        mode        => 'dns',
        domain_id   => $domain_id,
        domain_name => $domain_name,
        tunnel_dir  => $self->tunnel_dir,
        env_file    => $self->project_env_file,
        command     => \@cmd,
    };
}

sub project_env_file {
    my ($self) = @_;
    return File::Spec->catfile( $self->{cwd}, '.env' );
}

sub tunnel_dir {
    my ($self) = @_;
    return File::Spec->catdir( $self->{cwd}, 'tunnel' );
}

sub tunnel_config_file {
    my ($self) = @_;
    return File::Spec->catfile( $self->tunnel_dir, 'config.yml' );
}

sub ensure_tunnel_dir {
    my ($self) = @_;
    my $dir = $self->tunnel_dir;
    make_path($dir) if !-d $dir;
    return $dir;
}

sub docker_volume_spec {
    my ($self) = @_;
    return $self->tunnel_dir . ':/root/.cloudflared';
}

sub docker_command {
    my ( $self, @subcommand ) = @_;
    return (
        'docker', 'run', '-u', 'root', '--rm', '-it',
        '-v', $self->docker_volume_spec,
        'cloudflare/cloudflared:latest',
        @subcommand,
    );
}

sub run_system {
    my ( $self, @cmd ) = @_;
    my $rc = $self->{system_runner}->(@cmd);
    die "Command failed with exit code $rc: @cmd\n" if $rc != 0;
    return 1;
}

sub read_env_state {
    my ($self) = @_;
    my $file = $self->project_env_file;
    my @lines;
    my %map;

    if ( -f $file ) {
        open my $fh, '<', $file or die "Unable to read $file: $!";
        while ( my $line = <$fh> ) {
            chomp $line;
            if ( $line =~ /^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$/ ) {
                my ( $key, $value ) = ( $1, $2 );
                $map{$key} = $value;
                push @lines, { key => $key, raw => $line };
                next;
            }
            push @lines, { raw => $line };
        }
        close $fh or die "Unable to close $file: $!";
    }

    return {
        file  => $file,
        map   => \%map,
        lines => \@lines,
    };
}

sub write_env_values {
    my ( $self, $state, $updates ) = @_;
    my %pending = %{$updates};
    my @out;

    for my $line ( @{ $state->{lines} } ) {
        if ( $line->{key} && exists $pending{ $line->{key} } ) {
            my $value = delete $pending{ $line->{key} };
            push @out, $line->{key} . '=' . $value;
            $state->{map}{ $line->{key} } = $value;
            next;
        }
        push @out, $line->{raw};
    }

    for my $key ( sort keys %pending ) {
        push @out, $key . '=' . $pending{$key};
        $state->{map}{$key} = $pending{$key};
    }

    open my $fh, '>', $state->{file} or die "Unable to write $state->{file}: $!";
    print {$fh} join( "\n", @out ), "\n";
    close $fh or die "Unable to close $state->{file}: $!";
    $state->{lines} = [
        map {
            my $raw = $_;
            $raw =~ /^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$/
              ? { key => $1, raw => $raw }
              : { raw => $raw }
        } @out
    ];
    return $state->{file};
}

sub resolve_domain_id {
    my ( $self, $arg, $env ) = @_;
    return $arg if defined $arg && $arg ne q{};
    return $env->{CLOUDFLARE_DOMAIN_ID} if defined $env->{CLOUDFLARE_DOMAIN_ID} && $env->{CLOUDFLARE_DOMAIN_ID} ne q{};
    return $env->{DOMAIN_ID} if defined $env->{DOMAIN_ID} && $env->{DOMAIN_ID} ne q{};
    die "DOMAIN_ID is required. Pass it explicitly or set CLOUDFLARE_DOMAIN_ID in .env\n";
}

sub resolve_domain_name {
    my ( $self, $arg, $env ) = @_;
    return $arg if defined $arg && $arg ne q{};
    return $env->{CLOUDFLARE_DOMAIN_NAME} if defined $env->{CLOUDFLARE_DOMAIN_NAME} && $env->{CLOUDFLARE_DOMAIN_NAME} ne q{};
    return $env->{DOMAIN_NAME} if defined $env->{DOMAIN_NAME} && $env->{DOMAIN_NAME} ne q{};
    die "DOMAIN_NAME is required. Pass it explicitly or set CLOUDFLARE_DOMAIN_NAME in .env\n";
}

sub resolve_web_container {
    my ( $self, $arg, $env ) = @_;
    return $arg if defined $arg && $arg ne q{};
    return $env->{WEB_CONTAINER} if defined $env->{WEB_CONTAINER} && $env->{WEB_CONTAINER} ne q{};
    return 'web';
}

sub resolve_web_port {
    my ( $self, $arg, $env ) = @_;
    return $arg if defined $arg && $arg ne q{};
    return $env->{WEB_CONTAINER_PORT} if defined $env->{WEB_CONTAINER_PORT} && $env->{WEB_CONTAINER_PORT} ne q{};
    return 80;
}

sub write_tunnel_config {
    my ( $self, $uuid, $web_container, $web_port ) = @_;
    my $file = $self->tunnel_config_file;
    open my $fh, '>', $file or die "Unable to write $file: $!";
    print {$fh} "tunnel: $uuid\n";
    print {$fh} "url: http://$web_container:$web_port\n";
    print {$fh} "credentials-file: /var/cloudflared/$uuid.json\n";
    print {$fh} "protocol: quic\n";
    print {$fh} "warp-routing:\n";
    print {$fh} "  enabled: true\n";
    print {$fh} "logfile: /var/log/cloudflared.log\n";
    print {$fh} "loglevel: debug\n";
    print {$fh} "transport-loglevel: info\n";
    close $fh or die "Unable to close $file: $!";
    return $file;
}

1;
