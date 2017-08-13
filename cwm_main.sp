#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <emitsoundany>
#include <colors_csgo>
#include <csgo_items>   // https://forums.alliedmods.net/showthread.php?t=243009

#include <custom_weapon_mod.inc>

#include <roleplay>

#pragma newdecls required

int g_iStackCount = 0;
int g_iStack[MAX_CWEAPONS][WSI_Max], g_iEntityData[MAX_ENTITIES][WSI_Max];
int g_aStack[MAX_CWEAPONS][WAA_Max][MAX_ANIMATION][3];
float g_fStack[MAX_CWEAPONS][WSF_Max], g_fEntityData[MAX_ENTITIES][WSF_Max];
Handle g_hStack[MAX_CWEAPONS][WSH_Max];
char g_sStack[MAX_CWEAPONS][WSS_Max][PLATFORM_MAX_PATH];
int g_cBlood[MAX_BLOOD], g_cScorch, g_cBeam;
DataPack g_hProjectile[MAX_ENTITIES];
bool g_bRoleplayMOD;

bool g_bHasCustomWeapon[65];
StringMap g_hNamedIdentified;

#define ANIM_SEQ		0
#define	ANIM_FRAME		1
#define ANIM_FPS		2

#define DEG2RAD(%1)		(%1*3.14159265/180.0)
// -----------------------------------------------------------------------------------------------------------------
//
//	PLUGIN START
//
public void OnPluginStart() {
	char classname[64];
	
	for (int i = 1; i < MaxClients; i++)
	if (IsClientInGame(i))
		OnClientPostAdminCheck(i);
	
	for (int i = 1; i < MAX_ENTITIES; i++) {
		g_iEntityData[i][WSI_Identifier] = -1;
		
		if (!IsValidEdict(i) || !IsValidEntity(i))
			continue;
		if (HasEntProp(i, Prop_Send, "m_iItemDefinitionIndex")) {
			CSGO_GetItemDefinitionNameByIndex(GetEntProp(i, Prop_Send, "m_iItemDefinitionIndex"), classname, sizeof(classname));
			if (StrContains(classname, "default") >= 0) {
				if (g_bRoleplayMOD) {
					int client = Weapon_GetOwner(i);
					if (client > 0) {
						rp_ClientMoney(client, i_AddToPay, 2500);
						CPrintToChat(client, "{green}[CWM]{default} Votre arme BETA vous a été remboursée par un admin.");
					}
				}
				AcceptEntityInput(i, "Kill");
			}
		}
	}
	
	
	if (GetConVarInt(FindConVar("hostport")) == 27025) {
		RegConsoleCmd("sm_cwm", Cmd_Spawn);
	}
	else {
		RegAdminCmd("sm_cwm", Cmd_Spawn, ADMFLAG_ROOT);
	}
	
	
	g_hNamedIdentified = new StringMap();
}
public void OnMapStart() {
	char tmp[PLATFORM_MAX_PATH];
	for (int i = 0; i < MAX_BLOOD; i++) {
		Format(tmp, sizeof(tmp), "decals/blood%d.vtf", i + 1);
		g_cBlood[i] = PrecacheDecal(tmp);
	}
	
	g_cScorch = PrecacheDecal("decals/scorch1.vtf");
	g_cBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
	PrecacheSound("weapons/clipempty_rifle.wav");
	PrecacheSound("weapons/sg556/sg556_draw.wav");
	
	for (int i = 0; i < g_iStackCount; i++) {
		g_iStack[i][WSI_VModel] = PrecacheModel(g_sStack[i][WSS_VModel]);
		g_iStack[i][WSI_WModel] = PrecacheModel(g_sStack[i][WSS_WModel]);
	}
}
public APLRes AskPluginLoad2(Handle hPlugin, bool isAfterMapLoaded, char[] error, int err_max) {
	g_bRoleplayMOD = LibraryExists("roleplay");
	
	CreateNative("CWM_Create", Native_CWM_Create);
	CreateNative("CWM_SetInt", Native_CWM_SetInt);
	CreateNative("CWM_SetFloat", Native_CWM_SetFloat);
	CreateNative("CWM_SetEntityInt", Native_CWM_SetEntityInt);
	CreateNative("CWM_SetEntityFloat", Native_CWM_SetEntityFloat);
	CreateNative("CWM_GetEntityInt", Native_CWM_GetEntityInt);
	CreateNative("CWM_GetEntityFloat", Native_CWM_GetEntityFloat);
	CreateNative("CWM_RegHook", Native_CWM_RegHook);
	CreateNative("CWM_AddAnimation", Native_CWM_AddAnimation);
	CreateNative("CWM_RunAnimation", Native_CWM_RunAnimation);
	CreateNative("CWM_Spawn", Native_CWM_Spawn);
	CreateNative("CWM_ShootProjectile", Native_CWM_ShootProjectile);
	CreateNative("CWM_ShootDamage", Native_CWM_ShootDamage);
	CreateNative("CWM_ShootExplode", Native_CWM_ShootExplode);
	CreateNative("CWM_GetId", Native_CWM_GetId);
	CreateNative("CWM_RefreshHUD", Native_CWM_RefreshHUD);
	
	ServerCommand("sm_cwm_reload");
}
public void OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "roleplay"))
		g_bRoleplayMOD = true;
}
public void OnLibraryRemoved(const char[] name) {
	if (StrEqual(name, "roleplay"))
		g_bRoleplayMOD = false;
}

// -----------------------------------------------------------------------------------------------------------------
//
//	Admin commands
//
public Action Cmd_Spawn(int client, int args) {
	char tmp[64];
	float pos[3], ang[3];
	GetCmdArg(1, tmp, sizeof(tmp));
	
	if (args <= 0) {
		
		Menu menu = CreateMenu(menu_Spawn);
		menu.SetTitle("Que voulez-vous spawn?");
		for (int i = 0; i < g_iStackCount; i++) {
			menu.AddItem(g_sStack[i][WSS_Name], g_sStack[i][WSS_Fullname]);
		}
		menu.Display(client, MENU_TIME_FOREVER);
		return Plugin_Handled;
	}
	
	int id;
	if (g_hNamedIdentified.GetValue(tmp, id)) {
		int target = GetCmdArgInt(2);
		if (client > 0)
			GetClientAimedLocation(client, pos, ang);
		ang[0] = ang[2] = 0.0;
		ang[1] += 180.0;
		CWM_Spawn(id, target, pos, ang);
	}
	return Plugin_Handled;
}
public int menu_Spawn(Handle handler, MenuAction action, int client, int param) {
	if (action == MenuAction_Select) {
		char item[32];
		GetMenuItem(handler, param, item, sizeof(item));
		ClientCommand(client, "sm_cwm %s %d; sm_cwm", item, client);
	}
	else if (action == MenuAction_End) {
		CloseHandle(handler);
	}
}
// -----------------------------------------------------------------------------------------------------------------
//
//	Native
//
public int Native_CWM_GetId(Handle plugin, int numParams) {
	static char tmp[PLATFORM_MAX_PATH];
	GetNativeString(1, tmp, sizeof(tmp));
	
	int id;
	if (g_hNamedIdentified.GetValue(tmp, id))
		return id;
	return -1;
}
public int Native_CWM_Create(Handle plugin, int numParams) {
	GetNativeString(1, g_sStack[g_iStackCount][WSS_Fullname], PLATFORM_MAX_PATH);
	GetNativeString(2, g_sStack[g_iStackCount][WSS_Name], PLATFORM_MAX_PATH);
	GetNativeString(3, g_sStack[g_iStackCount][WSS_ReplaceWeapon], PLATFORM_MAX_PATH);
	GetNativeString(4, g_sStack[g_iStackCount][WSS_VModel], PLATFORM_MAX_PATH);
	GetNativeString(5, g_sStack[g_iStackCount][WSS_WModel], PLATFORM_MAX_PATH);
	
	g_iStack[g_iStackCount][WSI_VModel] = PrecacheModel(g_sStack[g_iStackCount][WSS_VModel]);
	g_iStack[g_iStackCount][WSI_WModel] = PrecacheModel(g_sStack[g_iStackCount][WSS_WModel]);
	
	view_as<Handle>(g_hStack[g_iStackCount][WSH_Draw]) = CreateForward(ET_Hook, Param_Cell, Param_Cell);
	view_as<Handle>(g_hStack[g_iStackCount][WSH_Attack]) = CreateForward(ET_Hook, Param_Cell, Param_Cell);
	view_as<Handle>(g_hStack[g_iStackCount][WSH_AttackPost]) = CreateForward(ET_Hook, Param_Cell, Param_Cell);
	view_as<Handle>(g_hStack[g_iStackCount][WSH_Attack2]) = CreateForward(ET_Hook, Param_Cell, Param_Cell);
	view_as<Handle>(g_hStack[g_iStackCount][WSH_Reload]) = CreateForward(ET_Hook, Param_Cell, Param_Cell);
	view_as<Handle>(g_hStack[g_iStackCount][WSH_Idle]) = CreateForward(ET_Hook, Param_Cell, Param_Cell);
	view_as<Handle>(g_hStack[g_iStackCount][WSH_Empty]) = CreateForward(ET_Hook, Param_Cell, Param_Cell);
	
	
	g_hNamedIdentified.SetValue(g_sStack[g_iStackCount][WSS_Name], g_iStackCount);
	return g_iStackCount++;
}
public int Native_CWM_RunAnimation(Handle plugin, int numParams) {
	int entity = GetNativeCell(1);
	int id = g_iEntityData[entity][WSI_Identifier];
	if (id == -1)
		return;
	int anim = GetNativeCell(2);
	float time = GetNativeCell(3);
	int rnd = Math_GetRandomInt(1, g_aStack[id][anim][0][ANIM_SEQ]);
	
	float duration = g_aStack[id][anim][rnd][ANIM_FRAME] / float(g_aStack[id][anim][rnd][ANIM_FPS]);
	time = 1.0;
	
	g_iEntityData[entity][WSI_Animation] = g_aStack[id][anim][rnd][ANIM_SEQ];
	g_fEntityData[entity][WSF_NextIdle] = GetGameTime() + duration;
	g_fEntityData[entity][WSF_AnimationSpeed] = time;
	
	CWM_Animation(g_iEntityData[entity][WSI_Owner], entity);
}
public int Native_CWM_AddAnimation(Handle plugin, int numParams) {
	int id = GetNativeCell(1);
	int data = GetNativeCell(2);
	int cpt = g_aStack[id][data][0][ANIM_SEQ] + 1;
	
	g_aStack[id][data][cpt][ANIM_SEQ] = GetNativeCell(3);
	g_aStack[id][data][cpt][ANIM_FRAME] = GetNativeCell(4);
	g_aStack[id][data][cpt][ANIM_FPS] = GetNativeCell(5);
	
	g_aStack[id][data][0][0] = cpt;
}
public int Native_CWM_SetInt(Handle plugin, int numParams) {
	g_iStack[GetNativeCell(1)][GetNativeCell(2)] = GetNativeCell(3);
	return 1;
}
public int Native_CWM_SetEntityInt(Handle plugin, int numParams) {
	g_iEntityData[GetNativeCell(1)][GetNativeCell(2)] = GetNativeCell(3);
	return 1;
}
public int Native_CWM_GetEntityInt(Handle plugin, int numParams) {
	return g_iEntityData[GetNativeCell(1)][GetNativeCell(2)];
}
public int Native_CWM_SetFloat(Handle plugin, int numParams) {
	g_fStack[GetNativeCell(1)][GetNativeCell(2)] = GetNativeCell(3);
	return 1;
}
public int Native_CWM_SetEntityFloat(Handle plugin, int numParams) {
	g_fEntityData[GetNativeCell(1)][GetNativeCell(2)] = GetNativeCell(3);
	return 1;
}
public int Native_CWM_GetEntityFloat(Handle plugin, int numParams) {
	return view_as<int>(g_fEntityData[GetNativeCell(1)][GetNativeCell(2)]);
}
public int Native_CWM_RegHook(Handle plugin, int numParams) {
	AddToForward(g_hStack[GetNativeCell(1)][GetNativeCell(2)], plugin, GetNativeFunction(3));
}
public int Native_CWM_Spawn(Handle plugin, int numParams) {
	float pos[3], ang[3];
	int id = GetNativeCell(1);
	int target = GetNativeCell(2);
	GetNativeArray(3, pos, sizeof(pos));
	GetNativeArray(4, ang, sizeof(ang));
	
	int entity = CreateEntityByName(g_sStack[id][WSS_ReplaceWeapon]);
	DispatchKeyValue(entity, "classname", g_sStack[id][WSS_ReplaceWeapon]);
	DispatchKeyValue(entity, "CanBePickedUp", "1");
	DispatchSpawn(entity);
	
	SetEntityModel(entity, g_sStack[id][WSS_WModel]);
	TeleportEntity(entity, pos, ang, NULL_VECTOR);
	
	g_fEntityData[entity][WSF_NextAttack] = 0.0;
	g_iEntityData[entity][WSI_Identifier] = id;
	g_iEntityData[entity][WSI_Bullet] = g_iStack[id][WSI_MaxBullet];
	g_iEntityData[entity][WSI_Ammunition] = g_iStack[id][WSI_MaxAmmunition];
	
	if (IsValidClient(target))
		Client_EquipWeapon(target, entity, true);
	if (Weapon_GetOwner(entity) > 0)
		OnClientWeaponSwitch(Weapon_GetOwner(entity), entity);
}
public int Native_CWM_ShootDamage(Handle plugin, int numParams) {
	float src[3], ang[3], hit[3], dst[3];
	int client = GetNativeCell(1);
	int wpnid = GetNativeCell(2);
	GetNativeArray(3, hit, sizeof(hit));
	
	int id = g_iEntityData[wpnid][WSI_Identifier];
	
	GetClientEyePosition(client, src);
	GetClientEyeAngles(client, ang);
	ang[0] += GetRandomFloat(-g_fStack[id][WSF_Spread], g_fStack[id][WSF_Spread]);
	ang[1] += GetRandomFloat(-g_fStack[id][WSF_Spread], g_fStack[id][WSF_Spread]);
	
	
	int target;
	Handle trace = TR_TraceRayFilterEx(src, ang, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilterSelf, client);
	if (TR_DidHit(trace)) {
		TR_GetEndPosition(hit, trace);
		target = TR_GetEntityIndex(trace);
		
		if (GetVectorDistance(src, hit) < g_fStack[id][WSF_AttackRange]) {
			
			if (IsBreakable(target)) {
				Entity_Hurt(target, g_iStack[id][WSI_AttackDamage], client, DMG_CRUSH, g_sStack[id][WSS_Name]);
				if (g_bRoleplayMOD && IsValidClient(target) && rp_ClientCanAttack(client, target) )
					rp_ClientAggroIncrement(client, target, g_iStack[id][WSI_AttackDamage]);
				
				if (IsValidClient(target)) {
					TE_SetupBloodSprite(hit, view_as<float>( { 0.0, 0.0, 0.0 } ), { 255, 0, 0, 255 }, 16, 0, 0);
					TE_SendToAll();
					
					Entity_GetGroundOrigin(target, dst);
					TE_SetupWorldDecal(dst, g_cBlood[GetRandomInt(0, MAX_BLOOD - 1)]);
					TE_SendToAll();
				}
			}
			else
				target = 0;
		}
		else
			target = -1;
	}
	
	delete trace;
	if (target >= 0)
		SetNativeArray(3, hit, sizeof(hit));
	return target;
}
public int Native_CWM_ShootExplode(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int wpnid = GetNativeCell(2);
	int entity = GetNativeCell(3);
	float radius = view_as<float>(GetNativeCell(4));
	int id = g_iEntityData[wpnid][WSI_Identifier];
	float falloff = float(g_iStack[id][WSI_AttackDamage]) / radius;
	float src[3], dst[3], distance, min[3], max[3], hit[3], fraction;
	Handle tr;
	Entity_GetAbsOrigin(entity, src);
	
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", src);
	TE_WriteNum("m_nIndex", g_cScorch);
	TE_SendToAll();
	
	int MTRACE = 8;
	
	for (int i = 1; i <= MAX_ENTITIES; i++) {
		if (!IsValidEdict(i) || !IsValidEntity(i))
			continue;
		if (!IsBreakable(i))
			continue;
		if (IsValidClient(i) && !IsPlayerAlive(i))
			continue;
		
		Entity_GetAbsOrigin(i, dst);
		distance = view_as<float>(Math_Min(1.0, GetVectorDistance(src, dst)));
		if (distance > radius)
			continue;
		
		Entity_GetMinSize(i, min);
		Entity_GetMaxSize(i, max);
		fraction = 0.0;
		
		for (int j = 0; j < MTRACE; j++) {
			
			for (int k = 0; k <= 2; k++)
			hit[k] = dst[k] + GetRandomFloat(min[k], max[k]);
			
			
			tr = TR_TraceRayFilterEx(src, hit, MASK_SHOT, RayType_EndPoint, TraceEntityFilterSelf, entity);
			
			if (TR_DidHit(tr)) {
				fraction += TR_GetFraction(tr);
				if (TR_GetEntityIndex(tr) == i) {
					TE_SetupBloodSprite(hit, view_as<float>( { 0.0, 0.0, 0.0 } ), { 255, 0, 0, 255 }, 16, 0, 0);
					TE_SendToAll();
				}
			}
			else {
				fraction += 1.0;
				TE_SetupBloodSprite(hit, view_as<float>( { 0.0, 0.0, 0.0 } ), { 255, 0, 0, 255 }, 16, 0, 0);
				TE_SendToAll();
			}
			delete tr;
		}
		
		float damage = (fraction / float(MTRACE)) * (radius - distance) * falloff;
		if (damage > 0.0) {
			Entity_Hurt(i, RoundToCeil(damage), client, DMG_BLAST, g_sStack[id][WSS_Name]);
			if (g_bRoleplayMOD && IsValidClient(i) && rp_ClientCanAttack(client, i) )
				rp_ClientAggroIncrement(client, i, RoundToCeil(damage));
		}
	}
	
	
	return 1;
}
public int Native_CWM_ShootProjectile(Handle plugin, int numParams) {
	char name[32], model[PLATFORM_MAX_PATH];
	int client = GetNativeCell(1);
	int entity = GetNativeCell(2);
	GetNativeString(3, model, sizeof(model));
	GetNativeString(4, name, sizeof(name));
	float spreadAngle = view_as<float>(GetNativeCell(5));
	float speed = view_as<float>(GetNativeCell(6));
	Function callback = GetNativeFunction(7);
	
	int ent = CreateEntityByName("hegrenade_projectile");
	DispatchKeyValue(ent, "classname", name);
	DispatchSpawn(ent);
	
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropFloat(ent, Prop_Send, "m_flElasticity", 0.4);
	SetEntityMoveType(ent, MOVETYPE_FLYGRAVITY);
	
	
	Entity_SetSolidType(ent, SOLID_VPHYSICS);
	Entity_SetSolidFlags(ent, FSOLID_NOT_SOLID | FSOLID_TRIGGER);
	Entity_SetCollisionGroup(ent, COLLISION_GROUP_PLAYER | COLLISION_GROUP_PLAYER_MOVEMENT);
	
	if (!StrEqual(model, NULL_MODEL)) {
		if (!IsModelPrecached(model))
			PrecacheModel(model);
		SetEntityModel(ent, model);
	}
	else
		SetEntityRenderMode(ent, RENDER_NONE);
	
	float vecOrigin[3], vecAngles[3], vecDir[3], vecPush[3];
	
	GetClientEyePosition(g_iEntityData[entity][WSI_Owner], vecOrigin);
	GetClientEyeAngles(g_iEntityData[entity][WSI_Owner], vecAngles);
	
	vecAngles[0] += GetRandomFloat(-spreadAngle, spreadAngle);
	vecAngles[1] += GetRandomFloat(-spreadAngle, spreadAngle);
	
	GetAngleVectors(vecAngles, vecPush, NULL_VECTOR, NULL_VECTOR);
	GetAngleVectors(vecAngles, vecDir, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vecPush, RANGE_MELEE - 16.0);
	ScaleVector(vecDir, speed);
	
	
	float delta[3] =  { 32.0, -16.0, -12.0 };
	Math_RotateVector(delta, vecAngles, delta);
	vecOrigin[0] += delta[0];
	vecOrigin[1] += delta[1];
	vecOrigin[2] += delta[2];
	
	if (g_hProjectile[ent])
		delete g_hProjectile[ent];
	g_hProjectile[ent] = new DataPack();
	g_hProjectile[ent].WriteCell(client);
	g_hProjectile[ent].WriteCell(entity);
	g_hProjectile[ent].WriteCell(plugin);
	g_hProjectile[ent].WriteFunction(callback);
	
	TeleportEntity(ent, vecOrigin, vecAngles, vecDir);
	SDKHook(ent, SDKHook_StartTouch, CWM_ProjectileTouch);
	return ent;
}
public int Native_CWM_RefreshHUD(Handle plugin, int numParams) {
	CWM_Refresh(GetNativeCell(1), GetNativeCell(2));
}
// -----------------------------------------------------------------------------------------------------------------
//
//	EVENT
//
public void OnClientPostAdminCheck(int client) {
	SDKHook(client, SDKHook_WeaponSwitchPost, OnClientWeaponSwitch);
	SDKHook(client, SDKHook_WeaponDropPost, OnClientWeaponDrop);
}
public void OnEntityCreated(int entity, const char[] classname) {
	g_iEntityData[entity][WSI_Identifier] = -1;
}
public Action OnPlayerRunCmd(int client, int & btn, int & impulse, float vel[3], float ang[3], int & weapon, int & subtype, int & cmd, int & tick, int & seed, int mouse[2]) {
	static int lastButton[65];
	
	if (g_bHasCustomWeapon[client]) {
		int wpnid = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		
		if (wpnid > 0) {
			
			CWM_RefreshHUD(client, wpnid);
			float time = GetGameTime();
			int id = g_iEntityData[wpnid][WSI_Identifier];
			
			if (g_fEntityData[wpnid][WSF_NextAttack] <= time && (btn & IN_ATTACK)) {
				switch (g_iStack[id][WSI_AttackType]) {
					case WSA_Automatic: {
						CWM_Attack(client, wpnid);
					}
					case WSA_LockAndLoad: {
						if (g_iEntityData[wpnid][WSI_State] == 0) {
							g_iEntityData[wpnid][WSI_State] = 1;
							CWM_Attack(client, wpnid);
						}
					}
					case WSA_SemiAutomatic: {
						if (!(lastButton[client] & IN_ATTACK))
							CWM_Attack(client, wpnid);
					}
				}
			}
			if (g_iEntityData[wpnid][WSI_State] == 1 && !(btn & IN_ATTACK)) {
				switch (g_iStack[id][WSI_AttackType]) {
					case WSA_LockAndLoad: {
						CWM_AttackPost(client, wpnid);
						g_iEntityData[wpnid][WSI_State] = 0;
					}
				}
			}
			if (g_fEntityData[wpnid][WSF_NextAttack] <= time && (btn & IN_ATTACK2)) {
				switch (g_iStack[id][WSI_AttackType]) {
					case WSA_Automatic: {
						CWM_Attack2(client, wpnid);
					}
					case WSA_LockAndLoad: {
						CWM_Attack2(client, wpnid);
					}
					case WSA_SemiAutomatic: {
						if (!(lastButton[client] & IN_ATTACK2))
							CWM_Attack2(client, wpnid);
					}
				}
			}
			if (g_iEntityData[wpnid][WSI_State] == 0 && g_fEntityData[wpnid][WSF_NextAttack] <= time && (btn & IN_RELOAD)) {
				CWM_Reload(client, wpnid);
			}
			
			lastButton[client] = btn;
			if (g_iEntityData[wpnid][WSI_State] == 0 && g_fEntityData[wpnid][WSF_NextIdle] <= time)
				CWM_Idle(client, wpnid);
		}
	}
	return Plugin_Continue;
}
// -----------------------------------------------------------------------------------------------------------------
//
//	State Machine
//
stock void CWM_Refresh(int client, int wpnid) {
	int view = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	int world = GetEntPropEnt(wpnid, Prop_Send, "m_hWeaponWorldModel");
	
	if (GetEntPropFloat(wpnid, Prop_Send, "m_flNextPrimaryAttack") != FLT_MAX)
		SetEntPropFloat(wpnid, Prop_Send, "m_flNextPrimaryAttack", FLT_MAX);
	if (GetEntPropFloat(wpnid, Prop_Send, "m_flNextSecondaryAttack") != FLT_MAX)
		SetEntPropFloat(wpnid, Prop_Send, "m_flNextSecondaryAttack", FLT_MAX);
	if (GetEntProp(wpnid, Prop_Send, "m_iClip1") != g_iEntityData[wpnid][WSI_Bullet])
		SetEntProp(wpnid, Prop_Send, "m_iClip1", g_iEntityData[wpnid][WSI_Bullet]);
	if (GetEntProp(wpnid, Prop_Send, "m_iPrimaryReserveAmmoCount") != g_iEntityData[wpnid][WSI_Ammunition])
		SetEntProp(wpnid, Prop_Send, "m_iPrimaryReserveAmmoCount", g_iEntityData[wpnid][WSI_Ammunition]);
	
	if (view > 0) {
		if (GetEntProp(view, Prop_Send, "m_nSkin") != g_iEntityData[wpnid][WSI_Skin])
			SetEntProp(view, Prop_Send, "m_nSkin", g_iEntityData[wpnid][WSI_Skin]);
	}
	if (world > 0) {
		if (GetEntProp(world, Prop_Data, "m_nSkin") != g_iEntityData[wpnid][WSI_Skin])
			SetEntProp(world, Prop_Data, "m_nSkin", g_iEntityData[wpnid][WSI_Skin]);
	}
	if (GetEntProp(wpnid, Prop_Send, "m_nSkin") != g_iEntityData[wpnid][WSI_Skin])
		SetEntProp(wpnid, Prop_Send, "m_nSkin", g_iEntityData[wpnid][WSI_Skin]);
}
stock void CWM_Animation(int client, int entity) {
	int view = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if (view > 0) {
		SetEntProp(view, Prop_Send, "m_nSequence", g_iEntityData[entity][WSI_Animation]);
	}
}
stock void CWM_Idle(int client, int wpnid) {
	int id = g_iEntityData[wpnid][WSI_Identifier];
	Call_StartForward(view_as<Handle>(g_hStack[id][WSH_Idle]));
	Call_PushCell(client);
	Call_PushCell(wpnid);
	Call_Finish();
}
stock void CWM_Reload(int client, int wpnid) {
	int id = g_iEntityData[wpnid][WSI_Identifier];
	
	int bulletCount = g_iStack[id][WSI_ReloadType] == view_as<int>(WSR_Automatic) ? g_iStack[id][WSI_MaxBullet] : 1;
	
	if ((bulletCount + g_iEntityData[wpnid][WSI_Bullet]) > g_iStack[id][WSI_MaxBullet])
		bulletCount = g_iStack[id][WSI_MaxBullet] - g_iEntityData[wpnid][WSI_Bullet];
	
	if (bulletCount > 0 && g_iEntityData[wpnid][WSI_Ammunition] > 0) {
		
		Call_StartForward(view_as<Handle>(g_hStack[id][WSH_Reload]));
		Call_PushCell(client);
		Call_PushCell(wpnid);
		Call_Finish();
		
		g_iEntityData[wpnid][WSI_Ammunition] -= bulletCount;
		g_iEntityData[wpnid][WSI_Bullet] += bulletCount;
		
		if (g_iEntityData[wpnid][WSI_Ammunition] < 0) {
			g_iEntityData[wpnid][WSI_Bullet] += g_iEntityData[wpnid][WSI_Ammunition];
			g_iEntityData[wpnid][WSI_Ammunition] = 0;
		}
		
		g_fEntityData[wpnid][WSF_NextAttack] = GetGameTime() + g_fStack[id][WSF_ReloadSpeed];
		CreateTimer(g_fStack[id][WSF_ReloadSpeed], CWM_ReloadBatch, wpnid);
	}
	else {
		CWM_Empty(client, wpnid);
	}
}
public Action CWM_ReloadBatch(Handle timer, any wpnid) {
	
	int client = g_iEntityData[wpnid][WSI_Owner];
	int id = g_iEntityData[wpnid][WSI_Identifier];
	
	if (client > 0 && g_iEntityData[wpnid][WSI_Ammunition] > 1 && g_iEntityData[wpnid][WSI_Bullet] < g_iStack[id][WSI_MaxBullet])
		CWM_Reload(client, wpnid);
	
	return Plugin_Handled;
}
stock void CWM_Empty(int client, int wpnid) {
	int id = g_iEntityData[wpnid][WSI_Identifier];
	Call_StartForward(view_as<Handle>(g_hStack[id][WSH_Empty]));
	Call_PushCell(client);
	Call_PushCell(wpnid);
	Call_Finish();
	g_fEntityData[wpnid][WSF_NextAttack] = GetGameTime() + 0.5 + g_fStack[id][WSF_AttackSpeed];
	EmitSoundToAll("weapons/clipempty_rifle.wav", wpnid, SNDCHAN_WEAPON);
}
stock void CWM_Draw(int client, int wpnid) {
	int id = g_iEntityData[wpnid][WSI_Identifier];
	
	SetEntProp(wpnid, Prop_Send, "m_nModelIndex", g_iStack[id][WSI_WModel]);
	int view = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	int world = GetEntPropEnt(wpnid, Prop_Send, "m_hWeaponWorldModel");
	
	if (view > 0)
		SetEntProp(view, Prop_Send, "m_nModelIndex", g_iStack[id][WSI_VModel]);
	if (world > 0)
		SetEntProp(world, Prop_Send, "m_nModelIndex", g_iStack[id][WSI_WModel]);
	
	SetEntPropFloat(wpnid, Prop_Send, "m_flNextPrimaryAttack", FLT_MAX);
	SetEntPropFloat(wpnid, Prop_Send, "m_flNextSecondaryAttack", FLT_MAX);
	SetEntPropFloat(wpnid, Prop_Send, "m_flTimeWeaponIdle", FLT_MAX);
	
	g_fEntityData[wpnid][WSF_NextAttack] = GetGameTime() + 1.0;
	
	EmitSoundToAll("weapons/sg556/sg556_draw.wav", wpnid, SNDCHAN_WEAPON);
	
	Call_StartForward(view_as<Handle>(g_hStack[id][WSH_Draw]));
	Call_PushCell(client);
	Call_PushCell(wpnid);
	Call_Finish();
}
stock void CWM_Attack(int client, int wpnid) {
	int id = g_iEntityData[wpnid][WSI_Identifier];
	float time = GetGameTime();
	
	if (g_bRoleplayMOD) {
		if (rp_GetZoneBit(rp_GetPlayerZone(client)) & BITZONE_PEACEFULL) {
			g_fEntityData[wpnid][WSF_NextAttack] = time + g_fStack[id][WSF_AttackSpeed];
			g_iEntityData[wpnid][WSI_State] = 0;
			return;
		}
	}
	
	if (GetForwardFunctionCount(view_as<Handle>(g_hStack[id][WSH_Attack])) == 0) {
		g_iEntityData[wpnid][WSI_State] = 0;
		return;
	}
	
	if ((g_iEntityData[wpnid][WSI_Bullet] - g_iStack[id][WSI_AttackBullet]) >= 0) {
		
		Action a;
		Call_StartForward(view_as<Handle>(g_hStack[id][WSH_Attack]));
		Call_PushCell(client);
		Call_PushCell(wpnid);
		Call_Finish(a);
		
		if (a != Plugin_Stop) {
			g_fEntityData[wpnid][WSF_NextAttack] = time + g_fStack[id][WSF_AttackSpeed];
			if (a != Plugin_Handled)
				g_iEntityData[wpnid][WSI_Bullet] -= g_iStack[id][WSI_AttackBullet];
			
			if (g_iEntityData[wpnid][WSI_Bullet] == 0)
				CreateTimer(g_fStack[id][WSF_AttackSpeed], CWM_ReloadBatch, wpnid);
		}
	}
	else {
		g_iEntityData[wpnid][WSI_State] = 0;
		CWM_Reload(client, wpnid);
	}
}
stock void CWM_AttackPost(int client, int wpnid) {
	int id = g_iEntityData[wpnid][WSI_Identifier];
	float time = GetGameTime();
	
	if (g_bRoleplayMOD) {
		if (rp_GetZoneBit(rp_GetPlayerZone(client)) & BITZONE_PEACEFULL) {
			g_fEntityData[wpnid][WSF_NextAttack] = time + g_fStack[id][WSF_AttackSpeed];
			g_iEntityData[wpnid][WSI_State] = 1;
			return;
		}
	}
	
	Action a;
	Call_StartForward(view_as<Handle>(g_hStack[id][WSH_AttackPost]));
	Call_PushCell(client);
	Call_PushCell(wpnid);
	Call_Finish(a);
	
}
stock void CWM_Attack2(int client, int wpnid) {
	int id = g_iEntityData[wpnid][WSI_Identifier];
	float time = GetGameTime();
	
	if (g_bRoleplayMOD) {
		if (rp_GetZoneBit(rp_GetPlayerZone(client)) & BITZONE_PEACEFULL) {
			g_fEntityData[wpnid][WSF_NextAttack] = time + g_fStack[id][WSF_AttackSpeed];
			return;
		}
	}
	
	
	if (GetForwardFunctionCount(view_as<Handle>(g_hStack[id][WSH_Attack2])) == 0)
		return;
	
	if ((g_iEntityData[wpnid][WSI_Bullet] - g_iStack[id][WSI_AttackBullet]) >= 0) {
		
		Action a;
		Call_StartForward(view_as<Handle>(g_hStack[id][WSH_Attack2]));
		Call_PushCell(client);
		Call_PushCell(wpnid);
		Call_Finish(a);
		
		if (a != Plugin_Stop) {
			g_fEntityData[wpnid][WSF_NextAttack] = time + g_fStack[id][WSF_AttackSpeed];
			if (a != Plugin_Handled)
				g_iEntityData[wpnid][WSI_Bullet] -= g_iStack[id][WSI_AttackBullet];
		}
	}
	else {
		CWM_Reload(client, wpnid);
	}
}
// -----------------------------------------------------------------------------------------------------------------
//
//	Forwards
//
public Action OnClientWeaponSwitch(int client, int wpnid) {
	int id = g_iEntityData[wpnid][WSI_Identifier];
	if (id >= 0) {
		g_bHasCustomWeapon[client] = true;
		g_iEntityData[wpnid][WSI_Owner] = client;
		CWM_Draw(client, wpnid);
	}
	else {
		g_bHasCustomWeapon[client] = false;
	}
}
public Action OnClientWeaponDrop(int client, int wpnid) {
	if (wpnid > 0 && g_iEntityData[wpnid][WSI_Identifier] >= 0) {
		g_bHasCustomWeapon[client] = false;
		g_iEntityData[wpnid][WSI_Owner] = 0;
		RequestFrame(OnClientWeaponDropPost, EntIndexToEntRef(wpnid));
	}
}
public void OnClientWeaponDropPost(int wpnid) {
	wpnid = EntRefToEntIndex(wpnid);
	if (wpnid > 0 && g_iEntityData[wpnid][WSI_Identifier] >= 0)
		SetEntProp(wpnid, Prop_Send, "m_nModelIndex", g_iStack[g_iEntityData[wpnid][WSI_Identifier]][WSI_WModel]);
}
public bool TraceEntityFilterSelf(int entity, int contentsMask, any data) {
	return entity != data;
}
public bool TraceEntityFilterSelfAndEntity(int entity, int contentsMask, any data) {
	return entity > 0 && entity != 0;
}
public Action CWM_ProjectileTouch(int ent, int target) {
	g_hProjectile[ent].Reset();
	int client = g_hProjectile[ent].ReadCell();
	int wpnid = g_hProjectile[ent].ReadCell();
	Handle plugin = g_hProjectile[ent].ReadCell();
	Function callback = g_hProjectile[ent].ReadFunction();
	
	int id = g_iEntityData[wpnid][WSI_Identifier];
	
	if (callback != INVALID_FUNCTION && target >= 0 && target != client) {
		
		Action a;
		Call_StartFunction(plugin, callback);
		Call_PushCell(client);
		Call_PushCell(wpnid);
		Call_PushCell(ent);
		Call_PushCell(target);
		Call_Finish(a);
		
		if (a == Plugin_Continue && IsBreakable(target)) {
			Entity_Hurt(target, g_iStack[id][WSI_AttackDamage], g_iEntityData[wpnid][WSI_Owner], DMG_GENERIC, g_sStack[id][WSS_Name]);
			
			if (g_bRoleplayMOD && IsValidClient(target) && rp_ClientCanAttack(g_iEntityData[wpnid][WSI_Owner], target) )
				rp_ClientAggroIncrement(g_iEntityData[wpnid][WSI_Owner], target, g_iStack[id][WSI_AttackDamage]);
		}
		
		if (a != Plugin_Stop) {
			AcceptEntityInput(ent, "KillHierarchy");
			delete g_hProjectile[ent];
		}
	}
	
	return Plugin_Handled;
}
// -----------------------------------------------------------------------------------------------------------------
//
//	UTILS: CWM
//
public bool IsBreakable(int ent) {
	static char classname[64];
	if (ent <= 0 || !IsValidEdict(ent) || !IsValidEntity(ent))
		return false;
	if (IsValidClient(ent))
		return IsPlayerAlive(ent);
	if (!HasEntProp(ent, Prop_Send, "m_vecOrigin"))
		return false;
	
	if (g_bRoleplayMOD) {
		if (rp_GetBuildingData(ent, BD_owner) > 0)
			return true;
	}
	
	if (GetEntityMoveType(ent) != MOVETYPE_VPHYSICS)
		return false;
	if (!HasEntProp(ent, Prop_Send, "m_vecVelocity") && !HasEntProp(ent, Prop_Data, "m_vecAbsVelocity"))
		return false;
	if (Entity_GetMaxHealth(ent) <= 0)
		return false;
	
	GetEdictClassname(ent, classname, sizeof(classname));
	if (StrContains(classname, "door", false) == 0)
		return false;
	if (StrContains(classname, "prop_p", false) == 0)
		return true;
	if (StrContains(classname, "weapon_", false) == 0)
		return true;
	if (StrContains(classname, "chicken", false) == 0)
		return true;
	
	return false;
}
// -----------------------------------------------------------------------------------------------------------------
//
//	UTILS: Generics
//
stock int GetClientAimedLocation(int client, float position[3], float angles[3]) {
	int index = -1;
	GetClientEyePosition(client, position);
	GetClientEyeAngles(client, angles);
	
	Handle trace = TR_TraceRayFilterEx(position, angles, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilterSelf, client);
	if (TR_DidHit(trace)) {
		TR_GetEndPosition(position, trace);
		index = TR_GetEntityIndex(trace);
	}
	CloseHandle(trace);
	
	return index;
}
stock void TE_SetupWorldDecal(float origin[3], int index) {
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", origin);
	TE_WriteNum("m_nIndex", index);
}
stock int Entity_GetGroundOrigin(int entity, float pos[3]) {
	static float source[3], target[3];
	Entity_GetAbsOrigin(entity, source);
	target[0] = source[0];
	target[1] = source[1];
	target[2] = source[2] - 999999.9;
	
	Handle tr;
	tr = TR_TraceRayFilterEx(source, target, MASK_SOLID, RayType_EndPoint, TraceEntityFilterSelf, entity);
	if (tr)
		TR_GetEndPosition(pos, tr);
	delete tr;
} 