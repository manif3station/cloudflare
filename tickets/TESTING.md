# cloudflare testing

## Docker Commands

Functional pass:

```bash
docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc '
cd /workspace/skills/cloudflare
prove -lr t
'
```

Covered pass:

```bash
docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc '
cd /workspace/skills/cloudflare
cover -delete
HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lr t
cover -report text
'
```

## Result

- Docker functional suite passed
- Docker covered suite passed
- `lib/Cloudflare/Manager.pm` reached `100.0%` statement coverage
- `lib/Cloudflare/Manager.pm` reached `100.0%` subroutine coverage
- tests cover login tunnel-dir creation, create command env persistence, env fallback resolution, uuid config generation, dns route command generation, wrapper JSON output, wrapper usage failures, compose shipping, and MIT license docs
- latest covered result:

```text
Files=4, Tests=63
lib/Cloudflare/Manager.pm  100.0  79.3  61.2  100.0
```

## Cleanup

- `cover_db` must be removed from the skill folder before release
