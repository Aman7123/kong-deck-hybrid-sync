# kong-deck-hybrid-sync
Allows for DB-Less Kong Data Planes with just the Admin API, KIC, and a Proxy to sync with a Control Plane with DB.

## Overview
kong-deck-hybrid-sync is a simple way to replicate a unique data plane environment across multiple clusters but using a single read only data plane.

It has the following features:

* dump and sync
* select how often to run a dump
* select when to start the first dump, whether time of day or relative to container start time

## Sync
To run a sync, launch `kong-deck-hybrid-sync` image as a container with the correct parameters. Everything is controlled by environment variables passed to the container.

The following are the environment variables for a backup:

* `DS_RUN_FREQ`: How often to do a dump and sync, in minutes. Defaults to 5 minutes.
* `DS_RUN_ONCE`: Run the backup once and exit if `RUN_ONCE` is set. Useful if you use an external scheduler (e.g. as part of an orchestration solution like Cattle or Docker Swarm or [kubernetes cron jobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)) and don't want the container to do the scheduling internally. If you use this option, all other scheduling options, like `DB_DUMP_FREQ` and `DB_DUMP_BEGIN` and `DB_DUMP_CRON`, become obsolete.
* `DS_RUN_BEGIN`: What time to do the first dump. Defaults to 1 minute. Must be in one of two formats:
    * Absolute: HHMM, e.g. `2330` or `0415`
    * Relative: +MM, i.e. how many minutes after starting the container, e.g. `+10` (in 10 minutes), or `+90` in an hour and a half
* `DS_RUN_CRON`: Set the dump schedule using standard [crontab syntax](https://en.wikipedia.org/wiki/Cron), a single line.
* `VERBOSE`: Enables `set -x` in the script, which prints out every command as it is run. Useful for debugging.
* `DS_DEBUG`: Enables output of the Kong decK commands. Useful for debugging.
* `KONG_WORKSPACE`: The workspace to use for dump and sync. The workspace used in the data plane can be set within the KIC environment variables. Must not conflict with the workspace used in the control plane or the sync will overwrite anything in the control plane workspace.
* `KONG_DP_ADMIN_URL`: The URL of the data plane admin API. Defaults to using environment variables set by the helm deployment which has to local IP and port of the Admin API used by the data plane.
* `KONG_CP_ADMIN_URL`: The URL of of the control plane Admin API.
* `KONG_CP_ADMIN_TOKEN`: If using RBAC on the control plane this should be set to an RBAC user with READ/WRITE access to the workspace set in `KONG_WORKSPACE`.

### Scheduling
There are several options for scheduling how often a backup should run:

* `DS_RUN_ONCE`: run just once and exit.
* `DS_RUN_CRON`: run on a schedule.
* `DS_RUN_FREQ` and `DS_RUN_BEGIN`: run every x minutes, and run the first one at a particular time.

#### Cron Scheduling
If a cron-scheduled backup takes longer than the beginning of the next backup window, it will be skipped. For example, if your cron line is scheduled to backup every hour, as follows:

```
0 * * * *
```

And the backup that runs at 13:00 finishes at 14:05, the next backup will not be immediate, but rather at 15:00.

The cron algorithm is as follows: after each backup run, calculate the next time that the cron statement will be true and schedule the backup then.

#### Order of Priority
The scheduling options have an order of priority:

1. `RUN_ONCE` runs once, immediately, and exits, ignoring everything else.
2. `DS_RUN_CRON`: runs according to the cron schedule, ignoring `DB_DUMP_FREQ` and `DB_DUMP_BEGIN`.
3. `DB_DUMP_FREQ` and `DB_DUMP_BEGIN`: if nothing else is set.

### Permissions
By default the container will need the proper `Kong-Admin-Token` header passed as the env var `KONG_CP_ADMIN_TOKEN` for the Control Plane.

### Automated Build
This github repo is the source for the kong-deck-hybrid-sync. The actual image is stored on the docker hub at `arenner/kong-deck-hybrid-sync`, and is triggered with each commit to the source by automated build via Webhooks.