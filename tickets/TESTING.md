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
- Docker image build passed for `config/docker/cloudflare/Dockerfile`
- Docker startup runtime smoke check passed for the built image
- remote `dashboard docker compose` proof passed against a real project using the installed skill path
- `lib/Cloudflare/Manager.pm` reached `100.0%` statement coverage
- `lib/Cloudflare/Manager.pm` reached `100.0%` subroutine coverage
- tests cover login tunnel-dir creation, create command env persistence, env fallback resolution, uuid config generation, dns route command generation, wrapper JSON output, wrapper usage failures, compose shipping, `cloudflare_DDDC/cloudflare` build context resolution, linux/amd64 platform pinning, multi-stage Dockerfile shipping, Perl startup source shipping, root runtime handoff into `/etc/cloudflared`, runtime glibc-compatible builder selection, MIT license docs, and `.env` version alignment with `Changes`
- latest covered result:

```text
Files=5, Tests=89
lib/Cloudflare/Manager.pm  100.0  79.3  61.2  100.0
```

## Cleanup

- `cover_db` must be removed from the skill folder before release

## Extra Runtime Gate

Real-image startup smoke check:

```bash
docker build -t cloudflare-skill-startup-smoke ~/projects/skills/skills/cloudflare/config/docker/cloudflare
tmpdir=$(mktemp -d)
touch "$tmpdir/test.json" "$tmpdir/cert.pem" "$tmpdir/config.yml"
docker run --rm \
  --user root \
  -e UUID=test \
  -v "$tmpdir:/var/cloudflared" \
  --entrypoint /opt/startup \
  cloudflare-skill-startup-smoke \
  --version
rm -rf "$tmpdir"
```

Remote compose proof:

```bash
ssh <remote-host> '
cd ~/path/to/project &&
export cloudflare_DDDC=~/.developer-dashboard/skills/cloudflare/config/docker/cloudflare &&
dashboard docker compose config &&
dashboard docker compose run --rm cloudflare --version &&
dashboard docker compose up -d cloudflare
'
```
