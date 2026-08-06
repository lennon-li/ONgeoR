# Snapshot: ONgeoR 0.4.0, full pre-MVP feature set

**Taken:** 2026-08-06
**Source:** `ONgeoR` `main` @ `d709150`
**Method:** `git archive HEAD` — tracked files only

## What this is

A verbatim copy of ONgeoR as it stood before the MVP trim. It is **parked, not
retired**: the plan is to cut the package down to a smaller, more robust core
and then pull capabilities back out of here as they earn their way in.

## What it is not

- Not built, checked, loaded, or tested. `^attic$` is in the package
  `.Rbuildignore`, so `R CMD build` / `R CMD check` / `devtools::load_all()`
  / `testthat` all skip this directory entirely. Nothing in here runs.
- Not a substitute for git history. `git show d709150` is authoritative if the
  two ever disagree. This folder exists so the removed code stays *browsable
  side by side* with the trimmed version while trimming is in progress.
- Not complete. `git archive` copies tracked files only, which deliberately
  excludes `/data/` (licensed PCCF + full-resolution HIVE shapefile, never
  committed), `ONgeoR.png`, `README.html`, and pkgdown output. Restoring the
  data layer means re-fetching it, not copying it from here.

## Companion snapshot

`ONgeoRapp` was snapshotted at the same time — see
`ONgeoRapp/attic/full-v0.1.0/SNAPSHOT.md` (`main` @ `7b0c9a0`). The app depends
on this library, so the two are trimmed in lockstep and the snapshots are only
meaningful as a pair.

## Removing this folder

Once the MVP has stabilised and nothing more is coming back out, delete the
whole directory and drop `^attic$` from `.Rbuildignore`. The history keeps it.
