/*****************************************************
Airshot 2.1

An updated Airshot plugin originally released by Watch:
https://forums.alliedmods.net/showthread.php?t=24312&highlight=airshot

2.1 Update (22/5/2024)

Since the latest Half Life update on 1080p & 720p resolutions, many HUD elements have been increased in size, including HUD Messages. 
This was causing longer names to overlap and look ugly!

[*] Reworked letter spacing so each message is perfectly spaced.
[*] Player names will no longer be shortened and can be the maximum of 31 characters.

Airshot 2.0 example:
 - https://i.imgur.com/a6TKaKz.jpeg

Airshot 2.1 fixed:
 - https://i.imgur.com/A2Ga804.jpeg

Requirements:
[*] AMXX 1.8.3 or above (HUD Messages are sent using Director HUD Messages)
[*] Install the .wav sounds to: tfc/sound/airshot

New Features:
[*] Added colour HUD Messages
  - HUD Messages will be the team colours of the owner and victim.
    https://i.imgur.com/Wtupj9C.jpg
	
[*] Added mid-air and double airshot detection
  - If the owner is also in the air, a mid-airshot is detected.
  - If the owner hits the same victim twice before they hit the ground, a double is detected.
    https://i.imgur.com/5X69KFz.jpg
	
[*] Added quake sounds for each airshot
  - Airshot = Ownage
  - Mid-air = Dominating
  - Double = Holy shit!

[*] Added more gore!
  - If the victim is killed by an airshot, Extra gibs and blood will be rendered.

Notes (Bugs):
[*] Only 3 airshots can be printed on the screen at the same time and will stack with the most recent at the bottom, then reset to the top when all are cleared.
[*] If another player airshots just after one, then that victim becomes the new double detection victim and the first will be ignored.

HAVE FUN! :D
*****************************************************/

#include <amxmodx>
#include <engine>

#pragma semicolon 1

#define SOUND_AIRSHOT "airshot/airshot.wav"
#define SOUND_AIRSHOT_MIDAIR "airshot/airshot2.wav"
#define SOUND_AIRSHOT_DOUBLE "airshot/airshot3.wav"
#define SOUND_SPLAT "common/bodysplat.wav"
#define MODEL_GIBLEG "models/gib_hgrunt.mdl"
#define MODEL_GIBPARTS "models/hgibs.mdl"

// characters in order of frequency
new const szChar[80] = "etaoinshrdlcumwfgypbvkjxqzETAOINSHRDLCUMWFGYPBVKJXQZ _()[]{}<>@|/!?-.,&*#+=$:;'";

// space consumed by each character
new Float:fSpace[80] = {0.0072, 0.0052, 0.0068, 0.0072, 0.0037, 0.0072, 0.0052, 0.0072, 0.0052, 0.0072, 0.0037, 0.0063, 0.0072,
						0.0109, 0.0103, 0.0048, 0.0063, 0.0068, 0.0072, 0.0072, 0.0068, 0.0068, 0.0048, 0.0068, 0.0072, 0.0068,
						0.0072, 0.0078, 0.0078, 0.0088, 0.0038, 0.0082, 0.0062, 0.0082, 0.0078, 0.0078, 0.0068, 0.0078, 0.0082,
						0.0093, 0.0113, 0.0072, 0.0082, 0.0077, 0.0072, 0.0072, 0.0078, 0.0078, 0.0068, 0.0073, 0.0088, 0.0068,
						0.0042, 0.0075, 0.0049, 0.0049, 0.0054, 0.0054, 0.0054, 0.0054, 0.0075, 0.0075, 0.0101, 0.0073, 0.0050,
						0.0050, 0.0059, 0.0049, 0.0050, 0.0049, 0.0091, 0.0054, 0.0075, 0.0075, 0.0075, 0.0075, 0.0049, 0.0049, 0.0033};

new const g_szSoundFlesh[5][] = {"debris/flesh2.wav", "debris/flesh3.wav", "debris/flesh5.wav", "debris/flesh6.wav", "debris/flesh7.wav"};

#define VectorScale(%0,%1,%2)  ( %2[ x ] = %1 * %0[ x ], %2[ y ] = %1 * %0[ y ], %2[ z ] = %1 * %0[ z ] )
enum _:Vector { Float:x, Float:y, Float:z };

new colBlue[3] = {0, 128, 255};
new colRed[3] = {255, 40, 0};
new colYellow[3] = {255, 255, 0};
new colGreen[3] = {0, 255, 0};
	
new spr_blood;
new spr_bloodspray;
new g_iType;
new g_iMsgCount;
new g_iOwnerIndex;
new g_iVictimIndex;
new g_iKilledIndex;
new g_iDecalIndex[8];
new Float:g_vOrigin[3];
new Float:g_vVelocity[3];

new Float:g_fX = 0.02;
new Float:g_fY = 0.1;

public plugin_init()
{
	register_plugin("airshot", "2.1", "watch/se7en");
	register_touch("tf_rpg_rocket", "player", "rocket_touch");
	register_touch("airshot_gibs", "worldspawn", "gib_touch");
	register_event("DeathMsg", "event_DeathMsg", "a");
	register_event("ResetHUD", "event_ResetHUD", "b");
	
	new szDecal[8];
	for(new i = 0; i < 8; i++)
	{
		formatex(szDecal, charsmax(szDecal), "{blood%i", i + 1);
		g_iDecalIndex[i] = get_decal_index(szDecal);
	}
}

public plugin_precache()
{
	spr_blood = precache_model("sprites/blood.spr");
	spr_bloodspray = precache_model("sprites/bloodspray.spr");
	precache_sound(SOUND_AIRSHOT);
	precache_sound(SOUND_AIRSHOT_MIDAIR);
	precache_sound(SOUND_AIRSHOT_DOUBLE);
	precache_sound(SOUND_SPLAT);
	precache_sound(g_szSoundFlesh[0]);
	precache_sound(g_szSoundFlesh[1]);
	precache_sound(g_szSoundFlesh[2]);
	precache_sound(g_szSoundFlesh[3]);
	precache_sound(g_szSoundFlesh[4]);
	precache_model(MODEL_GIBPARTS);
	precache_model(MODEL_GIBLEG);
}

public rocket_touch(iRocket, iVictim)
{
	// check the victim is actually in the air (airshot)
	if(get_entity_flags(iVictim) & FL_ONGROUND)
		return;
	
	// check the rocket came from a soldier and not an SG
	new iOwner = entity_get_edict(iRocket, EV_ENT_owner);
	new iClass = entity_get_int(iOwner, EV_INT_playerclass);
	
	if(iClass != 3)
		return;
	
	// check they are on different teams
	new iOwnerTeam = entity_get_int(iOwner, EV_INT_team);
	new iVictimTeam = entity_get_int(iVictim, EV_INT_team);
	
	if(iOwnerTeam == iVictimTeam)
		return;
	
	// check if this airshot is a double
	if(iOwner == g_iOwnerIndex && iVictim == g_iVictimIndex)
	{
		// play the holy shit sound
		client_cmd(0, "spk ^"sound/%s^"", SOUND_AIRSHOT_DOUBLE);
		g_iType = 2;
	}
	
	// check if the owner is also in the air (mid-air shot)
	else if(!(get_entity_flags(iOwner) & FL_ONGROUND))
	{
		// play the dominating sound
		client_cmd(0, "spk ^"sound/%s^"", SOUND_AIRSHOT_MIDAIR);
		g_iType = 1;
	}
	else
		// play the ownage sound
		client_cmd(0, "spk ^"sound/%s^"", SOUND_AIRSHOT);
	
	// store the ids to check if the owner doubles or the victim is killed
	g_iOwnerIndex = iOwner;
	g_iVictimIndex = iVictim;
	g_iKilledIndex = iVictim;
	set_task(0.1, "reset_killed");
	set_task(0.2, "check_grounding", iVictim + 1483);
	entity_get_vector(iVictim, EV_VEC_origin, g_vOrigin);
	entity_get_vector(iRocket, EV_VEC_velocity, g_vVelocity);
	
	// clear all HUD messages and start from the top if 3 airshots are already displayed
	if(g_iMsgCount == 3)
		clear_hudmessages();
	
	switch(iOwnerTeam)
	{
		case 1: // owner is blue
		{
			switch(iVictimTeam)
			{
				case 2: send_hudmessage(iOwner, iVictim, colBlue, colRed);		// victim is red
				case 3: send_hudmessage(iOwner, iVictim, colBlue, colYellow);	// victim is yellow
				case 4: send_hudmessage(iOwner, iVictim, colBlue, colGreen);	// victim is green
			}
		}
		case 2: // owner is red
		{
			switch(iVictimTeam)
			{
				case 1: send_hudmessage(iOwner, iVictim, colRed, colBlue);		// victim is blue
				case 3: send_hudmessage(iOwner, iVictim, colRed, colYellow);	// victim is yellow
				case 4: send_hudmessage(iOwner, iVictim, colRed, colGreen);		// victim is green
			}
		}
		case 3: // owner is yellow
		{
			switch(iVictimTeam)
			{
				case 1: send_hudmessage(iOwner, iVictim, colYellow, colBlue);	// victim is blue
				case 2: send_hudmessage(iOwner, iVictim, colYellow, colRed);	// victim is red
				case 4: send_hudmessage(iOwner, iVictim, colYellow, colGreen);	// victim is green
			}
		}
		case 4: // owner is green
		{
			switch(iVictimTeam)
			{
				case 1: send_hudmessage(iOwner, iVictim, colGreen, colBlue);	// victim is blue
				case 2: send_hudmessage(iOwner, iVictim, colGreen, colRed);		// victim is red
				case 3: send_hudmessage(iOwner, iVictim, colGreen, colYellow);	// victim is yellow
			}
		}
	}
	
	// move the next HUD message down (if within 6 seconds of the last)
	g_iMsgCount++;
	
	switch(g_iMsgCount)
	{
		case 1:
		{
			g_fY = 0.13;
			set_task(6.1, "reset_hudmessage", 16091);
		}
		case 2:
		{
			g_fY = 0.16;
			set_task(6.1, "reset_hudmessage", 16092);
		}
	}
}

// print the colour HUD message
public send_hudmessage(iOwner, iVictim, iOwnerColor[], iVictimColor[])
{
	// generate the names for the HUD message
	new szOwnerName[32], szVictimName[32];
	get_user_name(iOwner, szOwnerName, 31);
	get_user_name(iVictim, szVictimName, 31);
	
	// get the distance and convert game units into meters
	new Float:vOwnerOrigin[3], Float:vVictimOrigin[3];
	entity_get_vector(iOwner, EV_VEC_origin, vOwnerOrigin);
	entity_get_vector(iVictim, EV_VEC_origin, vVictimOrigin);
	
	new iDistance = floatround(get_distance_f(vOwnerOrigin, vVictimOrigin) / 76.0);
	
	// calculate the X position
	new iTotal;
	new iLength = strlen(szOwnerName);
	
	for(new i = 0; i < iLength; i++)
	{
		if(isdigit(szOwnerName[i]))
		{
			// digits always consume the same amount of space
			g_fX += 0.0073;
			iTotal++;
			continue;
		}
		
		else for(new j = 0; j < 79; j++)
		{
			if(equal(szOwnerName[i], szChar[j], 1))
			{
				g_fX += fSpace[j];
				iTotal++;
				break;
			}
		}
	}
	
	// add an average space for anything else
	if(iTotal != iLength)
	{
		new iFill = iLength - iTotal;
		g_fX += 0.0066 * float(iFill);
	}
	
	// WARNING: Do not modify the HUD Messages below! HUD Messages have a maximum length of 128 characters!
	set_dhudmessage(iOwnerColor[0], iOwnerColor[1], iOwnerColor[2], 0.02, g_fY, 0, 0.5, 6.0, 0.0, 2.0);
	show_dhudmessage(0, szOwnerName);
	
	switch(g_iType)
	{
		case 0:
		{
			set_dhudmessage(255, 160, 0, 0.006 + g_fX, g_fY, 0, 0.5, 6.0, 0.0, 2.0);
			show_dhudmessage(0, "|airshot %dm|", iDistance);
		}
		case 1:
		{
			set_dhudmessage(255, 160, 0, 0.006 + g_fX, g_fY, 1, 0.0, 1.0, 3.0, 3.0);
			show_dhudmessage(0, "|mid-air %dm|", iDistance);
		}
		case 2:
		{
			set_dhudmessage(255, 160, 0, 0.006 + g_fX, g_fY, 1, 0.0, 1.0, 3.0, 3.0);
			show_dhudmessage(0, "|doubled %dm|", iDistance);
			g_iOwnerIndex = 0;
			g_iVictimIndex = 0;
		}
	}
	
	if(iDistance > 9)
		g_fX += 0.0075;
	
	if(g_iType == 2)
		g_fX += 0.095;
	else
		g_fX += 0.089;
	
	set_dhudmessage(iVictimColor[0], iVictimColor[1], iVictimColor[2], g_fX, g_fY, 0, 0.5, 6.0, 0.0, 2.0);
	show_dhudmessage(0, szVictimName);
	
	g_fX = 0.02;
	g_iType = 0;
}

// if the airshot killed the victim in the air, render more gibs and blood :D
public event_DeathMsg()
{
	new iVictim = read_data(2);
	
	if(iVictim != g_iKilledIndex)
		return;
	
	set_entity_visibility(iVictim, 0);
	emit_sound(iVictim, CHAN_AUTO, SOUND_SPLAT, VOL_NORM, ATTN_STATIC, 0, PITCH_NORM);
	
	// standard blood sprite
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_BLOODSPRITE);
	write_coord(floatround(g_vOrigin[0]));	// origin x
	write_coord(floatround(g_vOrigin[1]));	// y
	write_coord(floatround(g_vOrigin[2]));	// z
	write_short(spr_bloodspray);
	write_short(spr_blood);
	write_byte(248);							//red color amount
	write_byte(20);							//scale
	message_end();
	
	// gibs
	new iEntGibs[13];
	
	for(new i = 0; i < 13; i++)
	{
		iEntGibs[i] = create_entity("info_target");
		
		if(iEntGibs[i])
		{
			new Float:rVelocity[Vector];
			rVelocity[0] = g_vVelocity[0];
			rVelocity[1] = g_vVelocity[1];
			rVelocity[2] = g_vVelocity[2];
			VectorScale(rVelocity, random_float(1.1, 4.0), rVelocity);
			
			// streams of blood
			message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
			write_byte(TE_BLOODSTREAM);
			write_coord(floatround(g_vOrigin[0]));		// origin x
			write_coord(floatround(g_vOrigin[1]));		// y
			write_coord(floatround(g_vOrigin[2]));		// z
			write_coord(floatround(rVelocity[0]));		// velocity x
			write_coord(floatround(rVelocity[1]));		// y
			write_coord(floatround(rVelocity[2]));		// z
			write_byte(70);								// color
			write_byte(random_num(200, 500));			// speed
			message_end();
			
			if(i < 11)
			{
				entity_set_model(iEntGibs[i], MODEL_GIBPARTS);
				entity_set_int(iEntGibs[i], EV_INT_body, i + 1);
				entity_set_origin(iEntGibs[i], g_vOrigin);
				entity_set_string(iEntGibs[i], EV_SZ_classname, "airshot_gibs");
				entity_set_int(iEntGibs[i], EV_INT_solid, SOLID_TRIGGER);
				entity_set_int(iEntGibs[i], EV_INT_movetype, MOVETYPE_BOUNCE);
				entity_set_int(iEntGibs[i], EV_INT_rendermode, kRenderNormal);
				entity_set_float(iEntGibs[i], EV_FL_friction, 0.1);
				entity_set_float(iEntGibs[i], EV_FL_gravity, 1.0);
				entity_set_vector(iEntGibs[i], EV_VEC_velocity, rVelocity);
				entity_set_vector(iEntGibs[i], EV_VEC_avelocity, rVelocity);
			}
			else
			{
				entity_set_model(iEntGibs[i], MODEL_GIBLEG);
				entity_set_origin(iEntGibs[i], g_vOrigin);
				entity_set_string(iEntGibs[i], EV_SZ_classname, "airshot_gibs");
				entity_set_int(iEntGibs[i], EV_INT_solid, SOLID_TRIGGER);
				entity_set_int(iEntGibs[i], EV_INT_movetype, MOVETYPE_BOUNCE);
				entity_set_int(iEntGibs[i], EV_INT_rendermode, kRenderNormal);
				entity_set_float(iEntGibs[i], EV_FL_friction, 0.1);
				entity_set_float(iEntGibs[i], EV_FL_gravity, 1.0);
				entity_set_vector(iEntGibs[i], EV_VEC_velocity, rVelocity);
				entity_set_vector(iEntGibs[i], EV_VEC_avelocity, rVelocity);
			}
		}
	}
	
	set_task(10.0, "remove_gibs", iEntGibs[0], iEntGibs, 13);
	g_iKilledIndex = 0;
	g_iOwnerIndex = 0;
	g_iVictimIndex = 0;
}

public gib_touch(iGib, iTouched)
{	
	emit_sound(iGib, CHAN_AUTO, g_szSoundFlesh[random_num(0, 4)], VOL_NORM, ATTN_STATIC, 0, random_num(80, 120));
	
	static Float:fOrigin[3];
	entity_get_vector(iGib, EV_VEC_origin, fOrigin);
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_WORLDDECAL);
	write_coord(floatround(fOrigin[0]));
	write_coord(floatround(fOrigin[1]));
	write_coord(floatround(fOrigin[2]));
	write_byte(g_iDecalIndex[random_num(0, 7)]);
	message_end();
	
	static Float:vVelocity[Vector];
	entity_get_vector(iGib, EV_VEC_velocity, vVelocity);
	VectorScale(vVelocity, 0.50, vVelocity);	
	entity_set_vector(iGib, EV_VEC_velocity, vVelocity);
	entity_set_vector(iGib, EV_VEC_avelocity, vVelocity);
}

public remove_gibs(const iEntGibs[], id)
{
	for(new i = 0; i < 13; i++)
	{
		if(is_valid_ent(iEntGibs[i]))
		{
			remove_entity(iEntGibs[i]);
		}
	}
}

public check_grounding(iTask)
{
	new id = iTask - 1483;
	
	if(id != g_iVictimIndex)
		return;
	
	if(!(get_entity_flags(id) & FL_ONGROUND))
	{
		set_task(0.2, "check_grounding", iTask);
	}
	else
	{
		g_iOwnerIndex = 0;
		g_iVictimIndex = 0;
	}
}

public event_ResetHUD(id)
{
	if(id == g_iVictimIndex || id == g_iOwnerIndex)
	{
		g_iOwnerIndex = 0;
		g_iVictimIndex = 0;
	}
}

public reset_hudmessage(id)
{
	new iMsg = id - 16090;
	
	if(iMsg != g_iMsgCount)
		return;
	
	g_iMsgCount = 0;
	g_fY = 0.1;
}

public clear_hudmessages()
{
	set_dhudmessage(0, 0, 0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0);
	
	for(new i = 0; i < 8; i++)
	{
		show_dhudmessage(0, "");
	}
	
	g_iMsgCount = 0;
	g_fY = 0.1;
}

public reset_killed()
{
	g_iKilledIndex = 0;
}

public client_disconnected(id)
{
	if(id == g_iVictimIndex || id == g_iOwnerIndex)
	{
		g_iOwnerIndex = 0;
		g_iVictimIndex = 0;
	}
}
