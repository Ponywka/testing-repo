FROM golang:1.26-alpine3.22 AS go-builder

FROM go-builder AS build_sing-box
WORKDIR /src
COPY ./third-party/sing-box/ ./
RUN go mod download
RUN go build -v -trimpath -ldflags="-s -w -buildid=" -tags with_wireguard -o sing-box ./cmd/sing-box

FROM go-builder AS build_wgcf
WORKDIR /src
COPY ./third-party/wgcf/ ./
RUN go mod download
RUN go build -v -trimpath -ldflags="-s -w -buildid=" -o wgcf .

FROM alpine:3.22 AS release
COPY --from=build_sing-box /src/sing-box /usr/bin/sing-box
COPY --from=build_wgcf /src/wgcf /usr/bin/wgcf
COPY ./opt/ /opt/
VOLUME /app
WORKDIR /app
ENTRYPOINT [ "/opt/warpsock/docker-entrypoint.sh" ]
