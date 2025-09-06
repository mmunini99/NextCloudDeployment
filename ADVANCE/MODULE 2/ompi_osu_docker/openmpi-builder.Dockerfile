FROM debian:bullseye as builder

RUN apt update \
    && apt install -y --no-install-recommends \
        g++ \
        libopenmpi-dev \
        make \
    && rm -rf /var/lib/apt/lists/*