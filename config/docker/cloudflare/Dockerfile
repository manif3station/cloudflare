FROM perl:5.38 AS builder

RUN cpan App::cpanminus \
 && cpanm --notest PAR::Packer

WORKDIR /build

COPY startup.pl /build/startup.pl

RUN pp -o /build/startup /build/startup.pl \
 && mkdir -p /build/runtime-libs/usr/lib/x86_64-linux-gnu \
 && cp /usr/lib/x86_64-linux-gnu/libcrypt.so.1 /build/runtime-libs/usr/lib/x86_64-linux-gnu/libcrypt.so.1 \
 && cp /usr/lib/x86_64-linux-gnu/libcrypt.so.1.1.0 /build/runtime-libs/usr/lib/x86_64-linux-gnu/libcrypt.so.1.1.0

FROM cloudflare/cloudflared:latest

COPY --from=builder /build/runtime-libs/ /
COPY --from=builder --chmod=755 /build/startup /opt/startup
