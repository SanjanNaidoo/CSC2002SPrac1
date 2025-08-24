#!/usr/bin/env bash
set -euo pipefail

J=java
SER="DungeonHunter"

GRID="${GRID:-200}"
RHO0="${RHO0:-0.02}"
RHO_MAX="${RHO_MAX:-0.64}"
EPS="${EPS:-0.005}"
MAX_IMPROVE_FRAC="${MAX_IMPROVE_FRAC:-0.10}"

DEFAULT_SEEDS=(1 2 3 4 5 6 7 8 9 10)
if [[ "${SEEDS:-}" != "" ]]; then
  # shellcheck disable=SC2206
  SEEDS=(${SEEDS})
else
  SEEDS=("${DEFAULT_SEEDS[@]}")
fi

best_mana() {  # args: rho seed
  local rho="$1" seed="$2" out mana
  echo "RUN: $J -cp bin $SER $GRID $rho $seed" >&2
  out="$($J -cp bin "$SER" "$GRID" "$rho" "$seed")"
  mana="$(printf '%s\n' "$out" | sed -n 's/.*mana \([0-9][0-9]*\).*/\1/p' | tail -n1)"
  if [[ -z "$mana" ]]; then
    echo "Error: failed to parse mana (grid=$GRID rho=$rho seed=$seed). Full output follows:" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  printf '%s' "$mana"
}

# float compare using C locale
le() { LC_NUMERIC=C awk -v a="$1" -v b="$2" 'BEGIN{exit !(a <= b)}'; }

rho="$RHO0"
while le "$rho" "$RHO_MAX"; do
  rho2="$(LC_NUMERIC=C awk -v r="$rho" 'BEGIN{printf "%.6f", r*2}')"
  improved=0; total=0

  for seed in "${SEEDS[@]}"; do
    m1="$(best_mana "$rho"  "$seed")"
    m2="$(best_mana "$rho2" "$seed")"
    inc="$(LC_NUMERIC=C awk -v m1="$m1" -v m2="$m2" 'BEGIN{print (m2-m1)/m1}')"
    LC_NUMERIC=C awk -v inc="$inc" -v eps="$EPS" 'BEGIN{exit !(inc > eps)}' && improved=$((improved+1))
    total=$((total+1))
  done

  frac="$(LC_NUMERIC=C awk -v i="$improved" -v t="$total" 'BEGIN{printf "%.3f", i/t}')"
  echo "rho=$rho -> 2rho=$rho2 : improved in $improved/$total seeds (=$frac)"

  LC_NUMERIC=C awk -v f="$frac" -v thr="$MAX_IMPROVE_FRAC" 'BEGIN{exit !(f <= thr)}' && {
    echo "Chosen optimum density: $rho"
    exit 0
  }

  rho="$rho2"
done

echo "Hit RHO_MAX=$RHO_MAX; choose last rho=$rho"
