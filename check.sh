#!/bin/bash

for i in common/*; do
  if ! docker run --rm -v "./:/app" koalaman/shellcheck:stable "/app/$i"; then
    exit 1
  fi
done;

for i in $(find docker -type f); do
  if ! docker run --rm -v "./:/app" hadolint/hadolint hadolint "/app/$i"; then
    exit 1
  fi
done