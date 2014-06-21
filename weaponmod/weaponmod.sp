#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <phun>
#include <weaponmod>

#pragma semicolon 1

#define MAX_CUSTOM_WEAPONS	2
#define MAX_SZ_DATA			wpn_max_string
#define MAX_SZ_LENGTH		128
#define MAX_FL_DATA			wpn_max_float
#define MAX_INT_DATA		wpn_max_integer
#define MAX_EV_DATA			wpn_max_event


#define EF_NODRAW 32

// Weapons DATA
new String:	g_szWPN	[MAX_CUSTOM_WEAPONS][MAX_SZ_DATA][MAX_SZ_LENGTH];
new Float:	g_flWPN	[MAX_CUSTOM_WEAPONS][MAX_FL_DATA];
new 		g_intWPN[MAX_CUSTOM_WEAPONS][MAX_INT_DATA];
new Handle:	g_hWPN	[MAX_CUSTOM_WEAPONS][MAX_EV_DATA];
// Users DATA
new Float:	g_flUserWPN	[65][MAX_CUSTOM_WEAPONS][MAX_FL_DATA];
new			g_intUserWPN[65][MAX_CUSTOM_WEAPONS][MAX_INT_DATA];
//

new g_iWpnCount = -1;

new const String:WPN_LIMIT_REACHED[] = "WeaponsMOD: Couldn't register weapon '%s' - Limit reached";
new const String:WPN_INVALID_WPNID[] = "WeaponsMOD: Invalid weaponID '%d' called by plugin '%s' (%s)";
new const String:WPN_INVALID_DATA[] = "WeaponsMOD: Invalid dataID '%d' called by plugin '%s' (%s)";


new bool:SpawnCheck[MAXPLAYERS+1];
new ClientVM[MAXPLAYERS+1][2];
new bool:IsCustom[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "WeaponMOD - Core",
	author = "KoSSoLaX",
	description = "Custom Weapon Module - CORE",
	version = "1.0",
	url = "http://www.ts-x.eu"
}
new g_cBloodModel, g_cSprayModel;

public OnMapStart() {
	g_cBloodModel = PrecacheModel("sprites/blood.vmt", true);
	g_cSprayModel = PrecacheModel("sprites/bloodspray.vmt", true);
}
public OnPluginStart() {
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	for(new client = 1; client <= MaxClients; client++) {
		
		if( IsValidClient(client) ) {
			
			SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
			
			//find both of the clients viewmodels
			ClientVM[client][0] = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
			
			new PVM = -1;
			while ((PVM = FindEntityByClassname(PVM, "predicted_viewmodel")) != -1) {
				
				if (GetEntPropEnt(PVM, Prop_Send, "m_hOwner") == client) {
					
					if (GetEntProp(PVM, Prop_Send, "m_nViewModelIndex") == 1) {
						
						ClientVM[client][1] = PVM;
						break;
					}
				}
			}
		} 
	}
}
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vec[3], Float:ang[3], &weapon, &subtype) {
	if( IsCustom[client] ) {
		new WeaponIndex = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( IsValidEdict(WeaponIndex) ) {
			decl String:classname[32];
			GetEdictClassname(WeaponIndex, classname, sizeof(classname));
			
			for(new wpnID=0;wpnID<=g_iWpnCount; wpnID++) {
				if (StrEqual(g_szWPN[wpnID][wpn_replacement], classname, false) ) {
					
					SetEntPropFloat(WeaponIndex, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 2.5 );
					SetEntPropFloat(WeaponIndex, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 2.5 );
					
					if( g_flUserWPN[client][ wpnID ][ wpn_refireRate1 ] < GetGameTime() &&
						g_flUserWPN[client][ wpnID ][ wpn_refireRate2 ] < GetGameTime()
						) {
							
							
						if( buttons & IN_ATTACK ) {
							g_flUserWPN[ client ][ wpnID ][ wpn_refireRate1 ] = GetGameTime() + g_flWPN[ wpnID ][ wpn_refireRate1 ];
							CallForward(client, wpnID, wpn_evAttack1);							
							continue;
						}
						if( buttons & IN_ATTACK2 ) {
							g_flUserWPN[client][ wpnID ][ _:wpn_refireRate2 ] = GetGameTime() + g_flWPN[ wpnID ][ _:wpn_refireRate2 ];
							CallForward(client, wpnID, wpn_evAttack2);
							continue;
						}			
					}
					break;
				}
			}
		}
	}
	
	return Plugin_Continue;
}
public CallForward(client, wpnID, wpn_event:wpnData) {
	Call_StartForward(g_hWPN[wpnID][wpnData]);
	Call_PushCell(client);
	Call_Finish();
}
public OnClientPutInServer(client) {
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}
public OnEntityCreated(entity, const String:classname[]) {
	if( StrEqual(classname, "predicted_viewmodel", false) ) {
		SDKHook(entity, SDKHook_Spawn, OnEntitySpawned);
	}
}
public OnEntitySpawned(entity) {
	
	//find both of the clients viewmodels
	new Owner = GetEntPropEnt(entity, Prop_Send, "m_hOwner");
	if( (Owner > 0) && (Owner <= MaxClients) ) {
		if (GetEntProp(entity, Prop_Send, "m_nViewModelIndex") == 0) {
			ClientVM[Owner][0] = entity;
		}
		else if (GetEntProp(entity, Prop_Send, "m_nViewModelIndex") == 1) {
			ClientVM[Owner][1] = entity;
		}
	}
}

//hide viewmodel on death
public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	new UserId = GetEventInt(event, "userid");
	new client = GetClientOfUserId(UserId);
	
	hideViewModel(ClientVM[client][1]);
}

//when a player repsawns at round start after surviving previous round the viewmodel is unhidden
public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new UserId = GetEventInt(event, "userid");
	new client = GetClientOfUserId(UserId);
	
	//use to delay hiding viewmodel a frame or it won't work
	SpawnCheck[client] = true;
}


public OnPostThinkPost(client) {

	static OldWeapon[MAXPLAYERS + 1];
	static OldSequence[MAXPLAYERS + 1];
	static Float:OldCycle[MAXPLAYERS + 1];
	
	if( !IsValidClient(client) )
		return;
	
	decl String:classname[32];
	new WeaponIndex;
	
	//handle spectators
	
	if( !IsPlayerAlive(client) ) {
		
		new spec = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		if (spec != -1) {
			
			WeaponIndex = GetEntPropEnt(spec, Prop_Send, "m_hActiveWeapon");
			GetEdictClassname(WeaponIndex, classname, sizeof(classname));
			
			for(new wpnID=0;wpnID<=g_iWpnCount; wpnID++) {
				if (StrEqual(g_szWPN[wpnID][wpn_replacement], classname, false) ) {
					SetEntProp(ClientVM[client][1], Prop_Send, "m_nModelIndex", g_intWPN[wpnID][wpn_viewmodel]);
				}
			}
		}
		
		return;
	}
	
	
	
	if( ClientVM[client][0] )
		return;
	
	WeaponIndex = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	GetEdictClassname(ClientVM[client][0], classname, sizeof(classname));
	if( StrEqual(classname, "predicted_viewmodel", false) ) {
		new Sequence = GetEntProp(ClientVM[client][0], Prop_Send, "m_nSequence");
		new Float:Cycle = GetEntPropFloat(ClientVM[client][0], Prop_Data, "m_flCycle");
		
		if (WeaponIndex <= 0) {
			// Pas d'arme, pas de skin à afficher
			showViewModel(ClientVM[client][0]);
			hideViewModel(ClientVM[client][1]);
			
			IsCustom[client] = false;
			
			OldWeapon[client] = WeaponIndex;
			OldSequence[client] = Sequence;
			OldCycle[client] = Cycle;
			
			return;
		}
		
		//just stuck the weapon switching in here aswell instead of a separate hook
		if( WeaponIndex != OldWeapon[client] ) {
			
			GetEdictClassname(WeaponIndex, classname, sizeof(classname));
			
			for(new wpnID=0;wpnID<=g_iWpnCount; wpnID++) {
				
				if (StrEqual(g_szWPN[wpnID][wpn_replacement], classname, false) ) {
					
					if( !IsValidEdict(ClientVM[client][1]) )
						continue;
					
					hideViewModel(ClientVM[client][0]);
					showViewModel(ClientVM[client][1]);
					
					SetEntProp(WeaponIndex, Prop_Send, "m_iWorldModelIndex",	g_intWPN[wpnID][wpn_worldmodel]);
					SetEntProp(WeaponIndex, Prop_Send, "m_nModelIndex",			g_intWPN[wpnID][wpn_worldmodel]);
					SetEntityRenderColor(WeaponIndex,	255, 255, 255, 255);
					SetEntityRenderMode(WeaponIndex,	RENDER_TRANSCOLOR);
					
					SetEntProp(ClientVM[client][1], Prop_Send, "m_nModelIndex",	g_intWPN[wpnID][wpn_viewmodel]);
					
					
					SetEntPropEnt(ClientVM[client][1], Prop_Send, "m_hWeapon", GetEntPropEnt(ClientVM[client][0], Prop_Send, "m_hWeapon"));
					copySequence(ClientVM[client][1], ClientVM[client][0]);
					IsCustom[client] = true;
					break;
				}
				else {
					
					hideViewModel(ClientVM[client][1]);				
					IsCustom[client] = false;
				}
			}
		}
		else {
			copySequence(ClientVM[client][1], ClientVM[client][0]);
		}
		
		//hide viewmodel a frame after spawning
		if( SpawnCheck[client]) {
			SpawnCheck[client] = false;
			if( IsCustom[client] ) {
				hideViewModel(ClientVM[client][0]);
				showViewModel(ClientVM[client][1]);
			}
		}
		
		OldWeapon[client] = WeaponIndex;
		OldSequence[client] = Sequence;
		OldCycle[client] = Cycle;
	}
}
public copySequence(dst, src) {
	if( !IsValidEdict(dst) || !IsValidEdict(src) )
		return;
	
	SetEntProp(		dst, Prop_Send, "m_nSequence",		GetEntProp(src, Prop_Send, "m_nSequence"));
	//SetEntPropFloat(dst, Prop_Send, "m_flPlaybackRate",	GetEntPropFloat(src, Prop_Send, "m_flPlaybackRate"));
}
public hideViewModel(id) {
	if( !IsValidEdict(id) )
		return;
	
	new EntEffects = GetEntProp(id, Prop_Send, "m_fEffects");
	EntEffects |= EF_NODRAW;
	SetEntProp(id, Prop_Send, "m_fEffects", EntEffects);
}
public showViewModel(id) {
	if( !IsValidEdict(id) )
		return;
	
	new EntEffects = GetEntProp(id, Prop_Send, "m_fEffects");
	EntEffects &= ~EF_NODRAW;
	SetEntProp(id, Prop_Send, "m_fEffects", EntEffects);	
}
// ------------------------------------------------------------------------------------------
//
//				Natives
//
// ------------------------------------------------------------------------------------------

public ScheduleEntityInput( entity, Float:time, const String:input[]) {
	
	if( !IsValidEdict(entity) )
		return;
	if( !IsValidEntity(entity) )
		return;

	new Handle:dp;
	CreateDataTimer( time, ScheduleTargetInput_Task, dp, TIMER_DATA_HNDL_CLOSE); 
	WritePackCell(dp, EntIndexToEntRef(entity));
	WritePackString(dp, input);
}
public ScheduleTargetInput( const String:targetname[], Float:time, const String:input[]) {
	for(new i=1; i<=2048; i++) {
		if( !IsValidEdict(i) )
			continue;
		if( !IsValidEntity(i) )
			continue;
		
		new String:i_targetname[128];
		GetEntPropString(i, Prop_Data, "m_iName", i_targetname, sizeof(i_targetname));
		
		if( !StrEqual(targetname, i_targetname, false) )
			continue;
		
		new Handle:dp;
		CreateDataTimer( time, ScheduleTargetInput_Task, dp, TIMER_DATA_HNDL_CLOSE); 
		WritePackCell(dp, EntIndexToEntRef(i));
		WritePackString(dp, input);
	}
}
public Action:ScheduleTargetInput_Task(Handle:timer, Handle:dp) {
	new entity, String:input[128];
	
	ResetPack(dp);
	
	entity = EntRefToEntIndex(ReadPackCell(dp));
	ReadPackString(dp, input, 127);
	
	if( entity == INVALID_ENT_REFERENCE ) 
		return Plugin_Handled;
	if( entity <= 0 )
		return Plugin_Handled;
	if( !IsValidEdict(entity) )
		return Plugin_Handled;
	if( !IsValidEntity(entity) )
		return Plugin_Handled;
	
	AcceptEntityInput(entity, input);
	return Plugin_Handled;
}








public APLRes:AskPluginLoad2(Handle:hPlugin, bool:isAfterMapLoaded, String:error[], err_max) {
	
	CreateNative("wpnRegisterWeapon", 	Native_wpnRegisterWeapon);
	
	CreateNative("wpnSetString",		Native_wpnSetString);
	CreateNative("wpnGetString",		Native_wpnGetString);

	CreateNative("wpnSetInt",			Native_wpnSetInt);
	CreateNative("wpnGetInt",			Native_wpnGetInt);
	
	CreateNative("wpnSetFloat",			Native_wpnSetFloat);
	CreateNative("wpnGetFloat",			Native_wpnGetFloat);
	
	CreateNative("wpnRegisterEvent",	Native_wpnRegisterEvent);
	
	CreateNative("wpnPlayAnim",			Native_wpnPlayAnim);
	
	CreateNative("wpnCACdamage",		NativE_wpnCACdamage);
}
// native wpnPlayAnim( weaponID, anim );
public NativE_wpnCACdamage(Handle:plugin, numParams) {
	new wpnID = GetNativeCell(1);
	new client = GetNativeCell(2);
	new from = GetNativeCell(3);
	new Float:dmg = Float:GetNativeCell(4);
	
	if( wpnID ) {
	}
	
	new Float:f_Origin_1[3], Float:f_Origin_2[3], Float:distance;
	
	GetClientEyePosition(from, f_Origin_1);
	GetClientEyeAngles(client, f_Origin_2);
	
	new Handle:tr = TR_TraceRayFilterEx(f_Origin_1, f_Origin_2, MASK_SOLID, RayType_Infinite, FilterToOne, client);
	if( TR_DidHit(tr) ) {
		new target = TR_GetEntityIndex(tr);
		
		if( IsMoveAble(target) ) {
			TR_GetEndPosition(f_Origin_2, tr);
			distance = GetVectorDistance(f_Origin_1, f_Origin_2);
			
			if( distance <= 64.0 ) {
				SDKHooks_TakeDamage(target, client, client, dmg, DMG_CRUSH);
				
				TE_SetupBloodSprite(f_Origin_2, Float:{0.0, 0.0, -1.0}, {255, 0, 0, 250}, RoundFloat(dmg/6.6), g_cSprayModel, g_cBloodModel);
				TE_SendToAll();
				
				
				bloodSpray(client, target, RoundFloat(dmg/6.6));				
			}
		}
	}
	CloseHandle(tr);
}
stock bloodSpray(client, target, amount = 5) {
	
	for(new i=0; i<=amount; i++) {
		new String:fmt[64];
		Format(fmt, sizeof(fmt), "decals/blood%d.vmt", GetRandomInt(1, 8));
		
		new precache = PrecacheDecal(fmt, true);
		
		new Float:pos[3];
		Entity_GetAbsOrigin(target, pos);
		pos[0] += GetRandomFloat(-32.0, 32.0);
		pos[1] += GetRandomFloat(-32.0, 32.0);
		
		
		TE_Start("World Decal");
		TE_WriteVector("m_vecOrigin",pos);
		TE_WriteNum("m_nIndex", precache);
		TE_SendToAll();
	}	
}
public Native_wpnPlayAnim(Handle:plugin, numParams) {
	new client = GetNativeCell(1);
	
	SetEntProp(ClientVM[client][0], Prop_Send, "m_nSequence", GetNativeCell(2));
	SetEntProp(ClientVM[client][1], Prop_Send, "m_nSequence", GetNativeCell(2));
	
	SetEntPropFloat(ClientVM[client][0], Prop_Send, "m_flPlaybackRate", 1.0);
	SetEntPropFloat(ClientVM[client][1], Prop_Send, "m_flPlaybackRate", 1.0);
	
	SetEntPropFloat(ClientVM[client][0], Prop_Data, "m_flCycle", 1.0);
	SetEntPropFloat(ClientVM[client][1], Prop_Data, "m_flCycle", 1.0);	
}
// native wpnRegisterWeapon(const String:replace[], const String:longname[], const String:shortname[]);
public Native_wpnRegisterWeapon(Handle:plugin, numParams) {
	
	decl String:buffer[64];
	GetNativeString(2, buffer, sizeof(buffer));
	
	if( g_iWpnCount >= MAX_CUSTOM_WEAPONS )
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_LIMIT_REACHED, buffer);
	
	g_iWpnCount++;
	
	GetNativeString(1, g_szWPN[g_iWpnCount][wpn_replacement],MAX_SZ_LENGTH);
	GetNativeString(2, g_szWPN[g_iWpnCount][wpn_longName], 	MAX_SZ_LENGTH);
	GetNativeString(3, g_szWPN[g_iWpnCount][wpn_shortName],	MAX_SZ_LENGTH);
	
	for(new i=0; i<_:MAX_EV_DATA; i++) {
		g_hWPN[g_iWpnCount][i] = CreateForward(ET_Event, Param_Cell, Param_Cell);
	}
	
	LogToGame("[WeaponMod] WeaponID: %d - %s created as %s.", g_iWpnCount, g_szWPN[g_iWpnCount][wpn_longName], g_szWPN[g_iWpnCount][wpn_replacement]);
	return g_iWpnCount;
}
// native wpnSetString( weaponID, wpn_string:stringID, const String:str[]);
public Native_wpnSetString(Handle:plugin, numParams) {
	
	new wepID = GetNativeCell(1);
	decl String:buffer[64], String:buffer2[64];
	
	GetPluginFilename(plugin, buffer, sizeof(buffer));
	GetPluginInfo(plugin, PlInfo_Name, buffer2, sizeof(buffer2));
	
	if( wepID > MAX_CUSTOM_WEAPONS	||	wepID > g_iWpnCount ||	wepID < 0	) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_WPNID, wepID, buffer, buffer2);
	}
	
	new wpn_string:wpnData = GetNativeCell(2);
	if( _:wpnData < 0 ||	wpnData > MAX_SZ_DATA ) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_DATA, _:wpnData, buffer, buffer2);
	}
	
	GetNativeString(3, g_szWPN[wepID][wpnData], MAX_SZ_LENGTH);
	return 1;
}
// native wpnGetString( weaponID, wpn_string:stringID, const String:str[]);
public Native_wpnGetString(Handle:plugin, numParams) {
	
	new wepID = GetNativeCell(1);
	decl String:buffer[64], String:buffer2[64];
	
	GetPluginFilename(plugin, buffer, sizeof(buffer));
	GetPluginInfo(plugin, PlInfo_Name, buffer2, sizeof(buffer2));
	
	if( wepID > MAX_CUSTOM_WEAPONS	||	wepID > g_iWpnCount ||	wepID < 0	) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_WPNID, wepID, buffer, buffer2);
	}
	
	new wpn_string:wpnData = GetNativeCell(2);
	if( _:wpnData < 0 ||	wpnData > MAX_SZ_DATA ) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_DATA, _:wpnData, buffer, buffer2);
	}
	
	SetNativeString(3, g_szWPN[wepID][wpnData], MAX_SZ_LENGTH);
	return 1;
}

// native wpnSetInt( weaponID, wpn_integer:intID, int);
public Native_wpnSetInt(Handle:plugin, numParams) {
	
	new wepID = GetNativeCell(1);
	decl String:buffer[64], String:buffer2[64];
	
	GetPluginFilename(plugin, buffer, sizeof(buffer));
	GetPluginInfo(plugin, PlInfo_Name, buffer2, sizeof(buffer2));
	
	if( wepID > MAX_CUSTOM_WEAPONS	||	wepID > g_iWpnCount ||	wepID < 0	) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_WPNID, wepID, buffer, buffer2);
	}
	
	new wpn_integer:wpnData = GetNativeCell(2);
	if( _:wpnData < 0 || wpnData > MAX_INT_DATA ) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_DATA, _:wpnData, buffer, buffer2);
	}
	
	g_intWPN[wepID][wpnData] = _:GetNativeCell(3);
	
	return 1;
}
// native wpnGetInt( weaponID, wpn_integer:intID);
public Native_wpnGetInt(Handle:plugin, numParams) {
	
	new wepID = GetNativeCell(1);
	decl String:buffer[64], String:buffer2[64];
	
	GetPluginFilename(plugin, buffer, sizeof(buffer));
	GetPluginInfo(plugin, PlInfo_Name, buffer2, sizeof(buffer2));
	
	if( wepID > MAX_CUSTOM_WEAPONS	||	wepID > g_iWpnCount ||	wepID < 0	) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_WPNID, wepID, buffer, buffer2);
	}
	
	new wpn_integer:wpnData = GetNativeCell(2);
	if( _:wpnData < 0 || wpnData > MAX_INT_DATA ) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_DATA, _:wpnData, buffer, buffer2);
	}
	
	return _:g_intWPN[wepID][wpnData];
}


// native wpnSetFloat( weaponID, wpn_float:floatID, Float:flt);
public Native_wpnSetFloat(Handle:plugin, numParams) {
	
	new wepID = GetNativeCell(1);
	decl String:buffer[64], String:buffer2[64];
	
	GetPluginFilename(plugin, buffer, sizeof(buffer));
	GetPluginInfo(plugin, PlInfo_Name, buffer2, sizeof(buffer2));
	
	if( wepID > MAX_CUSTOM_WEAPONS	||	wepID > g_iWpnCount ||	wepID < 0	) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_WPNID, wepID, buffer, buffer2);
	}
	
	new wpn_float:wpnData = GetNativeCell(2);
	if( _:wpnData < 0 || wpnData > MAX_FL_DATA ) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_DATA, _:wpnData, buffer, buffer2);
	}
	
	g_flWPN[wepID][wpnData] = Float:GetNativeCell(3);
	
	return 1;
}
// native Float:wpnGetFloat( weaponID, wpn_float:floatID);
public Native_wpnGetFloat(Handle:plugin, numParams) {
	
	new wepID = GetNativeCell(1);
	decl String:buffer[64], String:buffer2[64];
	
	GetPluginFilename(plugin, buffer, sizeof(buffer));
	GetPluginInfo(plugin, PlInfo_Name, buffer2, sizeof(buffer2));
	
	if( wepID > MAX_CUSTOM_WEAPONS	||	wepID > g_iWpnCount ||	wepID < 0	) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_WPNID, wepID, buffer, buffer2);
	}
	
	new wpn_float:wpnData = GetNativeCell(2);
	if( _:wpnData < 0 || wpnData > MAX_FL_DATA ) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_DATA, _:wpnData, buffer, buffer2);
	}
	
	
	return _:g_flWPN[wepID][wpnData];
}

// native wpnRegisterEvent(weaponid, wpn_event:eventID, function[]);
public Native_wpnRegisterEvent(Handle:plugin, numParams) {
	// fwdId = CreateOneForward(g_int_wpn[wpnid][wpn_pluginid], func, FP_CELL, FP_CELL)
	
	new wepID = GetNativeCell(1);
	decl String:buffer[64], String:buffer2[64];
	
	GetPluginFilename(plugin, buffer, sizeof(buffer));
	GetPluginInfo(plugin, PlInfo_Name, buffer2, sizeof(buffer2));
	
	if( wepID > MAX_CUSTOM_WEAPONS	||	wepID > g_iWpnCount ||	wepID < 0	) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_WPNID, wepID, buffer, buffer2);
	}
	
	new wpn_event:wpnData = GetNativeCell(2);
	if( _:wpnData < 0 || wpnData > MAX_EV_DATA ) {
		return ThrowNativeError(SP_ERROR_NATIVE, WPN_INVALID_DATA, _:wpnData, buffer, buffer2);
	}
	
	return AddToForward(g_hWPN[g_iWpnCount][wpnData], plugin, Function:GetNativeCell(3));
}
// native wpn_bulletShot(weaponid, attacker, dmg_save, dmg_take);
// native wpn_playAnim(player, animation);
// native wpn_damageUser(weaponid, victim, attacker, dmg_save, dmg_take, dmg_type, hitplace=0);
// native wpn_radiusDamage(weaponid, attacker, inflictor, Float:range, Float:damage, damageType);
