#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

java_home_satisfies_gradle() {
  local candidate="$1"
  [[ -n "$candidate" && -x "$candidate/bin/javac" ]] || return 1

  local major
  major="$($candidate/bin/javac -version 2>&1 | sed -E 's/^javac ([0-9]+).*/\1/')"
  [[ "$major" =~ ^[0-9]+$ && "$major" -ge 17 ]]
}

select_java_home() {
  if java_home_satisfies_gradle "${JAVA_HOME:-}"; then
    printf '%s\n' "$JAVA_HOME"
    return 0
  fi

  local candidate
  for candidate in \
    /usr/lib/jvm/java-17-openjdk-amd64 \
    /usr/lib/jvm/java-21-openjdk-amd64
  do
    if java_home_satisfies_gradle "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf 'Could not find a JDK 17+ installation for Gradle.\n' >&2
  return 1
}

export JAVA_HOME="$(select_java_home)"
export PATH="$JAVA_HOME/bin:$PATH"
printf 'Using JAVA_HOME=%s\n' "$JAVA_HOME"

if "$repo_root/scripts/rag_engine_cache.sh" restore; then
  printf 'Using cached RAG engine artifacts.\n'
else
  printf 'No complete RAG engine cache found; Flutter may need to build Rust artifacts.\n' >&2
fi

flutter build apk --release --target-platform android-arm64
"$repo_root/scripts/rag_engine_cache.sh" save
