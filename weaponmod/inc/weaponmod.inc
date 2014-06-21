
enum wpn_string
{
	wpn_replacement,
	wpn_longName,
	wpn_shortName,
	
	wpn_max_string
}
enum wpn_integer
{
	wpn_viewmodel,
	wpn_worldmodel,
	
	wpn_cost,	
	
	wpn_ammo1,
	wpn_ammo2,
	
	wpn_bulletsPerShot1,
	wpn_bulletsPerShot2,
	
	wpn_max_integer
}

enum wpn_float
{
	Float:wpn_refireRate1,
	Float:wpn_refireRate2,
	
	Float:wpn_reloadTime,
	
	Float:wpn_recoil1,
	Float:wpn_recoil2,
	
	Float:wpn_max_float
}
enum wpn_event
{
	Handle:wpn_evAttack1,
	Handle:wpn_evAttack2,
	Handle:wpn_evReload,
	Handle:wpn_evPickup,
	Handle:wpn_evDraw,
	Handle:wpn_evHide,
	Handle:wpn_evDrop,
	
	wpn_max_event
}

funcenum wpnEvent
{
	public(client )
}

native wpnRegisterWeapon(const String:replace[], const String:longname[], const String:shortname[]);

native wpnSetString( weaponID, wpn_string:stringID, const String:str[]);
native wpnGetString( weaponID, wpn_string:stringID, String:str[]);

native wpnSetInt( weaponID, wpn_integer:intID, int);
native wpnGetInt( weaponID, wpn_integer:intID);

native wpnSetFloat( weaponID, wpn_float:floatID, Float:flt);
native Float:wpnGetFloat( weaponID, wpn_float:floatID);


native wpnRegisterEvent(weaponid, wpn_event:eventID, wpnEvent:hook);

native wpnPlayAnim( weaponID, anim );
native wpnCACdamage( weaponid, client, from, Float:damage);

/*
native wpn_bulletShot(weaponid, attacker, dmg_save, dmg_take);
native wpn_playAnim(player, animation);
native wpn_damageUser(weaponid, victim, attacker, dmg_save, dmg_take, dmg_type, hitplace=0);
native wpn_radiusDamage(weaponid, attacker, inflictor, Float:range, Float:damage, damageType);
*/
