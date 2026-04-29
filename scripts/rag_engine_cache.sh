#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s save|restore|status\n' "${0##*/}"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

command="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${RAG_ENGINE_FLUTTER_VERSION:-0.17.0}"
cache_root="${RAG_ENGINE_CACHE_DIR:-$repo_root/.rag-engine-cache/android/rag_engine_flutter-$version/release-vector_faer-vector_quant_i8}"
target_root="${RAG_ENGINE_TARGET_DIR:-$repo_root/build/rag_engine_flutter/build}"
targets=(
  release
  armv7-linux-androideabi
  aarch64-linux-android
  x86_64-linux-android
)

save_cache() {
  mkdir -p "$cache_root"
  for target in "${targets[@]}"; do
    if [[ ! -d "$target_root/$target" ]]; then
      printf 'Skipping missing target directory: %s\n' "$target_root/$target" >&2
      continue
    fi
    printf 'Saving %s...\n' "$target"
    tar -C "$target_root" -czf "$cache_root/$target.tar.gz" "$target"
  done
  printf 'RAG engine cache saved to %s\n' "$cache_root"
}

restore_cache() {
  mkdir -p "$target_root"
  local restored=0
  for target in "${targets[@]}"; do
    local archive="$cache_root/$target.tar.gz"
    if [[ ! -f "$archive" ]]; then
      printf 'Missing cache archive: %s\n' "$archive" >&2
      continue
    fi
    printf 'Restoring %s...\n' "$target"
    tar -C "$target_root" -xzf "$archive"
    restored=1
  done

  if [[ "$restored" -eq 0 ]]; then
    printf 'No RAG engine cache archives found in %s\n' "$cache_root" >&2
    return 1
  fi
  printf 'RAG engine cache restored into %s\n' "$target_root"
}

status_cache() {
  printf 'Cache: %s\n' "$cache_root"
  printf 'Target: %s\n' "$target_root"
  for target in "${targets[@]}"; do
    if [[ -f "$cache_root/$target.tar.gz" ]]; then
      printf 'cached:  %s\n' "$target"
    else
      printf 'missing: %s\n' "$target"
    fi
  done
}

case "$command" in
  save)
    save_cache
    ;;
  restore)
    restore_cache
    ;;
  status)
    status_cache
    ;;
  *)
    usage
    exit 2
    ;;
esac
