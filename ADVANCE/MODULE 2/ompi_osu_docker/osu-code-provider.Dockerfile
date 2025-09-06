FROM debian:bullseye as osu_code_provider

RUN apt update \
    && apt install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /code \
    && curl -o /code/osu-micro-benchmarks-7.3.tar.gz https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-7.3.tar.gz --insecure \
    && tar -xvf /code/osu-micro-benchmarks-7.3.tar.gz -C /code \
    && rm -rf /var/lib/apt/lists/*