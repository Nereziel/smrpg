#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <smlib/clients>

#pragma newdecls required
#include <smrpg>

#define UPGRADE_SHORTNAME "critical_hit"

ConVar g_hCVDefaultPercent;
ConVar g_hCVDefaultMaxDamage;
ConVar g_hCVDefaultDmgMultiplier;

public Plugin myinfo = 
{
	name = "SM:RPG Upgrade > Critical Hit",
	author = "Nereziel",
	description = "Critical Hit upgrade for SM:RPG. Deal exceptional damage on enemies.",
	version = SMRPG_VERSION,
	url = "http://overcore.eu/"
}

public void OnPluginStart()
{
	LoadTranslations("smrpg_stock_upgrades.phrases");

	// Account for late loading
	for(int i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public void OnPluginEnd()
{
	if(SMRPG_UpgradeExists(UPGRADE_SHORTNAME))
		SMRPG_UnregisterUpgradeType(UPGRADE_SHORTNAME);
}

public void OnAllPluginsLoaded()
{
	OnLibraryAdded("smrpg");
}

public void OnLibraryAdded(const char[] name)
{
	// Register this upgrade in SM:RPG
	if(StrEqual(name, "smrpg"))
	{
		SMRPG_RegisterUpgradeType("Critical Hit", UPGRADE_SHORTNAME, "Chance to deal addtional damage on enemies.", 10, true, 5, 5, 10);
		//SMRPG_SetUpgradeTranslationCallback(UPGRADE_SHORTNAME, SMRPG_TranslateUpgrade);
		g_hCVDefaultPercent = SMRPG_CreateUpgradeConVar(UPGRADE_SHORTNAME, "smrpg_criticalhit_percent", "2", "Percentage of damage done the victim loses additionally (multiplied by level)", _, true, 0.0);
		g_hCVDefaultDmgMultiplier = SMRPG_CreateUpgradeConVar(UPGRADE_SHORTNAME, "smrpg_criticalhit_dmg_mult", "1.25", "Percentage of damage done the victim loses additionally (static)", _, true, 0.0);
		g_hCVDefaultMaxDamage = SMRPG_CreateUpgradeConVar(UPGRADE_SHORTNAME, "smrpg_criticalhit_maxdmg", "75", "Maximum damage a player could deal additionally ignoring higher percentual values. (0 = disable)", _, true, 0.0);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}
/*
public void OnMapStart()
{
	if(!LoadWeaponConfig())
		SetFailState("Can't read config file in configs/smrpg/damage_weapons.cfg!");
}
*/
/**
 * SM:RPG Upgrade callbacks
 */
/*
public void SMRPG_TranslateUpgrade(int client, const char[] shortname, TranslationType type, char[] translation, int maxlen)
{
	if(type == TranslationType_Name)
		Format(translation, maxlen, "%T", UPGRADE_SHORTNAME, client);
	else if(type == TranslationType_Description)
	{
		char sDescriptionKey[MAX_UPGRADE_SHORTNAME_LENGTH+12] = UPGRADE_SHORTNAME;
		StrCat(sDescriptionKey, sizeof(sDescriptionKey), " description");
		Format(translation, maxlen, "%T", sDescriptionKey, client);
	}
}
*/
/**
 * Hook callbacks
 */
public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(attacker <= 0 || attacker > MaxClients || victim <= 0 || victim > MaxClients)
		return Plugin_Continue;
	
	if(!SMRPG_IsEnabled())
		return Plugin_Continue;
	
	int upgrade[UpgradeInfo];
	SMRPG_GetUpgradeInfo(UPGRADE_SHORTNAME, upgrade);
	if(!upgrade[UI_enabled])
		return Plugin_Continue;
	
	// Are bots allowed to use this upgrade?
	if(IsFakeClient(attacker) && SMRPG_IgnoreBots())
		return Plugin_Continue;
		
	// Ignore team attack if not FFA
	if(!SMRPG_IsFFAEnabled() && GetClientTeam(attacker) == GetClientTeam(victim))
		return Plugin_Continue;
	
	// Player didn't buy this upgrade yet.
	int iLevel = SMRPG_GetClientUpgradeLevel(attacker, UPGRADE_SHORTNAME);
	if(iLevel <= 0)
		return Plugin_Continue;
	
	int iWeapon = inflictor;
	if(inflictor > 0 && inflictor <= MaxClients)
		iWeapon = Client_GetActiveWeapon(inflictor);
	
	if(iWeapon == -1)
		return Plugin_Continue;
	
	char sWeapon[64];
	GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));
	
	if(StrContains(sWeapon, "weapon_", false) == -1)
		return Plugin_Continue;
		
	//float fDmgIncreasePercent = g_hCVDefaultPercent.FloatValue;
	//if (fDmgIncreasePercent <= 0.0)
		//return Plugin_Continue;
	
	if(!SMRPG_RunUpgradeEffect(victim, UPGRADE_SHORTNAME, attacker))
		return Plugin_Continue; // Some other plugin doesn't want this effect to run
	

	int randomnum = GetRandomInt(0, 100);
	// chance to do crit
	int chance = GetConVarInt(g_hCVDefaultPercent);
	//PrintToChatAll("int chance: %i", chance);
	if(randomnum <= (chance * iLevel))
	{
		// Increase the damage
		float fDmgInc = damage * g_hCVDefaultDmgMultiplier.FloatValue;
		
		// Cap it at the upper limit
		float fMaxDmg = g_hCVDefaultMaxDamage.FloatValue;
		if(fDmgInc >= (damage + fMaxDmg) && fMaxDmg > 0.0)
			fDmgInc = (damage + fMaxDmg);
			
		damage += fDmgInc;
		PrintToChat(attacker, "[RPG] You have landed a Critical hit!");
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
