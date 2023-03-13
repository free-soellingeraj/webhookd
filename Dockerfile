# FROM ncarlier/webhookd:latest

#########################################
# Build stage
#########################################
FROM golang:1.18 AS builder

# Repository location
ARG REPOSITORY=github.com/ncarlier

# Artifact name
ARG ARTIFACT=webhookd

# Copy sources into the container
ADD . /go/src/$REPOSITORY/$ARTIFACT

# Set working directory
WORKDIR /go/src/$REPOSITORY/$ARTIFACT

# Build the binary
RUN make

#########################################
# Distribution stage
#########################################
FROM 3.9-alpine:latest AS slim

# Repository location
ARG REPOSITORY=ncarlier

# Artifact name
ARG ARTIFACT=webhookd

# User
ARG USER=webhookd
ARG UID=1000

# Create non-root user
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "$(pwd)" \
    --no-create-home \
    --uid "$UID" \
    "$USER"

# Install deps
RUN apk add --no-cache bash gcompat

# Install binary
COPY --from=builder $ARTIFACT/release/$ARTIFACT /usr/local/bin/$ARTIFACT

VOLUME [ "/scripts" ]

EXPOSE 8080

USER $USER

CMD [ "webhookd" ]

#########################################
# Distribution stage with some tooling
#########################################
FROM alpinelinux/docker-cli:latest AS distrib

# Repository location
ARG REPOSITORY=github.com/ncarlier

# Artifact name
ARG ARTIFACT=webhookd

# User
ARG USER=webhookd
ARG UID=1000

# Create non-root user
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "$(pwd)" \
    --no-create-home \
    --uid "$UID" \
    "$USER"

# Install deps
RUN apk add --no-cache bash gcompat git openssh-client curl jq

# Install docker-compose
RUN curl -L --fail https://raw.githubusercontent.com/linuxserver/docker-docker-compose/master/run.sh \
     -o /usr/local/bin/docker-compose && \
     chmod +x /usr/local/bin/docker-compose

# Install binary and entrypoint
COPY --from=builder $ARTIFACT/release/$ARTIFACT /usr/local/bin/$ARTIFACT
COPY docker-entrypoint.sh /

# Define entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

VOLUME [ "/scripts" ]

EXPOSE 8080

USER $USER

## Specific implementation
COPY .htpasswd /
COPY . /shoebox-ml/
USER root
RUN apk upgrade && apk update
# ARG PYTHON_VERSION=3.9.15
RUN apk add make automake gcc g++ subversion wget zlib-dev libffi-dev openssl-dev musl-dev
# https://stackoverflow.com/a/73294721/7032846
# download and extract python sources
# RUN cd /opt \
#     && wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \                                              
#     && tar xzf Python-${PYTHON_VERSION}.tgz

# build python and remove left-over sources
# RUN cd /opt/Python-${PYTHON_VERSION} \ 
#     && ./configure --prefix=/usr --enable-optimizations --with-ensurepip=install \
#     && make install \
#     && rm /opt/Python-${PYTHON_VERSION}.tgz /opt/Python-${PYTHON_VERSION} -rf
RUN echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add --update --no-cache py3-numpy py3-pandas
USER $USER
# RUN python3 -m ensurepip
RUN python3 -m pip install "/shoebox-ml[corner]"

CMD [ "webhookd" ]
