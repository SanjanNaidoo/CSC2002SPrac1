#!/usr/bin/env python3
import sys, csv, matplotlib.pyplot as plt
from collections import defaultdict

if len(sys.argv) < 3:
    print("usage: python3 plot_speedup.py <csv> <title> [out.png]")
    sys.exit(1)

fn = sys.argv[1]
title = sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else None

# Load rows and normalize decimals
rows = []
with open(fn, newline='') as f:
    r = csv.DictReader(f)
    for row in r:
        row['grid']    = int(row['grid'])
        row['rho']     = float(str(row['rho']).replace(',', '.'))
        row['speedup'] = float(str(row['speedup']).replace(',', '.'))
        rows.append(row)

# Determine X axis from filename
xkey = 'grid' if 'by_grid' in fn else 'rho'
xlabel = 'Grid size (gateSize)' if xkey == 'grid' else 'Search density (ρ)'

# Group by machine
series = defaultdict(list)  # machine -> list[(x, y)]
for row in rows:
    series[row['machine']].append((float(row[xkey]), row['speedup']))

plt.figure()
for mach, pts in sorted(series.items()):
    pts.sort()
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    plt.plot(xs, ys, marker='o', markersize=3, linewidth=1.5, label=mach)

plt.title(title)
plt.xlabel(xlabel)
plt.ylabel('Speedup (T_serial / T_parallel)')
plt.grid(True)
if len(series) > 1:
    plt.legend()

if out:
    plt.savefig(out, bbox_inches='tight', dpi=150)
else:
    plt.show()

