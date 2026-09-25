
# [All the Mons - ATMons](https://www.curseforge.com/minecraft/modpacks/all-the-mons) on Curseforge
<!-- toc -->

- [Description](#description)
- [Requirements](#requirements)
- [Options](#options)
  * [Adding Minecraft Operators](#adding-minecraft-operators)
- [Troubleshooting](#troubleshooting)
  * [Accept the EULA](#accept-the-eula)
  * [Permissions of Files](#permissions-of-files)
  * [Resetting](#resetting)
  * [Upgrading](#upgrading)
- [Credits](#credits)

<!-- tocstop -->

## Description

This container is built to run on an [Unraid](https://unraid.net) server, outside of that your mileage will vary.

On first startup, this container downloads the ServerFiles release pinned in `launch.sh` directly from CurseForge (a daily GitHub Action bumps it to the latest) and installs it into /data.

Subsequent starts will launch the installed server normally.

No modded Minecraft files are shipped in this image — everything is downloaded at runtime.

Java 21
Multi-arch support (amd64 + arm64)

## Requirements

* /data mounted to a persistent disk
* Port 25565/tcp mapped
* environment variable EULA set to "true"
* Recommended: add `--stop-timeout=60` to **Extra Parameters** (Unraid advanced view). On stop, the container types `stop` into the server console and waits for the world to save; Docker's default 10 seconds can be too short for a big world.

As the end user, you are responsible for accepting the EULA from Mojang to run their server, by default in the container it is set to false.

## Options

These environment variables can be set to override their defaults.

* JVM_OPTS "-Xms2048m -Xmx4096m"
* MOTD "All the Mons | Modded Survival"
* ALLOW_FLIGHT "true" or "false"
* MAX_PLAYERS "5"
* ONLINE_MODE "true" or "false"
* ENABLE_WHITELIST "true" or "false"
* WHITELIST_USERS "TestUserName1, TestUserName2"
* OP_USERS "TestUserName1, TestUserName2"

## Troubleshooting

### Accept the EULA
Did you pass in the environment variable EULA set to `true`?

### Permissions of Files
This container is designed for [Unraid](https://unraid.net) so the user in the container runs on uid 99 and gid 100.  This may cause permission errors on the /data mount on other systems.

### Resetting
If the installation is incomplete for some reason.  Deleting the downloaded server file in /data will restart the install/upgrade process.

### Upgrading
When a new image version starts, it reinstalls the pack's `config`, `kubejs`, `mods` and NeoForge `libraries`. Your world, `server.properties`, whitelist and ops are kept. Back up `/data/world` before upgrading.

## Credits
Github: https://github.com/Goobaroo/docker-allthemods9

Docker: https://hub.docker.com/repository/docker/goobaroo/allthemods9

Github: https://github.com/W3LFARe/docker-allthemods10

Docker: https://registry.hub.docker.com/r/w3lfare/allthemods10 
