#!/usr/bin/env bash
set -e
docker build -f Dockerfile.train -t iris-train:naive .
docker build -f Dockerfile.infer -t iris-infer:naive .
docker run --rm -v iris-models:/models iris-train:naive
docker run --rm -v iris-models:/models iris-infer:naive
