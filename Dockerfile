
FROM python:3.9-alpine

WORKDIR /bumpversion

COPY bump_version.sh bump_version.sh

RUN apk add --no-cache \
    bash \
    grep \
    git && \
    pip --no-cache-dir install bump2version==v1.0.1

ENTRYPOINT ["/bin/bash", "./bump_version.sh"]
