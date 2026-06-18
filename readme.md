# RAGE:MP Offline Launcher / Updater Bypass

This project started as an experiment to bypass RAGE:MP's update and authentication infrastructure.

The main idea was simple: if RAGE:MP can run without depending on its online services, then servers and clients could continue functioning even if the official infrastructure becomes unavailable in the future.

By recreating and serving the API responses expected by the launcher, I was able to get RAGE:MP running in an offline environment. I'm releasing this source code in the hope that it saves others time and encourages further research. With enough effort, it may be possible to preserve multiplayer functionality and keep existing communities alive long after official support ends.

## Limitations

This solution only works with the GTA V version currently supported by RAGE:MP.

If Rockstar Games releases a GTA V update that changes the game client, RAGE:MP would normally require an update to maintain compatibility. Should official RAGE:MP development cease, no future updates would be available, making this bypass ineffective for newer GTA V versions.

For that reason, this project should be viewed as a preservation effort rather than a permanent solution.
