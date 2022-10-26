
#include <convar_class>
#include <ripext>

#define SUGGEST_CONFIRMATION_STRING "thx 4 suggestion. top (wo)men are on it <3"
#define SUGGEST_CONFIRMATION_STRING_COLORS "\x075e70d0thx \x07db88c24 suggestion\x07af2a22. top (wo)men are \x07ffffffon it \x077fd772<3"
#define REPORT_CONFIRMATION_STRING "thx 4 suggestion. top (wo)men are on it <3"
#define REPORT_CONFIRMATION_STRING_COLORS "\x075e70d0thx \x07db88c24 suggestion\x07af2a22. top (wo)men are \x07ffffffon it \x077fd772<3"

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "!suggest",
	author = "rtldg",
	description = "!suggest/!report messages to sourcemod/logs/suggest.log & sourcemod/logs/report.log",
	version = "1.1.0",
	url = "https://github.com/rtldg/sm_suggest"
}

char gS_Map[PLATFORM_MAX_PATH];
bool gB_Protobuf = false;
Convar gCV_WebhookURL = null;

public void OnPluginStart()
{
	gB_Protobuf = (GetUserMessageType() == UM_Protobuf);
	RegConsoleCmd("sm_suggest", Command_Suggest, "Make a suggestion");
	RegConsoleCmd("sm_report", Command_Report, "Make a report");

	gCV_WebhookURL = new Convar("suggest_webhook", "", "Discord webhook url for !suggest/!report", FCVAR_PROTECTED);
	Convar.AutoExecConfig();
}

public void OnMapStart()
{
	GetCurrentMap(gS_Map, sizeof(gS_Map));
}

void DoWebhook(bool report, int client, const char[] message)
{
	char filepath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filepath, sizeof(filepath), "logs/%s.log", report ? "report" : "suggest");
	LogToFileEx(filepath, "%L (%s) %s", client, gS_Map, message);

	char url[333];
	gCV_WebhookURL.GetString(url, sizeof(url));

	if (!url[0]) return;

	/* most of this is copied from shavit-bash2-discord.sp by eric */

	char steamid[65] = "rcon";
	if (client > 0)
		GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));

	char name[512];
	SanerGetClientName(client, name);
	ReplaceString(name, 512, "(", "\\(");
	ReplaceString(name, 512, ")", "\\)");
	ReplaceString(name, 512, "]", "\\]");
	ReplaceString(name, 512, "[", "\\[");
	ReplaceString(name, 512, "<", "\\<");
	ReplaceString(name, 512, ">", "\\>");
	ReplaceString(name, 512, "`", "'");
	Format(name, sizeof(name), "[%s](http://www.steamcommunity.com/profiles/%s)", name, steamid);

	// Suppress Discord mentions and embeds.
	// https://discord.com/developers/docs/resources/channel#allowed-mentions-object
	// https://discord.com/developers/docs/resources/channel#message-object-message-flags
	JSONArray parse = new JSONArray();
	JSONObject allowedMentions = new JSONObject();
	allowedMentions.Set("parse", parse);

	char content[512];
	strcopy(content, sizeof(content), message);
	ReplaceString(content, sizeof(content), "```", "`​`​`"); // ZWS / zero width spaced
	Format(content, sizeof(content), "[%s](https://steamcommunity.com/profiles/%s)\n```\n%s\n```", name, steamid, content);

	JSONObject json = new JSONObject();
	json.SetString("username", report ? "!report" : "!suggest");
	json.SetString("content", content);
	json.Set("allowed_mentions", allowedMentions);
	json.SetInt("flags", 4);

	HTTPRequest http = new HTTPRequest(url);
	http.Post(json, RequestCallback);

	delete parse;
	delete allowedMentions;
	delete json;
}

void RequestCallback(HTTPResponse response, any data, const char[] error)
{
	if (response.Status != HTTPStatus_NoContent)
	{
		LogError("SUGGEST: Discord webhook request failed. error = '%s'", error);
	}
}

public Action Command_Report(int client, int args)
{
	return Command_HANDLERRRR(client, args, true);
}

public Action Command_Suggest(int client, int args)
{
	return Command_HANDLERRRR(client, args, false);
}

public Action Command_HANDLERRRR(int client, int args, bool report)
{
	static int last_suggestion_time[MAXPLAYERS+1];

	if (client != 0 && (!IsClientConnected(client) || !IsClientInGame(client)))
	{
		return Plugin_Handled;
	}

	int now = GetTime();

	if (last_suggestion_time[client] && (last_suggestion_time[client] + 2 > now))
	{
		ReplyToCommand(client, "stop spamming");
		return Plugin_Handled;
	}

	last_suggestion_time[client] = now;

	char message[255];
	GetCmdArgString(message, sizeof(message));

	if (strlen(message) < 1)
	{
		return Plugin_Handled;
	}

	DoWebhook(report, client, message);

	if (client == 0)
	{
		PrintToServer(report ? REPORT_CONFIRMATION_STRING : SUGGEST_CONFIRMATION_STRING);
	}
	else
	{
		char sBuffer[256];

		FormatEx(sBuffer, (gB_Protobuf ? sizeof(sBuffer) : 253), "%s%s", (gB_Protobuf ? " ":""), report ? REPORT_CONFIRMATION_STRING_COLORS : SUGGEST_CONFIRMATION_STRING_COLORS);

		Handle hSayText2 = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

		if(gB_Protobuf)
		{
			Protobuf pbmsg = UserMessageToProtobuf(hSayText2);
			pbmsg.SetInt("ent_idx", client);
			pbmsg.SetBool("chat", true);
			pbmsg.SetString("msg_name", sBuffer);

			// needed to not crash
			for(int i = 1; i <= 4; i++)
			{
				pbmsg.AddString("params", "");
			}
		}
		else
		{
			BfWrite bfmsg = UserMessageToBfWrite(hSayText2);
			bfmsg.WriteByte(client);
			bfmsg.WriteByte(1);
			bfmsg.WriteString(sBuffer);
		}

		EndMessage();
	}

	return Plugin_Handled;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Steam names are `char[32+1];`. Source engine names are `char[32];` (MAX_PLAYER_NAME_LENGTH).
// This means Source engine names can end up with an invalid unicode sequence at the end.
// This will remove the unicode codepoint if necessary.
/*
	Sourcemod 1.11 will strip the invalid codepoint internally (some relevant links below) but it'd still be nice to just retrive the client's `name` convar so we get the full thing or maybe even grab it from whatever SteamGameServer api stuff makes it available if possible.
	https://github.com/alliedmodders/sourcemod/pull/545
	https://github.com/alliedmodders/sourcemod/issues/1315
	https://github.com/alliedmodders/sourcemod/pull/1544
*/
stock void SanerGetClientName(int client, char[] name)
{
	static EngineVersion ev = Engine_Unknown;

	if (ev == Engine_Unknown)
	{
		ev = GetEngineVersion();
	}

	GetClientName(client, name, 32+1);

	// CSGO doesn't have this problem because `MAX_PLAYER_NAME_LENGTH` is 128...
	if (ev == Engine_CSGO)
	{
		return;
	}

	int len = strlen(name);

	if (len == 31)
	{
		for (int i = 0; i < 3; i++)
		{
			static int masks[3] = {0xC0, 0xE0, 0xF0};

			if ((name[len-i-1] & masks[i]) >= masks[i])
			{
				name[len-i-1] = 0;
				return;
			}
		}
	}
}
