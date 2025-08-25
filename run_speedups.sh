#!/usr/bin/env bash
# Collects median serial/parallel times and writes two CSVs:
#   - speedup_by_grid.csv      (ρ fixed, vary grid densely)
#   - speedup_by_density.csv   (grid fixed, vary ρ densely)
set -euo pipefail
export LC_ALL=C
export LC_NUMERIC=C

J=java
SER=${SER:-DungeonHunter}
PAR=${PAR:-DungeonHunterPAR}

# -------- Tunables (override via env on the command line) --------
RHO=${RHO:-0.08}                  # fixed density for grid sweep
SEED=${SEED:-1}                   # deterministic seed
RUNS=${RUNS:-5}                   # median of N runs

# Dense grid sweep
GRIDS_MIN=${GRIDS_MIN:-64}
GRIDS_MAX=${GRIDS_MAX:-512}
GRIDS_STEP=${GRIDS_STEP:-16}

# Dense density sweep
DENS_MIN=${DENS_MIN:-0.02}
DENS_MAX=${DENS_MAX:-0.50}
DENS_STEP=${DENS_STEP:-0.02}

# Problem size used for the density sweep (fixed grid)
GRID_FOR_DENSITY=${GRID_FOR_DENSITY:-200}

HOST=$(uname -n)

# -------- Helpers --------
# Extract "time: X ms" number robustly from program output
get_ms() { sed -n 's/.*time:[[:space:]]*\([0-9][0-9]*\)[[:space:]]*ms.*/\1/p' | tail -n1; }
median() { printf "%s\n" "$@" | sort -n | awk '{a[NR]=$1} END{if(NR>0)print a[(NR+1)/2]}'; }

gen_grids() {
  seq "${GRIDS_MIN}" "${GRIDS_STEP}" "${GRIDS_MAX}"
}

# Emits floating point values [DENS_MIN, DENS_MAX] step DENS_STEP
gen_densities() {
  awk -v a="${DENS_MIN}" -v b="${DENS_MAX}" -v s="${DENS_STEP}" '
    BEGIN{
      x=a; eps=1e-12;
      while (x <= b+eps) { printf "%.5f\n", x; x+=s; }
    }'
}

# -------- A) Speedup vs grid (ρ fixed) --------
echo "machine,grid,rho,seed,Ts_ms,Tp_ms,speedup" > speedup_by_grid.csv

# Warmups (JIT)
first_grid=$(gen_grids | head -n1)
$J -cp bin "$SER" "${first_grid}" "$RHO" "$SEED" >/dev/null || true
$J -cp bin "$PAR" "${first_grid}" "$RHO" "$SEED" >/dev/null || true

while read -r g; do
  [ -z "$g" ] && continue
  ts=(); tp=()

  for i in $(seq 1 "$RUNS"); do
    out="$($J -cp bin "$SER" "$g" "$RHO" "$SEED")"
    ms="$(printf '%s\n' "$out" | get_ms)"; ts+=("$ms")

    out="$($J -cp bin "$PAR" "$g" "$RHO" "$SEED")"
    ms="$(printf '%s\n' "$out" | get_ms)"; tp+=("$ms")
  done

  msS="$(median "${ts[@]}")"
  msP="$(median "${tp[@]}")"
  sp="$(awk -v s="$msS" -v p="$msP" 'BEGIN{printf "%.6f", (p>0)? s/p : 0}')"
  printf "%s,%s,%s,%s,%s,%s,%s\n" "$HOST" "$g" "$RHO" "$SEED" "$msS" "$msP" "$sp" >> speedup_by_grid.csv
done < <(gen_grids)

# -------- B) Speedup vs density (grid fixed) --------
echo "machine,grid,rho,seed,Ts_ms,Tp_ms,speedup" > speedup_by_density.csv

# Warmups
first_rho=$(gen_densities | head -n1)
$J -cp bin "$SER" "$GRID_FOR_DENSITY" "$first_rho" "$SEED" >/dev/null || true
$J -cp bin "$PAR" "$GRID_FOR_DENSITY" "$first_rho" "$SEED" >/dev/null || true

while read -r r; do
  [ -z "$r" ] && continue
  ts=(); tp=()

  for i in $(seq 1 "$RUNS"); do
    out="$($J -cp bin "$SER" "$GRID_FOR_DENSITY" "$r" "$SEED")"
    ms="$(printf '%s\n' "$out" | get_ms)"; ts+=("$ms")

    out="$($J -cp bin "$PAR" "$GRID_FOR_DENSITY" "$r" "$SEED")"
    ms="$(printf '%s\n' "$out" | get_ms)"; tp+=("$ms")
  done

  msS="$(median "${ts[@]}")"
  msP="$(median "${tp[@]}")"
  sp="$(awk -v s="$msS" -v p="$msP" 'BEGIN{printf "%.6f", (p>0)? s/p : 0}')"
  printf "%s,%s,%s,%s,%s,%s,%s\n" "$HOST" "$GRID_FOR_DENSITY" "$r" "$SEED" "$msS" "$msP" "$sp" >> speedup_by_density.csv
done < <(gen_densities)

echo "Wrote: speedup_by_grid.csv, speedup_by_density.csv"
