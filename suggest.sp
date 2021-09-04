
#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "!suggest",
	author = "rtldg",
	description = "!suggest messages to sourcemod/logs/suggest.log",
	version = "1.0.0",
	url = "https://github.com/rtldg/sm_suggest"
}

char gS_Map[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	RegConsoleCmd("sm_suggest", Command_Suggest, "Make a suggestion");
}

public void OnMapStart()
{
	GetCurrentMap(gS_Map, sizeof(gS_Map));
}

public Action Command_Suggest(int client, int args)
{
	static int last_suggestion_time[MAXPLAYERS+1];

	if (client != 0 && (!IsClientConnected(client) || !IsClientInGame(client)))
	{
		return Plugin_Handled;
	}

	int now = GetTime();

	if (last_suggestion_time[client] && (last_suggestion_time[client] + 2 > now))
	{
		return Plugin_Handled;
	}

	last_suggestion_time[client] = now;

	char message[255];
	GetCmdArgString(message, sizeof(message));

	if (strlen(message) < 1)
	{
		return Plugin_Handled;
	}

	char filepath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filepath, sizeof(filepath), "logs/suggest.log");
	LogToFileEx(filepath, "%L (%s) %s", client, gS_Map, message);

	return Plugin_Handled;
}
