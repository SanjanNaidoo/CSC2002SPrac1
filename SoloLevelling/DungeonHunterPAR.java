// package SoloLevelling;  // <-- uncomment if your file lives in SoloLevelling/ and you want a package

import java.util.Random;
import java.util.concurrent.ForkJoinPool;
import java.util.concurrent.RecursiveTask;

public class DungeonHunterPAR {
    static final boolean DEBUG = false;

    // timers
    static long startTime = 0;
    static long endTime = 0;
    private static void tick() { startTime = System.currentTimeMillis(); }
    private static void tock() { endTime = System.currentTimeMillis(); }

    /** Result of the parallel search: global max value and index of winning Hunt. */
    static class Result {
        final int maxVal;
        final int finder;
        Result(int maxVal, int finder) { this.maxVal = maxVal; this.finder = finder; }
        int maxVal() { return maxVal; }
        int finder() { return finder; }
    }

    /** Fork/Join task over a subrange of searches. */
    static class SearchTask extends RecursiveTask<Result> {
        private final Hunt[] searches;
        private final int lo, hi, cutoff;
        SearchTask(Hunt[] searches, int lo, int hi, int cutoff) {
            this.searches = searches; this.lo = lo; this.hi = hi; this.cutoff = cutoff;
        }
        @Override protected Result compute() {
            int n = hi - lo;
            if (n <= cutoff) {
                int bestVal = Integer.MIN_VALUE, bestIdx = -1;
                for (int i = lo; i < hi; i++) {
                    int localMax = searches[i].findManaPeak();
                    if (localMax > bestVal || (localMax == bestVal && (bestIdx == -1 || i < bestIdx))) {
                        bestVal = localMax; bestIdx = i;
                    }
                    if (DEBUG) {
                        System.out.println("Shadow " + searches[i].getID() +
                                " finished at " + localMax + " in " + searches[i].getSteps());
                    }
                }
                return new Result(bestVal, bestIdx);
            } else {
                int mid = (lo + hi) >>> 1;
                SearchTask left  = new SearchTask(searches, lo,  mid, cutoff);
                SearchTask right = new SearchTask(searches, mid, hi,  cutoff);
                left.fork();
                Result rRight = right.compute();
                Result rLeft  = left.join();
                if (rLeft.maxVal() > rRight.maxVal() ||
                   (rLeft.maxVal() == rRight.maxVal() && rLeft.finder() < rRight.finder())) {
                    return rLeft;
                }
                return rRight;
            }
        }
    }

    /** Runs all Hunts in parallel and returns (maxVal, finderIndex). */
    static Result runParallelSearches(Hunt[] searches, int desiredParallelism) {
        int n = searches.length;
        if (n == 0) return new Result(Integer.MIN_VALUE, -1);

        int cores = Math.max(1, (desiredParallelism > 0) ? desiredParallelism
                                                         : Runtime.getRuntime().availableProcessors());
        int cutoff = Math.max(1, n / (cores * 8));

        ForkJoinPool pool = (desiredParallelism > 0)
                ? new ForkJoinPool(desiredParallelism)
                : ForkJoinPool.commonPool();

        return pool.invoke(new SearchTask(searches, 0, n, cutoff));
    }

    public static void main(String[] args) {
        double xmin, xmax, ymin, ymax;
        DungeonMap dungeon;

        int numSearches = 10, gateSize = 10;
        Hunt[] searches;

        Random rand = new Random();
        int randomSeed = 0;

        if (args.length != 3) {
            System.out.println("Incorrect number of command line arguments provided.");
            System.exit(0);
        }

        try {
            gateSize = Integer.parseInt(args[0]);
            if (gateSize <= 0) throw new IllegalArgumentException("Grid size must be greater than 0.");

            numSearches = (int) (Double.parseDouble(args[1]) * (gateSize * 2) * (gateSize * 2) * DungeonMap.RESOLUTION);

            randomSeed = Integer.parseInt(args[2]);
            if (randomSeed < 0) throw new IllegalArgumentException("Random seed must be non-negative.");
            else if (randomSeed > 0) rand = new Random(randomSeed);
        } catch (NumberFormatException e) {
            System.err.println("Error: All arguments must be numeric.");
            System.exit(1);
        } catch (IllegalArgumentException e) {
            System.err.println("Error: " + e.getMessage());
            System.exit(1);
        }

        xmin = -gateSize; xmax = gateSize; ymin = -gateSize; ymax = gateSize;
        dungeon = new DungeonMap(xmin, xmax, ymin, ymax, randomSeed);

        int dungeonRows = dungeon.getRows();
        int dungeonColumns = dungeon.getColumns();
        searches = new Hunt[numSearches];

        for (int i = 0; i < numSearches; i++) {
            searches[i] = new Hunt(i + 1, rand.nextInt(dungeonRows), rand.nextInt(dungeonColumns), dungeon);
        }

        int max = Integer.MIN_VALUE;
        int finder = -1;

        tick();
        Result r = runParallelSearches(searches, 0); // 0 => commonPool
        tock();

        max = r.maxVal();
        finder = r.finder();

        System.out.printf("\t dungeon size: %d,\n", gateSize);
        System.out.printf("\t rows: %d, columns: %d\n", dungeonRows, dungeonColumns);
        System.out.printf("\t x: [%f, %f], y: [%f, %f]\n", xmin, xmax, ymin, ymax );
        System.out.printf("\t Number searches: %d\n", numSearches);

        System.out.printf("\n\t time: %d ms\n", endTime - startTime);
        int tmp = dungeon.getGridPointsEvaluated();
        System.out.printf("\tnumber dungeon grid points evaluated: %d  (%2.0f%s)\n",
                tmp, (tmp * 1.0 / (dungeonRows * dungeonColumns * 1.0)) * 100.0, "%");

        System.out.printf("Dungeon Master (mana %d) found at:  ", max);
        System.out.printf("x=%.1f y=%.1f\n\n",
                dungeon.getXcoord(searches[finder].getPosRow()),
                dungeon.getYcoord(searches[finder].getPosCol()));
        dungeon.visualisePowerMap("visualiseSearchParallel.png", false);
        dungeon.visualisePowerMap("visualiseSearchPathParallel.png", true);
    }
}
