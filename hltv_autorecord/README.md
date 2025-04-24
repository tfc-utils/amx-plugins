This content comes from https://forums.alliedmods.net/showthread.php?p=993138.

**Description:**
This is a simple and usefull plugin designed for servers, that want to use autorecording hltv, but dont want to have empty demos when there are no players (at night, for example).
So, when hltv is connected, plugin will check minimal amount of players defined by the cvar and if it is not recording, it will start record. When the amount of players is lower than this cvar, hltv stops recording.
You can also define the path, where the demo will be stored.

**Note:**
1. If u have 2 or more HLTV in server, the only first connected will record.
2. To enable plugin without reading this flood about cvars just do:
2.1 Create cstrike/demos folder.
2.2 Find hltv.cfg and change adminpassword "hltvadminpass"
2.3 Add hltv_autorecord.amxx into cstrike/addons/configs/plugins.ini
   
**Cvars:**
autohltv_record 1 - enables autorecording
autohltv_path "demos/HLTV" - it means, that you will have "cstrike/demos/HLTV-12389034.dem". If you want to put the demos into ctrike folder, just make this cvar empty.
autohltv_ignorebots 1 - ignore bots as real players, it means that plugin will not count them at all (look next cvar). If you have bots, then change this cvar to 0 and change map on the server (or restart).
autohltv_minplayers 2 - minimum number of players in game to start recording hltv
autohltv_pass "hltvadminpass" - the pass to control hltv. Go to the hltv.cfg and find adminpassword there. Now you can change it to this or any other that you define by this cvar.
autohltv_recording 1|0 - automatic cvar, dont touch it if you dont know what you do. You can use it in server monitoring to find whether hltv is recording or not.
autohltv_time 0|1|2, 2 is default. 0 - no timer show as hudmessage. 1 - timer only for hltv. 2 - for all players. This may be usefull to set 2 for public servers, because it is not bad to know every second what the time is and you can use 1 for showing the time only for hltv, so you will see it in hltv demo and check the real time and match with time in your logs.
autohltv_delay 30.0 - delay should be equal to delay in hltv.cfg (director.cfg) of HLTV-server configuration file.

**Required modules:**
<sockets>

**Credits:**
Infra

**Changelog:**
1.7 - major update and added "autohltv_delay 30.0" cvar
1.6 - update of this plugin (final fix versus server crashing).
1.5 - Final fix versus server crash and added time showing feature for hltv or for all players set by default (configured by the cvar - read above). This will work as soon, as hltv is connected to server (so do not expect any if you dont have hltv)
1.3 - Fix versus server crashing (hope, the last one)
1.2 - Fix versus server crashing
1.1 - Fix versus server crash and added cvar for announcing, that hltv is recording.
1.0 - Initial release.

p.s. For hltv correct storage, there is php script in russian language. To correctly split demo name, use the autohltv_path "demos/HLTV" or just "HLTV". Credits to One, Timmy and a little bit for me 

p.p.s Arch.php.gz is a crontab-usage php-script if you have hltv server and web-server on the same machine. It will automatically compress the demos into zip and put them from your hlds/cstrike/demos/server1 folder into /srv/http/demos/server1 (i mean, to your http path). Before using change the pathes inside the script. After it is ready, simply create a file, for example, "cron_demos"
Code:
```
SHELL=/bin/bash
0-59 * * * * php /path_to_arch.php/arch.php
```
and execute
Code:
```
crontab cron_demos
```
