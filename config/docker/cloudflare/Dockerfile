FROM perl:5.38 AS builder

RUN cpan App::cpanminus \
 && cpanm --notest PAR::Packer

WORKDIR /build

COPY startup.pl /build/startup.pl

RUN pp -o /build/startup /build/startup.pl

FROM cloudflare/cloudflared:latest

COPY --from=builder --chmod=755 /build/startup /opt/startup
