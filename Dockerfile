FROM debian:buster-slim as builder

ARG BAZEL_VERSION=5.3.1

RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        git-lfs \
        openjdk-11-jdk \
        python \
        unzip \
        wget \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN set -ex \
    && wget -qO /usr/local/bin/bazel https://github.com/Loongson-Cloud-Community/bazel/releases/download/${BAZEL_VERSION}/bazel_nojdk-${BAZEL_VERSION}-linux-loongarch64 \
    && chmod +x /usr/local/bin/bazel \
    && bazel --version

ARG WORKDIR=/opt/platforms
ARG PLATFORMS_VERSION=0.0.6

RUN set -ex \
    && git clone -b ${PLATFORMS_VERSION} --depth=1 https://github.com/bazelbuild/platforms ${WORKDIR}

ADD 0.0.4.patch /opt/BUILD.patch

WORKDIR ${WORKDIR}

RUN set -ex \
    && git apply /opt/BUILD.patch \
    && bazel build //:all \
    && \
    if [ -f "distro/makerel.sh" ]; then \
        ./distro/makerel.sh ${PLATFORMS_VERSION}; \
    else \
        dist_file="/tmp/platforms-${PLATFORMS_VERSION}.tar.gz"; \
        tar czf "$dist_file" BUILD LICENSE WORKSPACE cpu os; \
    fi \
    && mkdir -p /opt/dist \
    && cp -f /tmp/platforms-${PLATFORMS_VERSION}.tar.gz /opt/dist \
    && echo $(shasum -a 256 /opt/dist/platforms-${PLATFORMS_VERSION}.tar.gz | cut -d' ' -f1) > /opt/dist/CHECKSUM

FROM debian:buster-slim

WORKDIR /opt/platform

COPY --from=builder /opt/dist /opt/platform/dist

VOLUME /dist

CMD cp -rf dist/* /dist/