#!/usr/bin/env bash
# Fills the comparison table (step 3 and 5). Run from the repo root.
measure() {
  local file=$1 tag=$2
  echo "=== $tag ==="
  echo "-- cold build"
  ( time docker build --no-cache -f "$file" -t "$tag" . >/dev/null ) 2>&1 | grep real
  echo "-- warm build (after touching train.py)"
  echo "# touched $(date +%s)" >> train.py
  ( time docker build -f "$file" -t "$tag" . >/dev/null ) 2>&1 | grep real
  sed -i '$ d' train.py
  echo "-- size"
  docker images "$tag" --format "{{.Size}}"
  echo "-- layers"
  docker history "$tag" --format "{{.ID}}" | wc -l
}
measure Dockerfile.train iris-train:naive
measure Dockerfile.train.opt iris-train:opt
