# EPIC-270 Add A Guided Cloudflare Tunnel Setup Skill

## Goal

Package the Cloudflare Tunnel project bootstrap into a governed `cloudflare` skill so Developer Dashboard users can prepare login, tunnel creation, UUID config, DNS routing, and container runtime setup without rebuilding the workflow by hand in each project.

## Scope

- add `dashboard cloudflare.login`
- add `dashboard cloudflare.create`
- add `dashboard cloudflare.uuid`
- add `dashboard cloudflare.dns`
- ship `config/docker/cloudflare/compose.yml`
- persist project-local Cloudflare values in `./.env`
- generate `./tunnel/config.yml`
- document and Docker-test the workflow
