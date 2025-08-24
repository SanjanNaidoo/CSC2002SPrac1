#!/usr/bin/env bash
set -euo pipefail
LC_NUMERIC=C   # force dot decimals

J=java
SER=${SER:-DungeonHunter}
PAR=${PAR:-DungeonHunterPAR}

# Input ranges (override via env if you want)
GRIDS=(${GRIDS:-100 200 400})
FACTORS=(${FACTORS:-1 2 4 8 16})
RHO=${RHO:-0.08}
SEED=${SEED:-1}
RUNS=${RUNS:-5}

# Outputs
SER_CSV=${SER_CSV:-serial_times.csv}
SWEEP_CSV=${SWEEP_CSV:-cutoff_sweep.csv}
CHOSEN_TXT=${CHOSEN_TXT:-chosen_cutoff.txt}

# Helper: extract "time: X ms" number robustly from program output
get_ms() {
  # read stdin, print last matched number
  sed -n 's/.*time:[[:space:]]*\([0-9][0-9]*\)[[:space:]]*ms.*/\1/p' | tail -n1
}

median() { printf "%s\n" "$@" | sort -n | awk '{a[NR]=$1} END{if (NR>0) print a[(NR+1)/2];}'; }

echo "== Building serial baselines ==" >&2
echo "grid,Ts_ms" > "$SER_CSV"
SER_TS=()  # serial medians aligned with GRIDS

for g in "${GRIDS[@]}"; do
  # warmup
  $J -cp bin "$SER" "$g" "$RHO" "$SEED" >/dev/null
  ts=()
  for i in $(seq 1 "$RUNS"); do
    out="$($J -cp bin "$SER" "$g" "$RHO" "$SEED")"
    ms="$(printf '%s\n' "$out" | get_ms)"
    if [[ -z "$ms" ]]; then
      echo "ERROR: failed to parse serial time for grid=$g (run $i). Full output:" >&2
      printf '%s\n' "$out" >&2
      exit 1
    fi
    ts+=("$ms")
  done
  med="$(median "${ts[@]}")"
  SER_TS+=("$med")
  echo "$g,$med" >> "$SER_CSV"
  echo "  grid=$g Ts_med=${med}ms" >&2
done

echo "== Sweeping cutoff factors (k) ==" >&2
echo "k,grid,Ts_ms,Tp_ms,speedup" > "$SWEEP_CSV"

for k in "${FACTORS[@]}"; do
  for idx in "${!GRIDS[@]}"; do
    g="${GRIDS[$idx]}"; Ts="${SER_TS[$idx]}"

    # warmup
    $J -Ddh.cutoffFactor="$k" -cp bin "$PAR" "$g" "$RHO" "$SEED" >/dev/null

    tp=()
    for i in $(seq 1 "$RUNS"); do
      out="$($J -Ddh.cutoffFactor="$k" -cp bin "$PAR" "$g" "$RHO" "$SEED")"
      ms="$(printf '%s\n' "$out" | get_ms)"
      if [[ -z "$ms" ]]; then
        echo "ERROR: failed to parse parallel time for k=$k grid=$g (run $i). Full output:" >&2
        printf '%s\n' "$out" >&2
        exit 1
      fi
      tp+=("$ms")
    done
    medP="$(median "${tp[@]}")"
    sp="$(awk -v s="$Ts" -v p="$medP" 'BEGIN{print (p>0)? s/p : 0}')"
    echo "$k,$g,$Ts,$medP,$sp" >> "$SWEEP_CSV"
    echo "  k=$k grid=$g Tp_med=${medP}ms speedup=$sp" >&2
  done
done

# Pick best k: highest average speedup across grids; tie -> smaller k
BEST_LINE="$(awk -F, 'NR>1{sum[$1]+=$5; cnt[$1]++}
  END{
    bestk=-1; bestavg=-1;
    for (k in sum) {
      avg=sum[k]/cnt[k];
      if (avg>bestavg || (avg==bestavg && (bestk<0 || k+0<bestk+0))) {bestavg=avg; bestk=k;}
    }
    if (bestk>=0) {printf "%d %.6f\n", bestk, bestavg;}
  }' "$SWEEP_CSV")"

if [[ -z "$BEST_LINE" ]]; then
  echo "ERROR: could not compute best k from $SWEEP_CSV" >&2
  exit 1
fi

BEST_K="$(echo "$BEST_LINE" | awk '{print $1}')"
BEST_AVG="$(echo "$BEST_LINE" | awk '{print $2}')"
printf '%s\n' "$BEST_K" > "$CHOSEN_TXT"

echo "== Result ==" >&2
echo "Chosen cutoffFactor (k): $BEST_K   (avg speedup across grids = $(printf '%.3f' "$BEST_AVG"))" >&2
echo "Wrote: $SER_CSV, $SWEEP_CSV, $CHOSEN_TXT" >&2
