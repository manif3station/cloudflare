# cloudflare

## Description

`cloudflare` is a Developer Dashboard skill that bootstraps a project-local Cloudflare Tunnel workflow.

## Value

It gives a project a repeatable path for Cloudflare login, tunnel creation, tunnel config generation, DNS routing, and a Docker Compose service that can be started through Developer Dashboard.

## Problem It Solves

Cloudflare Tunnel setup usually gets spread across ad hoc terminal commands, half-written `.env` files, and container config that drifts from one project to the next. That makes it easy to lose the tunnel id, route DNS with the wrong hostname, or start `cloudflared` with mismatched config paths.

## What It Does To Solve It

The skill adds four CLI commands that operate on the current project:

- `dashboard cloudflare.login`
- `dashboard cloudflare.create`
- `dashboard cloudflare.uuid`
- `dashboard cloudflare.dns`

The commands create and reuse a project-local `./tunnel/` folder, update the current project's `.env`, and write `./tunnel/config.yml` with the selected tunnel UUID and web target.

The skill also ships:

```text
~/projects/skills/skills/cloudflare/config/docker/cloudflare/compose.yml
```

That compose file is intended to be used as the Cloudflare service definition behind:

```bash
dashboard docker up -d cloudflare
```

The shipped runtime now stages the project-local tunnel assets from `/var/cloudflared` into `/etc/cloudflared` through a startup wrapper at `/opt/startup`, then starts `cloudflared --no-autoupdate --post-quantum tunnel run ${CLOUDFLARE_DOMAIN_ID}`.

## Developer Dashboard Feature Added

This skill adds:

- `dashboard cloudflare.login`
- `dashboard cloudflare.create`
- `dashboard cloudflare.uuid`
- `dashboard cloudflare.dns`
- a reusable compose service definition for `cloudflare`

## Installation

Install through Developer Dashboard:

```bash
dashboard skills install ~/projects/skills/skills/cloudflare
```

If your local DD wrapper exposes the singular alias, the same skill can also be installed through:

```bash
dashboard skill install cloudflare
```

## CLI Usage

Login to Cloudflare and create the local tunnel credential directory when needed:

```bash
dashboard cloudflare.login
```

Create a tunnel using an explicit id or name:

```bash
dashboard cloudflare.create demo-tunnel
```

The command also accepts a project `.env` fallback:

```dotenv
CLOUDFLARE_DOMAIN_ID=demo-tunnel
```

Generate the tunnel config and persist the UUID plus target web container:

```bash
dashboard cloudflare.uuid 11111111-2222-3333-4444-555555555555 demo-tunnel web 80
```

When `WEB_CONTAINER` or `WEB_CONTAINER_PORT` are already present in the project `.env`, they can be omitted from the command and default to `web` and `80`.

Add the DNS route:

```bash
dashboard cloudflare.dns demo-tunnel app.example.com
```

The DNS command also accepts these `.env` fallbacks:

```dotenv
CLOUDFLARE_DOMAIN_ID=demo-tunnel
CLOUDFLARE_DOMAIN_NAME=app.example.com
```

## Normal Example

From a project root:

```bash
dashboard cloudflare.login
dashboard cloudflare.create demo-tunnel
dashboard cloudflare.uuid 11111111-2222-3333-4444-555555555555 demo-tunnel web 80
dashboard cloudflare.dns demo-tunnel app.example.com
dashboard docker up -d cloudflare
```

Resulting project files:

- `./tunnel/config.yml`
- `./tunnel/11111111-2222-3333-4444-555555555555.json` after the Cloudflare create/login flow populates credentials
- `./.env` with `UUID`, `CLOUDFLARE_DOMAIN_ID`, `DOMAIN_ID`, `WEB_CONTAINER`, `WEB_CONTAINER_PORT`, and `CLOUDFLARE_DOMAIN_NAME`

The shipped compose runtime also expects:

- `${cloudflare_DDDC}/startup` to be available and mounted to `/opt/startup`
- `./tunnel/cert.pem` to exist before the `cloudflare` service starts

## Edge Cases

If `dashboard cloudflare.create` is run with no argument and the project `.env` does not contain `CLOUDFLARE_DOMAIN_ID` or `DOMAIN_ID`, the command fails with a clear error instead of inventing a tunnel identifier.

The shipped compose service now reads `CLOUDFLARE_DOMAIN_ID` directly.

If `dashboard cloudflare.uuid` is run without a `UUID`, the command fails before writing `./tunnel/config.yml`.

If `dashboard cloudflare.dns` is run without a hostname argument and without `CLOUDFLARE_DOMAIN_NAME` or `DOMAIN_NAME` in `.env`, the command fails before calling Docker.

## Browser Usage

This skill does not add a browser interface.

## License

`cloudflare` is released under the MIT License.

See [LICENSE](LICENSE).
