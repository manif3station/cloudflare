# cloudflare overview

`cloudflare` is a Developer Dashboard skill for project-local Cloudflare Tunnel setup.

It focuses on four command paths:

- `dashboard cloudflare.login`
- `dashboard cloudflare.create`
- `dashboard cloudflare.uuid`
- `dashboard cloudflare.dns`

The implementation keeps its state inside the target project:

- `./.env` stores `UUID`, `CLOUDFLARE_DOMAIN_ID`, `DOMAIN_ID`, `WEB_CONTAINER`, `WEB_CONTAINER_PORT`, and `CLOUDFLARE_DOMAIN_NAME` when those values are known
- `./tunnel/` stores the login credentials, generated `config.yml`, and the credential JSON created by Cloudflare

The skill ships a compose runtime definition at:

```text
~/projects/skills/skills/cloudflare/config/docker/cloudflare/compose.yml
```

The compose service uses a project-local `./tunnel:/var/cloudflared` mount, exposes `UUID` in the container environment, mounts a shipped startup wrapper to `/opt/startup`, copies the runtime assets into `/etc/cloudflared`, and then runs `cloudflared` with `--config /etc/cloudflared/config.yml`.

The compose command reads `${CLOUDFLARE_DOMAIN_ID}` directly from the project `.env`.
