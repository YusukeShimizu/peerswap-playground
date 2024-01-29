FROM golang:1.19-alpine as builder

ARG PEERSWAP_VERSION=premium-feature

# Force Go to use the cgo based DNS resolver. This is required to ensure DNS
# queries required to connect to linked containers succeed.
ENV GODEBUG netdns=cgo

# Install dependencies and install/build lnd.
RUN apk add --no-cache --update alpine-sdk \
    git \
    make 

# Copy in the local repository to build from.
RUN git clone --quiet --depth 1 --single-branch \
    --branch $PEERSWAP_VERSION \
    https://github.com/YusukeShimizu/peerswap /go/src/github.com/YusukeShimizu/peerswap

RUN cd /go/src/github.com/YusukeShimizu/peerswap \
    &&  make bins

# Expose lnd ports (server, rpc).
EXPOSE 9735 10009

# Copy the binaries and entrypoint from the builder image.
RUN cp /go/src/github.com/YusukeShimizu/peerswap/out/peerswapd /bin/
RUN cp /go/src/github.com/YusukeShimizu/peerswap/out/pscli /bin/

RUN mkdir -p ~/.peerswap

# Add bash.
RUN apk add --no-cache \
    bash

ENTRYPOINT ["peerswapd"]
