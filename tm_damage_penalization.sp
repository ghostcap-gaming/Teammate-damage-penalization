#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <sourcebanspp>

int g_iClientHits[MAXPLAYERS+1] = {0, ...};
bool g_bClientBanned[MAXPLAYERS+1] = {false, ...};

ConVar g_ConVar_HitsToBan, g_ConVar_BanLength, g_ConVar_RestartOnRound, g_ConVar_WarningEnable;

public Plugin myinfo = {
    name = "Teammate damage penalization",
    author = "Lerrdy",
    description = "Bans clients that repeatedly damage teammates",
    version = "0.1",
    url = "https://ghostcap.com"
};

public void OnPluginStart() {
	LoadTranslations("tm_damage_penalization");
	
	g_ConVar_HitsToBan = CreateConVar("sm_tm_damage_penalization_count", "5", "Number of teammate hits to ban for", _, true, 0.0);
	g_ConVar_BanLength = CreateConVar("sm_tm_damage_penalization_ban_length", "360", "Minutes to ban for in minutes", _, true, 0.0);
	g_ConVar_RestartOnRound = CreateConVar("sm_tm_damage_penalization_reset", "0", "When to reset the per-client damage count? (1 = RoundStart AND mapchange, 0 = Only on mapchange)", _, true, 0.0);
	g_ConVar_WarningEnable = CreateConVar("sm_tm_damage_penalization_warning_show", "1", "Should the attacker get a warning on every teammate damage before getting banned?", _, true, 0.0, true, 1.0);
	
	HookEvent("player_hurt", EventPlayerHurt);
	HookEvent("round_start", EventRoundStart);
	
	AutoExecConfig();
}

public void OnClientDisconnect(int client) {
	g_iClientHits[client] = 0;
	g_bClientBanned[client] = false;
}

public void EventRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	if (!g_ConVar_RestartOnRound.BoolValue) //If the convar for resetting is not set to 1 ignore roundstart
		return;
		
	for(int client = 1; client <= MaxClients; client++)  {
		g_iClientHits[client] = 0;
	}
}

public Action EventPlayerHurt(Handle event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker")); //Get attacker index
	if (attacker <= 0 || attacker > MaxClients) //Verify attacker index
		return Plugin_Continue;
		
	if (g_bClientBanned[attacker]) //Check if the client isnt already banned
		return Plugin_Handled;
		
	int index = GetClientOfUserId(GetEventInt(event, "userid")); //Get victim index
	if (GetClientTeam(index) != GetClientTeam(attacker) || index == attacker) //Verify that the attacker and the victim have the same team, and that client isnt damaging himself
		return Plugin_Continue;
	
	g_iClientHits[attacker]++; //Add one headshot to the counter
	if (g_iClientHits[attacker] >= g_ConVar_HitsToBan.IntValue) {
		char sBuffer[256];
		FormatEx(sBuffer, 256, "%T", "BAN_REASON", attacker); //Get the translated reason for the ban
		
		g_bClientBanned[attacker] = true; //Mark the attacker as banned
		
		SBPP_BanPlayer(0, attacker, g_ConVar_BanLength.IntValue, sBuffer); //Ban the attacker
		
		return Plugin_Handled;
	}
	
	if (g_ConVar_WarningEnable.BoolValue) {
		char sBuffer[256];
		FormatEx(sBuffer, 256, "%T%T", "PREFIX", attacker, "WARNING", attacker); //Get the translated warning message
		
		CPrintToChat(attacker, sBuffer); //Print the warning
	}
	
	return Plugin_Continue;
}