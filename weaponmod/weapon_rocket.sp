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
	name = "WeaponMOD: RocketLauncher",
	author = "KoSSoLaX`",
	description = "WeaponMOD: Lance Rockette",
	version = "1.0",
	url = "http://www.ts-x.eu/"
}

// -----------------------------------------------------------------------------------------------
//
new const String:WPN_NAME[] = "Lance Rocket";
new const String:WPN_SHORTNAME[] = "rpg";

new const String:WPN_MODEL[] = "models/weapons/w_models/w_rocketlauncher.mdl";
new const String:WPN_MODEL2[] = "models/weapons/w_missile_closed.mdl";
// -----------------------------------------------------------------------------------------------
//
public OnMapStart() {
	PrecacheModel(WPN_MODEL, true);
	PrecacheModel(WPN_MODEL2, true);
	
	PrecacheSound("weapons/rpg/rocket1.wav", true);
	PrecacheSound("weapons/rpg/rocketfire1.wav", true);

	
	AddFileToDownloadsTable("materials/models/weapons/w_rocketlauncher/w_rocketlauncher01_normal.vtf");
	AddFileToDownloadsTable("materials/models/weapons/w_rocketlauncher/w_rocketlauncher01.vmt");
	AddFileToDownloadsTable("materials/models/weapons/w_rocketlauncher/w_rocketlauncher01.vtf");
	
	AddFileToDownloadsTable("models/weapons/w_models/w_rocketlauncher.dx80.vtx");
	AddFileToDownloadsTable("models/weapons/w_models/w_rocketlauncher.dx90.vtx");
	AddFileToDownloadsTable("models/weapons/w_models/w_rocketlauncher.mdl");
	AddFileToDownloadsTable("models/weapons/w_models/w_rocketlauncher.phy");
	AddFileToDownloadsTable("models/weapons/w_models/w_rocketlauncher.sw.vtx");
	AddFileToDownloadsTable("models/weapons/w_models/w_rocketlauncher.vvd");
	
	AddFileToDownloadsTable("sound/weapons/rpg/rocket1.wav");
}
// -----------------------------------------------------------------------------------------------
//
public OnPluginStart() {
	create_weapon();
}
public create_weapon() {
	
	new wpnid = WM_RegisterWeapon(WPN_NAME, WPN_SHORTNAME);
	
	if( !wpnid ) 
		return;
	
	WM_SetString(wpnid, wpn_string_model, WPN_MODEL);
	
	WM_SetInt(wpnid, wpn_int_ammo1, 200);
	WM_SetInt(wpnid, wpn_int_ammo2, 50);
	WM_SetInt(wpnid, wpn_int_bullets_per_shot1, 1);
	WM_SetInt(wpnid, wpn_int_bullets_per_shot2, 1);
	
	WM_SetFloat(wpnid, wpn_float_refire_rate1, 1.0);
	WM_SetFloat(wpnid, wpn_float_refire_rate2, 1.0);
	WM_SetFloat(wpnid, wpn_float_reload, 1.0);
	
	WM_RegisterEvent(wpnid, wpn_event_attack1,	ev_attack1);
	return;
}
public Action:ev_attack1(client) {
	
	FireRocket(client);
	
	return Plugin_Continue;
}
// -----------------------------------------------------------------------------------------------
//
public FireRocket(client) {
	new Float:vecOrigin[3], Float:vecAngles[3], Float:vecVelocity[3];
	
	GetClientEyePosition(client, vecOrigin);
	GetClientEyeAngles(client, vecAngles);
	
	new Float:rad = degrees_to_radians(vecAngles[1]);
	
	vecOrigin[0] = (vecOrigin[0] - (-7.0 * Sine(rad))   + (35.0 * Cosine(rad)) );
	vecOrigin[1] = (vecOrigin[1] + (-7.0 * Cosine(rad)) + (35.0 * Sine(rad)) );
	vecOrigin[2] = (vecOrigin[2] - 1.0);
	
	new String:classname[128];
	Format(classname, sizeof(classname), "wm_%n_rocket_%i", WPN_SHORTNAME, client);
	
	new ent = CreateEntityByName("flashbang_projectile");
	
	DispatchKeyValue(ent, "classname", classname);
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntityModel(ent, WPN_MODEL2);
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	
	new Float:fMins[3] = {-1.0, -3.0, -1.0};
	new Float:fMaxs[3] = {1.0, 3.0, 1.0};
	
	SetEntPropVector( ent, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector( ent, Prop_Send, "m_vecMaxs", fMaxs);
	
	SetEntityMoveType(ent, MOVETYPE_FLY);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PROJECTILE);
	
	GetAngleVectors(vecAngles, vecVelocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vecVelocity, 1200.0);
	
	TeleportEntity(ent, vecOrigin, vecAngles, vecVelocity);
	
	EmitSoundToAll("weapons/rpg/rocket1.wav", ent, 0, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.4);
	EmitSoundToAll("weapons/rpg/rocketfire1.wav", client, 1, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.2);
	
	if( GetClientTeam( client) == CS_TEAM_T ) {
		MakeSmokeFollow(ent, 3.0, {250, 50, 50, 200});
	}
	else {
		MakeSmokeFollow(ent, 3.0, {50, 50, 250, 200});
	}	
	
	SDKHook(ent, SDKHook_Touch, CTF_WEAPON_RPG_FireRocket_TOUCH);
}
public CTF_WEAPON_RPG_FireRocket_TOUCH(rocket, entity) {
	
	new String:classname[64];
	GetEdictClassname(entity, classname, sizeof(classname));
	
	if( StrContains(classname, "trigger_", false) == 0 || StrContains(classname, "func_buyzone", false) == 0 ) 
		return;
	
	new Float:vecOrigin[3];
	
	GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", vecOrigin);
	
	ExplosionDamage(vecOrigin, 120.0, 250.0, GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity"));
	
	StopSound(rocket, 0, "weapons/rpg/rocket1.wav");
	
	new String:sound[128];
	Format(sound, 127, "weapons/explode%i.wav", GetRandomInt(3, 5));
	EmitSoundToAll(sound, rocket, 0, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	
	Colorize(rocket, 255, 255, 255, 0);
	vecOrigin[0] = 0.0;
	vecOrigin[1] = 0.0;
	vecOrigin[2] = 0.0;
	
	TeleportEntity(rocket, NULL_VECTOR, NULL_VECTOR, vecOrigin);
	
	SetEntProp(rocket, Prop_Data, "m_nSolidType", 0);
	SetEntProp(rocket, Prop_Data, "m_MoveCollide", 0);
	SetEntProp(rocket, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
	DispatchKeyValue(rocket, "solid", "0");
	
	SDKUnhook(rocket, SDKHook_Touch, CTF_WEAPON_RPG_FireRocket_TOUCH);	
	ScheduleEntityInput(rocket, 3.0, "KillHierarchy");
}
