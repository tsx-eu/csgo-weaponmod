#include <sourcemod>
#include <weaponmod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <phun>

public Plugin:myinfo = 
{
	name = "Weapon: Machette",
	author = "KoSSoLaX",
	description = "Custom Weapon - Machette",
	version = "1.0",
	url = "http://www.ts-x.eu"
}

new const String:WPN_NAME[] = "Machette";
new const String:WPN_SHORT[] = "wpn_machette";
new const String:WPN_REPLACE[] = "weapon_knife";

new const String:V_MODEL[] = "models/deadlydesire/weapons/v_model/machette_v3.mdl";
new const String:W_MODEL[] = "models/deadlydesire/weapons/w_model/machette_v3.mdl";

new const String:SND_ATK_1[] = "weapons/knife/knife_slash1.wav";
new const String:SND_ATK_2[] = "weapons/knife/knife_slash2.wav";


new g_iWeaponID = -1, g_cvModel = -1, g_cwModel = -1;

public createWeapon() {
	g_iWeaponID = wpnRegisterWeapon(WPN_REPLACE, WPN_NAME, WPN_SHORT);
	if( g_iWeaponID < 0 ) return;
	
	wpnSetInt(g_iWeaponID,		wpn_cost,				1000);
	wpnSetInt(g_iWeaponID,		wpn_ammo1,				1);
	wpnSetInt(g_iWeaponID,		wpn_ammo2,				0);
	wpnSetInt(g_iWeaponID,		wpn_bulletsPerShot1,	1);
	wpnSetInt(g_iWeaponID,		wpn_bulletsPerShot2,	1);
	
	wpnSetFloat(g_iWeaponID,	wpn_refireRate1,		0.66);
	wpnSetFloat(g_iWeaponID,	wpn_refireRate2,		1.5);
	wpnSetFloat(g_iWeaponID,	wpn_recoil1,			0.0);
	wpnSetFloat(g_iWeaponID,	wpn_recoil2,			0.0);
	wpnSetFloat(g_iWeaponID,	wpn_reloadTime,			0.0);
	
	wpnRegisterEvent(g_iWeaponID, wpn_evAttack1,		evAttack1);
	wpnRegisterEvent(g_iWeaponID, wpn_evAttack2,		evAttack2);	
}
public evAttack1(client) {
	
	wpnCACdamage(g_iWeaponID, client, client, 25.0);
	wpnPlayAnim(client, GetRandomInt(4, 5));
	
	EmitSoundToAll(SND_ATK_2, client);
	
	CreateTimer(wpnGetFloat(g_iWeaponID, wpn_refireRate1)-0.1, idle, client);
}
public Action:idle(Handle: timer, any:client) {
	wpnPlayAnim(client, 0);
}
public evAttack2(client) {
	
	wpnCACdamage(g_iWeaponID, client, client, 100.0);	
	wpnPlayAnim(client, GetRandomInt(2, 3));
	
	EmitSoundToAll(SND_ATK_1, client);
	
	CreateTimer(wpnGetFloat(g_iWeaponID, wpn_refireRate2)-0.1, idle, client);
}

public OnPluginStart() {
	createWeapon();
}
public OnMapStart() {
	g_cvModel = PrecacheModel(V_MODEL, true);
	g_cwModel = PrecacheModel(W_MODEL, true);
	
	PrecacheSound(SND_ATK_1, true);
	PrecacheSound(SND_ATK_2, true);
	
	wpnSetInt(g_iWeaponID,		wpn_viewmodel,			g_cvModel);
	wpnSetInt(g_iWeaponID,		wpn_worldmodel,			g_cwModel);
}
