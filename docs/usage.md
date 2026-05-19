# cloudflare usage

## Installation

```bash
dashboard skills install ~/projects/skills/skills/cloudflare
```

## Login

```bash
dashboard cloudflare.login
```

This creates `./tunnel/` when missing and runs:

```bash
docker run -u root --rm -it -v "$PWD/tunnel:/root/.cloudflared" cloudflare/cloudflared:latest tunnel login
```

## Create

```bash
dashboard cloudflare.create demo-tunnel
```

Or use the project `.env`:

```dotenv
CLOUDFLARE_DOMAIN_ID=demo-tunnel
```

The command persists both `CLOUDFLARE_DOMAIN_ID` and `DOMAIN_ID` in the project `.env`.

The shipped compose runtime reads `CLOUDFLARE_DOMAIN_ID`.

## UUID

```bash
dashboard cloudflare.uuid 11111111-2222-3333-4444-555555555555 demo-tunnel web 80
```

Defaults:

- `WEB_CONTAINER=web` when not set
- `WEB_CONTAINER_PORT=80` when not set

Generated `./tunnel/config.yml`:

```yaml
tunnel: 11111111-2222-3333-4444-555555555555
url: http://web:80
credentials-file: /var/cloudflared/11111111-2222-3333-4444-555555555555.json
protocol: quic
warp-routing:
  enabled: true
logfile: /var/log/cloudflared.log
loglevel: debug
transport-loglevel: info
```

## DNS

```bash
dashboard cloudflare.dns demo-tunnel app.example.com
```

Or use the project `.env`:

```dotenv
CLOUDFLARE_DOMAIN_ID=demo-tunnel
CLOUDFLARE_DOMAIN_NAME=app.example.com
```

The command runs:

```bash
docker run -u root --rm -it -v "$PWD/tunnel:/root/.cloudflared" cloudflare/cloudflared:latest tunnel route dns demo-tunnel app.example.com
```

## Compose Runtime

After login, create, uuid, and dns are complete, start the service through Developer Dashboard:

```bash
dashboard docker up -d cloudflare
```

The compose config comes from:

```text
~/projects/skills/skills/cloudflare/config/docker/cloudflare/compose.yml
```
