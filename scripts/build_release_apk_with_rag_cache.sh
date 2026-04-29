#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if "$repo_root/scripts/rag_engine_cache.sh" restore; then
  printf 'Using cached RAG engine artifacts.\n'
else
  printf 'No complete RAG engine cache found; Flutter may need to build Rust artifacts.\n' >&2
fi

flutter build apk --release
"$repo_root/scripts/rag_engine_cache.sh" save
