#!/usr/bin/env bash
set -euo pipefail
J=java; SER="DungeonHunter"; PAR="DungeonHunterPAR"

sizes=(50 100 200 400)
dens=(0.05 0.10 0.20 0.40)
seeds=(1 2 3 4)

for g in "${sizes[@]}"; do
  for d in "${dens[@]}"; do
    for s in "${seeds[@]}"; do
      outS=$($J -cp bin $SER $g $d $s | grep -E 'Dungeon Master|x=' | tr -d '\r')
      outP=$($J -cp bin $PAR $g $d $s | grep -E 'Dungeon Master|x=' | tr -d '\r')
      if [[ "$outS" != "$outP" ]]; then
        echo "MISMATCH g=$g d=$d s=$s"; echo "S:$outS"; echo "P:$outP"; exit 1
      fi
    done
  done
done
echo "Validation passed ✅"
