# docker-atmons

Unraid Docker image for the All the Mons server (CurseForge project 1356598): Minecraft 1.21.1, NeoForge, Java 21. Forked from W3LFARe/docker-allthemods10. The sibling repo `adamzaidi/docker-atm11` has the same layout, so fixes usually apply to both.

- `launch.sh` pins `SERVER_VERSION` + `SERVER_FILE_ID` (the ServerFiles zip, not the client pack file). `update-mod.yml` runs `fetch_latest_server_files.js` daily to bump them; a push to main builds and pushes `DOCKERHUB_USERNAME/docker-atmons:<version>` + `:latest`.
- The pack's `startserver.sh` still uses ATM10 env var names (`ATM10_INSTALL_ONLY`, `ATM10_RESTART`).
- `launch.sh` calls `startserver.sh` only with `ATM10_INSTALL_ONLY=true` (installs NeoForge and creates server.properties), then runs Java itself. Run as PID 1, startserver.sh ignored SIGTERM, so `docker stop` killed the server without saving. Now a SIGTERM trap writes `stop` to a FIFO on the server's stdin and waits.
- The pack's `user_jvm_args.txt` has no trailing newline. `launch.sh` adds one before appending `JVM_OPTS`, otherwise flags fuse together and the JVM won't start.
- server.properties settings use `set_prop` (sets the key, or appends it if missing), because they have to apply on first boot, before Minecraft writes the full file.
- startserver.sh installs NeoForge only when `libraries/` is missing, so the upgrade path wipes `libraries` along with config/kubejs/mods.
- Restarts after a crash are left to Docker's restart policy (the pack's internal restart loop is no longer used).
- ForgeCDN URL = `files/<first 4 digits of id>/<last 3 digits, leading zeros stripped>/<name>`.
