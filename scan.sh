#!/usr/bin/env bash
mkdir -p reports
for t in naive opt; do
  trivy image --severity HIGH,CRITICAL -f json -o reports/trivy-$t.json iris-train:$t
  trivy image --severity HIGH,CRITICAL iris-train:$t | tee reports/trivy-$t.txt
done
