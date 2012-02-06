#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <phun>
#include <smlib>
#include <weaponmod>

public Plugin:myinfo = 
{
	name = "WeaponMOD: Core",
	author = "KoSSoLaX`",
	description = "WeaponMOD: Coeur du système d'arme personnalisée",
	version = "0.1b",
	url = "http://www.ts-x.eu/"
}

#define MAX_WEAPON			12
#define MAX_STRINGSIZE		64
#define USING_WEAPON		"weapon_tmp"


new g_iWeaponRegistered[ MAX_WEAPON ];

new g_iWeaponData[ MAX_WEAPON ][ wpn_int_max ];
new Float:g_flWeaponData[ MAX_WEAPON ][ wpn_float_max ];
new String:g_szWeaponData[ MAX_WEAPON ][ wpn_string_max ][ MAX_STRINGSIZE ];
new Handle:g_hWeaponData[ MAX_WEAPON ][ wpn_event_max ];
new g_iWpnCount = 0;

new g_icWeaponData[ MAX_WEAPON ][ wpn_ic_max ][ 65 ];
new Float:g_fcWeaponData[ MAX_WEAPON ][ wpn_fc_max ][ 65 ];

new g_cWeapon[ 65 ];

new g_cScorch = -1;
new g_cExplode = -1;

// -----------------------------------------------------------------------------------------------
//
public OnPluginStart() {
	RegAdminCmd("wm_giveweapon", CmdAdminGiveWeapon, ADMFLAG_BAN, "wm_giveweapon<weaponID>");
}
public OnMapStart() {
	g_cScorch = PrecacheModel("materials/decals/smscorch1.vmt", true);
	g_cExplode = PrecacheModel("materials/sprites/old_aexplo.vmt", true);
	
	PrecacheSound("weapons/explode3.wav", true);
	PrecacheSound("weapons/explode4.wav", true);
	PrecacheSound("weapons/explode5.wav", true);
}
public Action:CmdAdminGiveWeapon(client, args) {
	
	GivePlayerItem(client, USING_WEAPON);
	
	new String:arg1[12];
	GetCmdArg(1, arg1, sizeof(arg1));
	new wpnid = StringToInt(arg1);
	
	g_cWeapon[client] = wpnid;
	
	g_icWeaponData[wpnid][ wpn_ic_ammo1 ][client] = g_iWeaponData[wpnid][wpn_int_ammo1];
	g_icWeaponData[wpnid][ wpn_ic_ammo2 ][client] = g_iWeaponData[wpnid][wpn_int_ammo2];
	
	return Plugin_Handled;
}
// -----------------------------------------------------------------------------------------------
//			FRAME
public OnGameFrame() {
	
	for(new client=1; client<=GetMaxClients(); client++) {
		if( !IsValidClient(client) )
			continue;
		
		if( !IsPlayerAlive(client) )
			continue;
		
		if( GetClientTeam(client) != CS_TEAM_CT && GetClientTeam(client) != CS_TEAM_T )
			continue;
		
		new WeaponIndex = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		new String:WeaponName[64]; GetEdictClassname(WeaponIndex, WeaponName, 63);
		
		new ent = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
		
		new wpnid = g_cWeapon[client];
		
		if( StrEqual(WeaponName, USING_WEAPON, false) && wpnid >= 1 ) {
			
			
			if( g_icWeaponData[wpnid][wpn_ic_entity1][client] <= GetMaxClients() || !IsValidEdict( g_icWeaponData[wpnid][wpn_ic_entity1][client] ) || !IsValidEntity( g_icWeaponData[wpnid][wpn_ic_entity1][client] ) ) {
				
				ent = CreateEntityByName("prop_dynamic");
				SetEntityModel(ent, g_szWeaponData[wpnid][wpn_string_model]);
				
				if( GetClientTeam(client) == CS_TEAM_CT ) {
					DispatchKeyValue(ent, "Skin", "1");
				}
				
				DispatchKeyValue(ent, "disableshadows", "1");
				DispatchKeyValue(ent, "nodamageforces", "1");
				DispatchKeyValue(ent, "spawnflags", "6");
				
				DispatchSpawn(ent);
				
				new String:ParentName[128];
				Format(ParentName, sizeof(ParentName), "wpn_%s_%i%i%i", g_szWeaponData[wpnid][wpn_string_shortname], ent, client, GetRandomInt(11111, 99999) );
				DispatchKeyValue(client, "targetname", ParentName);
				
				SetVariantString(ParentName);
				AcceptEntityInput(ent, "SetParent");
				
				SetVariantString("muzzle_flash");
				AcceptEntityInput(ent, "SetParentAttachment");
				
				new Float:pos[3], Float:dir[3];
				SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
				SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
				pos[0] = -5.0;	pos[1] = -20.0;	pos[2] = 5.0;
				dir[0] = 15.0;	dir[1] = 40.0;	dir[2] = -20.0;
				
				TeleportEntity(ent, pos, dir, NULL_VECTOR);
				
				g_icWeaponData[wpnid][wpn_ic_entity1][client] = ent;
			}
			SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
			
			SetEntityRenderMode(WeaponIndex, RENDER_TRANSCOLOR);
			SetEntityRenderColor(WeaponIndex, 0, 0, 0, 0);
			
			SetEntPropFloat(WeaponIndex, Prop_Send, "m_flNextPrimaryAttack", (GetGameTime()+5.0));
			
			Client_SetWeaponAmmo(client, USING_WEAPON, g_icWeaponData[wpnid][wpn_ic_ammo2][client], g_icWeaponData[wpnid][wpn_ic_ammo2][client], g_icWeaponData[wpnid][wpn_ic_ammo1][client], g_icWeaponData[wpnid][wpn_ic_ammo1][client]);
		}
		else {
			
			if( GetEntProp(client, Prop_Send, "m_bDrawViewmodel") != 1 )
				SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
			
			if( g_icWeaponData[wpnid][wpn_ic_entity1][client] >= GetMaxClients() && IsValidEdict( g_icWeaponData[wpnid][wpn_ic_entity1][client] ) && IsValidEntity( g_icWeaponData[wpnid][wpn_ic_entity1][client] ) ) {
				AcceptEntityInput(g_icWeaponData[wpnid][wpn_ic_entity1][client], "Kill");
			}
			g_icWeaponData[wpnid][wpn_ic_entity1][client] = -1;
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if( !IsValidClient(client) )
		return Plugin_Continue;
	
	if( !IsPlayerAlive(client) )
		return Plugin_Continue;
	
	if( GetClientTeam(client) != CS_TEAM_CT && GetClientTeam(client) != CS_TEAM_T )
		return Plugin_Continue;
	
	new WeaponIndex = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	new String:WeaponName[64]; GetEdictClassname(WeaponIndex, WeaponName, 63);
	
	new wpnid = g_cWeapon[client];
	
	if( StrEqual(WeaponName, USING_WEAPON, false) && wpnid >= 1 ) {
		
		if( buttons & IN_ATTACK ) {
			
			if( g_fcWeaponData[wpnid][wpn_fc_refire][client] > GetGameTime() ) {
				return Plugin_Continue;
			}
			
			g_fcWeaponData[wpnid][wpn_fc_refire][client] = (Float:GetGameTime() + Float:g_flWeaponData[wpnid][wpn_float_refire_rate1]);
			
			if( g_icWeaponData[wpnid][wpn_ic_ammo1][client] <= 0 ) {
				return Plugin_Continue;
			}
			
			g_icWeaponData[wpnid][wpn_ic_ammo1][client]--;
			
			if( Handle:g_hWeaponData[wpnid][wpn_event_attack1] == INVALID_HANDLE ) {
				return Plugin_Continue;
			}
			
			Call_StartForward( Handle:g_hWeaponData[wpnid][wpn_event_attack1] );
			Call_PushCell(client);
			Call_Finish();
		}
		if( buttons & IN_ATTACK2 ) {
			
			if( g_fcWeaponData[wpnid][wpn_fc_refire][client] > GetGameTime() ) {
				return Plugin_Continue;
			}
			
			g_fcWeaponData[wpnid][wpn_fc_refire][client] = (Float:GetGameTime() + Float:g_flWeaponData[wpnid][wpn_float_refire_rate2]);
			
			if( g_icWeaponData[wpnid][wpn_ic_ammo1][client] <= 0 ) {
				return Plugin_Continue;
			}
			
			g_icWeaponData[wpnid][wpn_ic_ammo1][client]--;
			
			if( Handle:g_hWeaponData[wpnid][wpn_event_attack2] == INVALID_HANDLE ) {
				return Plugin_Continue;
			}
			
			Call_StartForward( Handle:g_hWeaponData[wpnid][wpn_event_attack2] );
			Call_PushCell(client);
			Call_Finish();
		}
		if( buttons & IN_RELOAD ) {
			
			g_fcWeaponData[wpnid][wpn_fc_refire][client] = (Float:GetGameTime() + Float:g_flWeaponData[wpnid][wpn_float_reload]);
			
			if( g_icWeaponData[wpnid][wpn_ic_ammo2][client] <= 0 ) {
				return Plugin_Continue;
			}
			
			g_icWeaponData[wpnid][ wpn_ic_ammo1 ][client] = g_iWeaponData[wpnid][wpn_int_ammo1];
			g_icWeaponData[wpnid][wpn_ic_ammo2][client]--;
			
			if( Handle:g_hWeaponData[wpnid][wpn_event_reload] == INVALID_HANDLE ) {
				return Plugin_Continue;
			}
			
			Call_StartForward( Handle:g_hWeaponData[wpnid][wpn_event_reload] );
			Call_PushCell(client);
			Call_Finish();
		}
	}
	
	return Plugin_Continue;
}
// -----------------------------------------------------------------------------------------------
//			NATIVES
public APLRes:AskPluginLoad2(Handle:hPlugin, bool:isAfterMapLoaded, String:error[], err_max) {
	
	CreateNative("WM_RegisterWeapon", 	Native_WM_RegisterWeapon);
	
	CreateNative("WM_SetInt",			Native_WM_SetInt);
	CreateNative("WM_SetFloat",			Native_WM_SetFloat);
	CreateNative("WM_SetString",		Native_WM_SetString);
	CreateNative("WM_RegisterEvent",	Native_WM_RegisterEvent);
	
	CreateNative("ScheduleEntityInput",	Native_ScheduleEntityInput);
	CreateNative("ExplosionDamage",		Native_ExplosionDamage);
	return APLRes_Success;
}
public Native_ExplosionDamage(Handle:plugin, numParams) {
	
	new Float:origin[3];
	GetNativeArray(1, Float:origin, sizeof(origin));
	
	new Float:damage = Float:GetNativeCell(2);
	new Float:lenght = Float:GetNativeCell(3);
	new index = GetNativeCell(4);
	
	new Float:PlayerVec[3], Float:distance, Float:falloff = (damage/lenght);
	
	new Float:min[3] = { -8.0, -8.0, -8.0};
	new Float:max[3] = {  8.0,  8.0,  8.0};
	new Float:origin2[3], Float:normal[3];
	
	new Handle:tr = TR_TraceHullFilterEx(origin, origin, min, max, MASK_SHOT, WM_TraceEntityFilterStuff);
	TR_GetPlaneNormal(tr, normal);
	TR_GetEndPosition(origin2, tr);
	
	CloseHandle(tr);
	
	if( GetVectorDistance(origin, origin2) <= 32.0 ) {
		origin[0] = origin2[0];
		origin[1] = origin2[1];
		origin[2] = origin2[2];
	}
	
	TE_SetupExplosion(origin, g_cExplode, 1.0, 1, 0, RoundFloat(lenght), RoundFloat(lenght), normal);
	TE_SendToAll();
	
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", origin);
	TE_WriteNum("m_nIndex", g_cScorch);
	TE_SendToAll();
	
	
	for(new i=1; i<=GetMaxEntities(); i++) {
		if( !IsValidEdict(i) )
			continue;
		if( !IsValidEntity(i) )
			continue;
		if( !IsMoveAble(i) )
			continue;
		
		if( IsValidClient(i) ) {
			GetClientEyePosition(i, PlayerVec);
		}
		else {
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", PlayerVec);
		}
		
		
		distance = GetVectorDistance(origin, PlayerVec) * falloff;
		
		new Float:dmg = (damage - distance);		
		
		TR_TraceRayFilter(origin, PlayerVec, MASK_SHOT, RayType_EndPoint, WM_TraceEntityFilterStuff);
		new Float:fraction = (TR_GetFraction()) * 1.5;
		
		if( TR_GetEntityIndex() == i )
			fraction = 1.0;
		
		if( fraction > 1.0 )
			fraction = 1.0;
		if( fraction < 0.0 )
			fraction = 0.0;
		
		dmg *= fraction;
		
		if( dmg < 0.0 )
			continue;
		
		if( IsValidClient(i) ) {
			if( i == index || GetClientTeam(i) == GetClientTeam(index) ) {
				dmg *= 0.65;
			}
		}
		
		
		DealDamage(i, RoundFloat(dmg), index);
	}
	MakeRadiusPush2(origin, lenght, (damage * 10.0));
}
public Native_ScheduleEntityInput(Handle:plugin, numParams) {
	new entity = _:GetNativeCell(1);
	new Float:time = Float:GetNativeCell(2);
	new String:input[128];
	GetNativeString(3, input, sizeof(input));
	
	if( !IsValidEdict(entity) )
		return;
	if( !IsValidEntity(entity) )
		return;
	
	new Handle:dp;
	CreateDataTimer( time, ScheduleTargetInput_Task, dp); 
	WritePackCell(dp, EntIndexToEntRef(entity));
	WritePackString(dp, input);
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
public Native_WM_RegisterWeapon(Handle:plugin, numParams) {
	
	if( g_iWpnCount >= MAX_WEAPON )
		return 0;
	
	g_iWpnCount++;
	
	GetNativeString(1, g_szWeaponData[g_iWpnCount][ wpn_string_name], MAX_STRINGSIZE);
	GetNativeString(2, g_szWeaponData[g_iWpnCount][ wpn_string_shortname], MAX_STRINGSIZE);
	
	g_iWeaponRegistered[ g_iWpnCount ] = 1;
	
	return g_iWpnCount;
}
public Native_WM_SetInt(Handle:plugin, numParams) {
	
	new wpnid = GetNativeCell(1);
	new enum_weapon_int:enum_data = GetNativeCell(2);
	new data = _:GetNativeCell(3);
	
	g_iWeaponData[ wpnid ][ enum_data ] = data;
}
public Native_WM_SetFloat(Handle:plugin, numParams) {
	
	new wpnid = GetNativeCell(1);
	new enum_weapon_int:enum_data = GetNativeCell(2);
	new Float:data = Float:GetNativeCell(3);
	
	g_flWeaponData[ wpnid ][ enum_data ] = data;
}
public Native_WM_SetString(Handle:plugin, numParams) {
	
	new wpnid = GetNativeCell(1);
	new enum_weapon_string:enum_data = GetNativeCell(2);
	
	GetNativeString(3, g_szWeaponData[wpnid][ enum_data ], MAX_STRINGSIZE);
}
public Native_WM_RegisterEvent(Handle:plugin, numParams) {
	
	new wpnid = GetNativeCell(1);
	new enum_weapon_event:enum_data = GetNativeCell(2);
	new func = GetNativeCell(3);
	
	g_hWeaponData[ wpnid ][ enum_data ] = CreateForward( ET_Event, Param_Cell);
	AddToForward(g_hWeaponData[ wpnid ][ enum_data ], plugin, Function:func);
}
// -----------------------------------------------------------------------------------------------
//			STOCKS & UTILS
public bool:WM_TraceEntityFilterStuff(entity, mask) {

	if( IsValidClient(entity) || IsMoveAble(entity) )
		return false;
	
	if( entity > 0 && IsValidEdict(entity) && IsValidEntity(entity) ) {
		new String:classname[64];
		GetEdictClassname(entity, classname, sizeof(classname));
		if( StrContains(classname, "wm_") == 0 ) {
			return false;
		}
	}
	
	return true;
}
stock MakeRadiusPush2( Float:center[3], Float:lenght, Float:damage) {
	
	new Float:vecPushDir[3], Float:vecOrigin[3], Float:vecVelo[3], Float:FallOff = (damage/lenght);
	
	for(new i=1; i<=2048; i++) {
		if( !IsValidEdict(i) )
			continue;
		if( !IsValidEntity(i) )
			continue;
		if( !IsMoveAble(i) )
			continue;
		
		if( IsValidClient(i) ) {
			GetClientEyePosition(i, vecOrigin);
		}
		else {
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecOrigin);
		}
		
		if( GetVectorDistance(vecOrigin, center) > lenght )
			continue;
		
		GetEntPropVector(i, Prop_Data, "m_vecVelocity", vecVelo);
		
		vecPushDir[0] = vecOrigin[0] - center[0];
		vecPushDir[1] = vecOrigin[1] - center[1];
		vecPushDir[2] = vecOrigin[2] - center[2];
		
		NormalizeVector(vecPushDir, vecPushDir);
		new Float:dist = (lenght - GetVectorDistance(vecOrigin, center)) * FallOff;
		
		TR_TraceRayFilter(center, vecOrigin, MASK_SHOT, RayType_EndPoint, WM_TraceEntityFilterStuff);
		new Float:fraction = (TR_GetFraction()) * 1.5;
		
		if( fraction >= 1.0 )
			fraction = 1.0;
		
		dist *= fraction;
		
		new Float:vecPush[3];
		vecPush[0] = (dist * vecPushDir[0]) + vecVelo[0];
		vecPush[1] = (dist * vecPushDir[1]) + vecVelo[1];
		vecPush[2] = (dist * vecPushDir[2]) + vecVelo[2];
		
		new flags = GetEntityFlags(i);
		if( vecPush[2] > 0.0 && (flags & FL_ONGROUND) ) {
			
			SetEntityFlags(i, (flags&~FL_ONGROUND) );
			SetEntPropEnt(i, Prop_Send, "m_hGroundEntity", -1);
		}
		TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vecPush);
	}
}
