# syntax=docker/dockerfile:1.7

# dynamic config
ARG             BUILD_DATE
ARG             VCS_REF
ARG             VERSION
ARG             GO_VERSION=1.18.1
ARG             ALPINE_VERSION=3.15.1

# build
FROM            --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS builder
ARG             TARGETOS
ARG             TARGETARCH
ARG             TARGETVARIANT
RUN             apk add --no-cache git gcc musl-dev make
ENV             GO111MODULE=on
WORKDIR         /go/src/moul.io/grpcbin
COPY            go.* ./
RUN             go mod download
COPY            . ./
#RUN             make install
RUN             set -eux; \
                goarm="${TARGETVARIANT#v}"; \
                if [ "$TARGETARCH" != "arm" ]; then goarm=""; fi; \
                CGO_ENABLED=0 GOOS="$TARGETOS" GOARCH="$TARGETARCH" GOARM="$goarm" \
                  go build -o /go/bin/grpcbin -ldflags "-extldflags \"-static\"" -v

# minimalist runtime
FROM            --platform=$TARGETPLATFORM alpine:${ALPINE_VERSION}
LABEL           org.label-schema.build-date=$BUILD_DATE \
                org.label-schema.name="grpcbin" \
                org.label-schema.description="" \
                org.label-schema.url="https://moul.io/grpcbin/" \
                org.label-schema.vcs-ref=$VCS_REF \
                org.label-schema.vcs-url="https://github.com/moul/grpcbin" \
                org.label-schema.vendor="Manfred Touron" \
                org.label-schema.version=$VERSION \
                org.label-schema.schema-version="1.0" \
                org.label-schema.cmd="docker run -i -t --rm moul/grpcbin" \
                org.label-schema.help="docker exec -it $CONTAINER grpcbin --help"
RUN             apk update && apk add ca-certificates && rm -rf /var/cache/apk/*
COPY            --from=builder /go/bin/grpcbin /bin/grpcbin
COPY            --from=builder /go/src/moul.io/grpcbin/cert /root/cert
WORKDIR         /root
EXPOSE          9000 9001 80
ENTRYPOINT      ["/bin/grpcbin"]
