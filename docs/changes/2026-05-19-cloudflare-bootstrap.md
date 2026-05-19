# 2026-05-19 cloudflare bootstrap

- added the first governed `cloudflare` skill release
- added `dashboard cloudflare.login`, `dashboard cloudflare.create`, `dashboard cloudflare.uuid`, and `dashboard cloudflare.dns`
- added project `.env` persistence for tunnel id, UUID, web target, and DNS hostname values
- added `./tunnel/config.yml` generation with a mounted `/var/cloudflared` credentials path
- added the compose runtime definition at `config/docker/compose.yml`
- added Docker-tested Perl coverage for the command and file-generation paths
