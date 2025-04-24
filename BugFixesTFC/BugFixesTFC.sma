/*
* 	Fixes:
* 		- #1: Nails that would have been stuck as "ghosts" are now removed.
* 		- #2: Flags will no longer get stuck in solid objects.
* 		- #3: Spys can now be infected while feigned. This also prevents the server from crashing due to the infecting/healing feigned spies bug.
* 		- #4: Spys can no longer quick disguise. This also prevents the server from crashing due to disguising too quickly.
* 		- #5: The camera entity will no longer break the players view if the player disconnects while using it.
* 		- #6: Players will no longer stay concussed when they respawn.
* 		- #7: Opening doors will no longer remove effects from caltrops.
* 		- #8: The engineer's teleport will no longer take the player to the exit location if the player dies before the teleport has finished.
* 		- #9: Players can no longer take flags through engineer's teleporters.
* 		- #10: Players can no longer uncover dead enemy spies.
* 		- #11: Grenades that are stuck inside of another entity will no longer do too much damage to any entities in its explosion radius.
* 		- #12: Nail grenades will no longer get stuck in ceilings.
* 		- #13: Mirv grenade's bomblets will no longer spawn in areas with a solid object between the mirv and bomblet.
* 		- #14: Grenades that prime immediately before death will no longer follow the player to their spawn if they respawn quick enough.
* 		- #15: Primed grenades will no longer be wrongly removed by item_tfgoal removal if the player has zero primary or secondary grenades left.
* 		- #16: Players view angle will no longer change when a players health is 0 but still alive. (AKA Death Bug or Zero Health Bug)
*		- #17: Normal grenade jumps will always push a player forwards, even while the server runs at 1000 FPS. (sys_ticrate 1000.0)
*		- #18: Flags can now be tossed even if a player/wall is obstructing. (instead of: Not enough room to drop items here)
*		- #19: AMXX Menus stuck on a players screen from the last map are removed.
*
* 	Special thanks:
* 		- teh ORiON:	Contributed towards fixing bug #8.
* 		- azul:			Contributed towards fixing bug #14.
* 		- azul:			Supplied the signatures and code for bug #15.
* 
* 	Changelog:
*		- v1.4	-	2023/06/10
*		 + Reworked fix #15. Plugin is now fully self contained with no additional plugins/modules needed.
*		 + Minor code optimizations.
*
*		- v1.3	-	2022/05/16
*		 + Fixed a bug causing a random player class to be stuck on the same class. Thanks HLM
*
*		- v1.2	-	2021/08/02
*		 + NOTE: The okapi module is no longer required (could potentially be causing crashes).
*		 + NOTE: Since the Double Fire bug has finally been fixed by Steam, this plugin is compatible with the latest build of TFC. Servers should update.
*		 + Added a fix for the Death/Zero Health Bug (fix #16).
*		 + Added a fix for normal grenade jumps while the server runs at 1000 FPS (fix #17).
*		 + Added a fix to allow flag tossing through obstructions (fix #18).
*		 + Added a fix to remove AMXX Menus stuck on a screen from last map (fix #19).
*
* 		- v1.1	-	2017/06/15
* 		 + NOTE: The okapi module is no longer required.
* 		 + Added a fix for grenades following players to spawn (fix #14).
* 		 + Added a fix for primed grenades being wrongly removed by item_tfgoal removal (fix #15).
* 		 + Fixed an issue with the nail bug fix (fix #1).
* 
* 		- v1.0	-	2017/05/15
* 		 + Initial release (fixes #1-13).
*/


/*
* 	NOTES:
* 
* 	tfstate values:
* 		-1: Player is marked as both under the influence of a spy's gas grenade and a spy's tranquilizer dart.
* 		0:	Player is considered to be not priming a grenade.
* 		1:	Player is considered to be priming a grenade.
*/

#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>

#pragma semicolon 1

new const PLUGIN[] = "Bug Fixes TFC";
new const VERSION[] = "1.4";
new const AUTHOR[] = "hlstriker/se7en";

#define MAXPLAYERS 								32
#define OFFSET_CLIENT_CANT_DISGUISE_OR_TELEPORT	26
#define OFFSET_CLIENT_LINUX_DIFF				4	// 3 on older tfc.so
#define OFFSET_TELEPORTER_PLAYER				425
#define OFFSET_TELEPORTER_TYPE					427
#define OFFSET_TELEPORTER_STATE					428
#define OFFSET_TELEPORTER_LINUX_DIFF			5
#define TELEPORTER_TYPE_EXIT					5
#define TELEPORTER_STATE_TELEPORTING			3
#define TELEPORTER_STATE_TELEPORTING_2			4
#define TELEPORTER_STATE_RECHARGE				6
#define TELEPORTER_USE_DELAY_AFTER_DEATH		1.0

new g_iModelIndex_Rocket;
new g_iModelIndex_NailGrenade;
new g_iModelIndex_MirvBomblet;
new g_iLastMirvThinkEnt;
new g_pointerTicrate;
new g_iMaxPlayers;

new Float:g_fTicrate;
new Float:g_fFlagTossTime[MAXPLAYERS+1];
new Float:g_fFlagTossOrigin[MAXPLAYERS+1][3];
new Float:g_fDeathOrigin[MAXPLAYERS+1][3];
new Float:g_fLastDeath[MAXPLAYERS+1];

new bool:g_bCheckMedkitTrace[MAXPLAYERS+1];
new bool:g_bBlockConcuss[MAXPLAYERS+1];
new bool:g_bBlockSetOrigin[MAXPLAYERS+1];
new bool:g_bDied[MAXPLAYERS+1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_cvar("bug_fixes_tfc_ver", VERSION, FCVAR_SERVER|FCVAR_SPONLY);
	
	g_iMaxPlayers = get_maxplayers();
	g_pointerTicrate = get_cvar_pointer("sys_ticrate");
	g_fTicrate = get_pcvar_float(g_pointerTicrate);
	
	if(g_fTicrate > 110.0)
		RegisterHam(Ham_Spawn, "tf_weapon_normalgrenade", "OnSpawnGren", 1);
	
	register_forward(FM_SetOrigin, "fwd_SetOrigin");
	register_forward(FM_SetOrigin, "fwd_SetOrigin_Post", 1);
	register_forward(FM_TraceHull, "fwd_TraceHull_Post", 1);
	register_forward(FM_TraceLine, "fwd_TraceLine_Post", 1);
	
	RegisterHam(Ham_Weapon_PrimaryAttack, "tf_weapon_medikit", "OnPrimaryAttack_Medkit");
	RegisterHam(Ham_TFC_Concuss, "player", "OnConcuss");
	RegisterHam(Ham_TakeHealth, "player", "OnTakeHealth");
	RegisterHam(Ham_Touch, "tf_nailgun_nail", "OnTouch_Nail");
	RegisterHam(Ham_Think, "building_teleporter", "OnThink_Teleporter");
	RegisterHam(Ham_Think, "building_teleporter", "OnThink_Teleporter_Post", 1);
	RegisterHam(Ham_Think, "tf_weapon_mirvgrenade", "OnThink_MirvGrenade");
	
	register_event("DeathMsg", "Event_DeathMsg", "a", "2>0");
	register_event("ResetHUD", "Event_ResetHUD_Dead", "bd"); // Use "ResetHUD" instead of "Spectator" to detect when a player goes spec. "Spectator" is called after the flag is dropped.
	register_event("ResetHUD", "Event_ResetHUD_Alive", "be");
	
	register_message(get_user_msgid("Concuss"), "msg_Concuss");
	register_message(get_user_msgid("Damage"), "msg_Damage");
	register_message(get_user_msgid("MOTD"), "msg_MOTD");
	
	register_clcmd("dropitems", "cmd_DropItems");
	register_clcmd("+gren1", "cmd_Grenade");
	register_clcmd("+gren2", "cmd_Grenade");
	register_clcmd("primeone", "cmd_Grenade");
	register_clcmd("primetwo", "cmd_Grenade");
}

public plugin_precache()
{
	g_iModelIndex_Rocket = precache_model("models/rpgrocket.mdl");
	g_iModelIndex_NailGrenade = precache_model("models/ngrenade.mdl");
	g_iModelIndex_MirvBomblet = precache_model("models/bomblet.mdl");
}

public msg_Concuss(iMsgID, iDest, iClient)
{
	if(g_bBlockConcuss[iClient])
		set_msg_arg_int(1, ARG_BYTE, 0);
}

public msg_Damage(iMsgID, iDest, iClient)
{
	new Float:fHealth;
	pev(iClient, pev_health, fHealth);
	
	if((pev(iClient, pev_deadflag) == DEAD_NO) && fHealth < 1.0)
	{
		set_pev(iClient, pev_health, 1.0);
	}
}

public msg_MOTD(iMsgID, iDest, iClient)
{
	// send a blank menu to clear any bugged menus
	show_menu(iClient, 0, "^n", 1);
}

public cmd_DropItems(iClient)
{
	SaveFlagTossOrigin(iClient);
	
	if(!get_ent_data(iClient, "CBaseEntity", "fClientGrenadePrimed"))
		return PLUGIN_CONTINUE;
	
	new iGrenades[2];
	iGrenades[0] = get_ent_data(iClient, "CBaseEntity", "no_grenades_1");
	iGrenades[1] = get_ent_data(iClient, "CBaseEntity", "no_grenades_2");
	
	if(iGrenades[0] == 0 || iGrenades[1] == 0)
	{
		set_ent_data(iClient, "CBaseEntity", "no_grenades_1", 1);
		set_ent_data(iClient, "CBaseEntity", "no_grenades_2", 1);
		set_task(0.1, "Reset_Grenades", iClient + 100, iGrenades, 2);
	}
	
	return PLUGIN_CONTINUE;
}

public Reset_Grenades(const iGrenades[], iClient)
{
	set_ent_data(iClient - 100, "CBaseEntity", "no_grenades_1", iGrenades[0]);
	set_ent_data(iClient - 100, "CBaseEntity", "no_grenades_2", iGrenades[1]);
}

public cmd_Grenade(iClient)
{
	set_ent_data(iClient, "CBaseEntity", "bRemoveGrenade", false);
}

public Event_DeathMsg()
{
	new iVictim = read_data(2);
	if(!IsPlayer(iVictim))
		return;
	
	g_bDied[iVictim] = true;
	OnDeath(iVictim);
}

public Event_ResetHUD_Alive(iClient)
{
	if(!g_bDied[iClient])
		return;
	
	static iTFState;
	iTFState = get_ent_data(iClient, "CBaseEntity", "tfstate");
	set_ent_data(iClient, "CBaseEntity", "bRemoveGrenade", true);
	set_ent_data(iClient, "CBaseEntity", "tfstate", iTFState & ~0x0001);
	engfunc(EngFunc_SetView, iClient, iClient);
	g_bDied[iClient] = false;
	g_bBlockConcuss[iClient] = true;
	g_bBlockSetOrigin[iClient] = false;
}

public Event_ResetHUD_Dead(iClient)
{
	OnDeath(iClient);
}

public OnSpawnGren(iEnt)
{
	set_pcvar_float(g_pointerTicrate, 100.0);
	set_task(0.1, "reset_Ticrate");
}

public reset_Ticrate()
{
	set_pcvar_float(g_pointerTicrate, g_fTicrate);
}

public client_disconnected(iClient)
{
	SaveFlagTossOrigin(iClient);
	g_bDied[iClient] = false;
	g_bBlockConcuss[iClient] = false;
	g_bBlockSetOrigin[iClient] = false;
	g_bCheckMedkitTrace[iClient] = false;
}

OnDeath(iClient)
{
	entity_get_vector(iClient, EV_VEC_origin, g_fDeathOrigin[iClient]);
	
	SaveFlagTossOrigin(iClient);
	g_fLastDeath[iClient] = get_gametime();
	g_bBlockSetOrigin[iClient] = false;
}

SaveFlagTossOrigin(iClient)
{
	entity_get_vector(iClient, EV_VEC_origin, g_fFlagTossOrigin[iClient]);
	g_fFlagTossTime[iClient] = get_gametime();
}

public OnTouch_Nail(iTouched, iOther)
{
	static iTouchedModelIndex;
	iTouchedModelIndex = entity_get_int(iTouched, EV_INT_modelindex);
	
	if(iTouchedModelIndex != g_iModelIndex_Rocket)
		return;
	
	if(iTouchedModelIndex != entity_get_int(iOther, EV_INT_modelindex))
		return;
	
	static szClassNameTouched[32], szClassNameOther[32];
	entity_get_string(iTouched, EV_SZ_classname, szClassNameTouched, charsmax(szClassNameTouched));
	entity_get_string(iOther, EV_SZ_classname, szClassNameOther, charsmax(szClassNameOther));
	
	if(!equal(szClassNameTouched, szClassNameOther))
		return;
	
	entity_set_int(iTouched, EV_INT_solid, 0);
	entity_set_origin(iTouched, Float:{9999999.0, 9999999.0, 9999999.0});
}

public OnThink_Teleporter(iEnt)
{
	static iClient;
	iClient = get_pdata_cbase(iEnt, OFFSET_TELEPORTER_PLAYER, OFFSET_TELEPORTER_LINUX_DIFF);
	
	if(!IsPlayer(iClient))
		return;
	
	if(g_fLastDeath[iClient] + TELEPORTER_USE_DELAY_AFTER_DEATH < get_gametime())
		return;
	
	// Force the teleporters state into recharging if the state is still in teleporting. The server will crash if we null the player pointer without also changing the state.
	if(get_pdata_int(iEnt, OFFSET_TELEPORTER_STATE, OFFSET_TELEPORTER_LINUX_DIFF) == TELEPORTER_STATE_TELEPORTING)
		set_pdata_int(iEnt, OFFSET_TELEPORTER_STATE, TELEPORTER_STATE_RECHARGE, OFFSET_TELEPORTER_LINUX_DIFF);
	
	set_pdata_cbase(iEnt, OFFSET_TELEPORTER_PLAYER, -1, OFFSET_TELEPORTER_LINUX_DIFF);
}

public OnThink_Teleporter_Post(iEnt)
{
	if(!is_valid_ent(iEnt))
		return;
	
	static iClient;
	iClient = get_pdata_cbase(iEnt, OFFSET_TELEPORTER_PLAYER, OFFSET_TELEPORTER_LINUX_DIFF);
	
	if(!IsPlayer(iClient))
		return;
	
	if(!get_pdata_int(iClient, OFFSET_CLIENT_CANT_DISGUISE_OR_TELEPORT, OFFSET_CLIENT_LINUX_DIFF))
		return;
	
	if(get_pdata_int(iEnt, OFFSET_TELEPORTER_TYPE, OFFSET_TELEPORTER_LINUX_DIFF) != TELEPORTER_TYPE_EXIT)
		return;
	
	if(get_pdata_int(iEnt, OFFSET_TELEPORTER_STATE, OFFSET_TELEPORTER_LINUX_DIFF) != TELEPORTER_STATE_TELEPORTING_2)
		return;
	
	g_bBlockSetOrigin[iClient] = true;
}

public OnTakeHealth(iClient, Float:fHealth, iDamageBits)
{
	if(fHealth == 0.0)
		return HAM_SUPERCEDE;
	
	return HAM_IGNORED;
}

public OnConcuss(iClient, iConcEnt)
{
	g_bBlockConcuss[iClient] = false;
}

public OnPrimaryAttack_Medkit(iWeapon)
{
	static iOwner;
	iOwner = entity_get_edict(iWeapon, EV_ENT_owner);
	if(!IsPlayer(iOwner))
		return;
	
	g_bCheckMedkitTrace[iOwner] = true;
}

public OnThink_MirvGrenade(iEnt)
{
	g_iLastMirvThinkEnt = iEnt;
}

public fwd_SetOrigin(iEnt, Float:fOrigin[3])
{
	if(!IsPlayer(iEnt))
	{
		CheckSetOrigin_Grenade(iEnt);
		return FMRES_IGNORED;
	}
	
	if(!g_bBlockSetOrigin[iEnt])
		return FMRES_IGNORED;
	
	g_bBlockSetOrigin[iEnt] = false;
	return FMRES_SUPERCEDE;
}

CheckSetOrigin_Grenade(iEnt)
{
	if(entity_get_int(iEnt, EV_INT_modelindex) != g_iModelIndex_NailGrenade)
		return;
	
	static szClassName[22];
	entity_get_string(iEnt, EV_SZ_classname, szClassName, charsmax(szClassName));
	szClassName[21] = 0x00;
	
	if(!equal(szClassName, "tf_weapon_nailgrenade"))
		return;
	
	new Float:fOrigin[3];
	entity_get_vector(iEnt, EV_VEC_origin, fOrigin);
	entity_set_vector(iEnt, EV_VEC_oldorigin, fOrigin);
}

public fwd_SetOrigin_Post(iEnt, Float:fOrigin[3])
{
	static szClassName[22];
	entity_get_string(iEnt, EV_SZ_classname, szClassName, charsmax(szClassName));
	szClassName[21] = 0x00;
	
	if(equal(szClassName, "item_tfgoal"))
	{
		CheckSetOrigin_TFGoal_Post(iEnt, fOrigin);
		return;
	}
	
	static iModelIndex;
	iModelIndex = entity_get_int(iEnt, EV_INT_modelindex);
	
	if(iModelIndex == g_iModelIndex_NailGrenade && equal(szClassName, "tf_weapon_nailgrenade"))
	{
		CheckSetOrigin_NailGrenade_Post(iEnt, fOrigin);
		return;
	}
	
	if(iModelIndex == g_iModelIndex_MirvBomblet && equal(szClassName, "tf_weapon_mirvbomblet"))
	{
		CheckSetOrigin_MirvBomblet_Post(iEnt, fOrigin);
		return;
	}
}

CheckSetOrigin_TFGoal_Post(iEnt, const Float:fOrigin[3])
{
	if(engfunc(EngFunc_PointContents, fOrigin) != CONTENTS_SOLID)
		return;
	
	new iOwner = entity_get_edict(iEnt, EV_ENT_owner);
	if(!IsPlayer(iOwner))
		return;
	
	if(get_gametime() != g_fFlagTossTime[iOwner])
		return;
	
	// One might think setting origin within the SetOrigin forward would cause infinite recursion.. nope.
	entity_set_origin(iEnt, g_fFlagTossOrigin[iOwner]);
}

CheckSetOrigin_NailGrenade_Post(iEnt, Float:fOrigin[3])
{
	new Float:fOldOrigin[3];
	entity_get_vector(iEnt, EV_VEC_oldorigin, fOldOrigin);
	
	if(fOldOrigin[0] == 0.0 && fOldOrigin[1] == 0.0 && fOldOrigin[2] == 0.0)
		return;
	
	fOrigin[2] += 1.0;
	
	new trace = 0;
	engfunc(EngFunc_TraceLine, fOrigin, fOldOrigin, IGNORE_MONSTERS | IGNORE_MISSILE, iEnt, trace);
	
	new Float:fFraction;
	get_tr2(trace, TR_Fraction, fFraction);
	
	if(fFraction == 1.0 && !get_tr2(trace, TR_StartSolid))
		return;
	
	fOrigin[2] -= 1.0;
	
	new Float:fDist = vector_distance(fOrigin, fOldOrigin);
	if(fDist < 7.0)
		fOldOrigin[2] -= (7.0 - fDist);
	
	// Make sure the origin isn't in the floor now.
	trace = 0;
	engfunc(EngFunc_TraceLine, fOldOrigin, fOrigin, IGNORE_MONSTERS | IGNORE_MISSILE, iEnt, trace);
	
	// Only set the custom origin if it's not stuck in the floor.
	if(fFraction == 1.0 && !get_tr2(trace, TR_StartSolid))
		entity_set_origin(iEnt, fOldOrigin);
}

CheckSetOrigin_MirvBomblet_Post(iEnt, Float:fOrigin[3])
{
	if(!is_valid_ent(g_iLastMirvThinkEnt))
		return;
	
	new Float:fMirvOrigin[3];
	entity_get_vector(g_iLastMirvThinkEnt, EV_VEC_origin, fMirvOrigin);
	
	new trace = 0;
	engfunc(EngFunc_TraceLine, fOrigin, fMirvOrigin, IGNORE_MONSTERS | IGNORE_MISSILE, iEnt, trace);
	
	if(get_tr2(trace, TR_Hit) == g_iLastMirvThinkEnt)
		return;
	
	// The bomblets trace wasn't able to hit its mirv owner. Set the bomblets origin at the mirv's origin instead.
	entity_set_origin(iEnt, fMirvOrigin);
}

public fwd_TraceLine_Post(const Float:fV1[3], const Float:fV2[3], iIgnoreFlags, iEntToSkip, tr)
{
	if(!IsPlayer(iEntToSkip))
	{
		CheckTrace_GrenadeInSolid(iIgnoreFlags, iEntToSkip, tr);
		return;
	}
	
	if(!g_bCheckMedkitTrace[iEntToSkip])
		return;
	
	new iHit = get_tr(TR_pHit);
	if(!IsPlayer(iHit))
		return;
	
	// Since the medkit hit a player in TraceLine the game code won't run the tracehull, so set the medkit trace variable back to false now.
	g_bCheckMedkitTrace[iEntToSkip] = false;
}

CheckTrace_GrenadeInSolid(iIgnoreFlags, iEntToSkip, tr)
{
	// Grenade traces that hit players seem to always have no ignoreflags sets.
	if(iIgnoreFlags)
		return;
	
	// Return if the trace didn't start in a solid.
	if(!get_tr2(tr, TR_StartSolid))
		return;
	
	// Return if the trace didn't hit another entity.
	if(get_tr2(tr, TR_Hit) == -1)
		return;
	
	// Return if the ent to skip is not a grenade.
	static szClassName[11];
	entity_get_string(iEntToSkip, EV_SZ_classname, szClassName, charsmax(szClassName));
	szClassName[10] = 0x00;
	
	if(!equal(szClassName, "tf_weapon_"))
		return;
	
	// Simply setting StartSolid to 0 will fix the damage issue.
	set_tr2(tr, TR_StartSolid, 0);
}

public fwd_TraceHull_Post(const Float:fV1[3], const Float:fV2[3], iIgnoreFlags, iHullNumber, iEntToSkip, tr)
{
	if(!IsPlayer(iEntToSkip))
		return;
	
	// allow flags to be tossed even if a player is obstructing
	if(iHullNumber == 1)
	{
		set_tr2(tr, TR_flFraction, 1.0);
	}
	else if(iHullNumber == 3)
	{
		if(!g_bCheckMedkitTrace[iEntToSkip])
			return;
		
		g_bCheckMedkitTrace[iEntToSkip] = false;
		
		new iHit = get_tr(TR_pHit);
		if(!IsPlayer(iHit))
			return;
	}
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= g_iMaxPlayers)
		return true;
	
	return false;
}
