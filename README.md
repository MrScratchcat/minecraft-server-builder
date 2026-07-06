#To install a minecraft server run this:
```bash
curl -fsSL https://raw.githubusercontent.com/MrScratchcat/minecraft-server-builder/refs/heads/main/server-creator.sh | bash
```

Supported server types: Vanilla, Fabric, Forge and NeoForge.

Version lists are fetched live from Mojang, Fabric, Forge and NeoForge, so new
releases are available immediately without updating the script. The matching
Java version for the chosen Minecraft version is picked automatically.

## Adding mods

Mods only work on Fabric, Forge and NeoForge servers (not Vanilla), and every
mod has to match your Minecraft version **and** your loader — a Forge 1.20.1
mod will not load on NeoForge or Fabric. Most content mods also need to be
installed in each player's client; only server-side mods (backups, performance,
admin tools) work with normal vanilla clients.

### Quick way: copy the mod into the container

```bash
sudo docker cp mymod.jar minecraft-server-container:/minecraft/mods/
sudo docker restart minecraft-server-container
```

If the mods folder does not exist yet, create it first:

```bash
sudo docker exec minecraft-server-container mkdir -p /minecraft/mods
```

Mods added this way survive restarts, but they are lost if you ever delete and
recreate the container, because only the world folder is on a persistent
volume.

### Better way: mount a mods folder from your computer

Create the container with an extra `-v` flag that points a folder on your
computer at `/minecraft/mods`:

```bash
mkdir -p ~/minecraft-mods
sudo docker rm -f minecraft-server-container   # remove the old container (your world is safe on its volume)
sudo docker run -d \
    --name minecraft-server-container \
    -p 25565:25565 \
    -v minecraft-data-:/minecraft/world \
    -v ~/minecraft-mods:/minecraft/mods \
    --restart always \
    minecraft-server
```

Now adding a mod is just: drop the jar into `~/minecraft-mods` and run
`sudo docker restart minecraft-server-container`. Nothing is lost when the
container is recreated.

Tip: run `sudo docker inspect minecraft-server-container | grep -A3 Mounts`
before removing the container to see the exact name of your world volume, and
use that name in the `-v` flag so the new container keeps your world. If you
used a different port or container name during setup, adjust the commands to
match.
