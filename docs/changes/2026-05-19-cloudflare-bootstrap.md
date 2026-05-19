# 2026-05-19 cloudflare bootstrap

- added the first governed `cloudflare` skill release
- added `dashboard cloudflare.login`, `dashboard cloudflare.create`, `dashboard cloudflare.uuid`, and `dashboard cloudflare.dns`
- added project `.env` persistence for tunnel id, UUID, web target, and DNS hostname values
- added `./tunnel/config.yml` generation with a mounted `/var/cloudflared` credentials path
- moved the compose runtime definition to `config/docker/cloudflare/compose.yml`
- updated the compose runtime to read `${CLOUDFLARE_DOMAIN_ID}`
- added the shipped `/opt/startup` wrapper and `${UUID}` compose environment support
- switched the runtime config and credentials handoff to `/etc/cloudflared`
- updated the compose startup mount to `${cloudflare_DDDC}/startup`
- updated the compose command order to `--post-quantum tunnel run ${CLOUDFLARE_DOMAIN_ID}`
- replaced the mounted shell startup script with a Perl startup program compiled through a multi-stage Dockerfile
- added Docker-tested Perl coverage for the command and file-generation paths
