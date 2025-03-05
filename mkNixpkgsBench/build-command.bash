# shellcheck shell=bash

set -euo pipefail

preBench() {
  export NIX_PAGER=
  return 0
}

preRun() {
  # shellcheck disable=SC2154
  for dir in "${nixDirs[@]}"; do
    export "$dir"="$(mktemp -d)"
  done
  export NIX_STORE="$NIX_STORE_DIR"
  nix-store --init
  return 0
}

runPhase() {
  runHook preRun

  # shellcheck disable=SC2154
  NIX_SHOW_STATS_PATH="eval.json" \
    command time \
    --format="$(<"${timeFormatJson:?}")" \
    --output="time.json" \
    nix eval \
    "${nixEvalArgs[@]}" \
    --file "${evalFilePath:?}" \
    "${evalAttrPath:?}" \
    >/dev/null

  # Join the time and eval JSON files, nesting them under their respective keys, and append the result to the
  # eval JSON file.
  # NOTE: runNum is brought into scope by the for loop in benchPhase.
  jq \
    --null-input \
    --sort-keys \
    --argjson runNum "${runNum:?}" \
    --slurpfile time "time.json" \
    --slurpfile eval "eval.json" \
    --slurpfile info "${benchConfigJson:?}" \
    '{
      $runNum,
      info: $info[0],
      time: $time[0],
      eval: $eval[0]
    }' >>runs.json

  runHook postRun
}

postRun() {
  for dir in "${nixDirs[@]}"; do
    rm -rf "${!dir}"
  done
  return 0
}

postBench() {
  jq --sort-keys --slurp <"runs.json" >"${out:?}"
  return 0
}

benchPhase() {
  runHook preBench
  local -i runNum
  for runNum in $(seq 1 "${numRuns:?}"); do
    nixLog "beginning run $runNum of $numRuns"
    runHook runPhase
  done
  unset runNum
  runHook postBench
}

runHook benchPhase
