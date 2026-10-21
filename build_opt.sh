#!/usr/bin/env bash
set -e
docker build -f Dockerfile.train.opt -t iris-train:opt .
docker build -f Dockerfile.infer.opt -t iris-infer:opt .
docker run --rm -v iris-models-opt:/models iris-train:opt
docker run --rm -v iris-models-opt:/models:ro iris-infer:opt
