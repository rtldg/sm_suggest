
#define CONFIRMATION_STRING "thx 4 suggestion. top (wo)men are on it <3"
#define CONFIRMATION_STRING_COLORS "\x075e70d0thx \x07db88c24 suggestion\x07af2a22. top (wo)men are \x07ffffffon it \x077fd772<3"
#define COLOR_PREFIX ""

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "!suggest",
	author = "rtldg",
	description = "!suggest messages to sourcemod/logs/suggest.log",
	version = "1.0.1",
	url = "https://github.com/rtldg/sm_suggest"
}

char gS_Map[PLATFORM_MAX_PATH];
bool gB_Protobuf = false;

public void OnPluginStart()
{
	gB_Protobuf = (GetUserMessageType() == UM_Protobuf);
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

	char filepath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filepath, sizeof(filepath), "logs/suggest.log");
	LogToFileEx(filepath, "%L (%s) %s", client, gS_Map, message);

	if (client == 0)
	{
		PrintToServer(CONFIRMATION_STRING);
	}
	else
	{
		char sBuffer[256];

		FormatEx(sBuffer, (gB_Protobuf ? sizeof(sBuffer) : 253), "%s%s", (gB_Protobuf ? " ":""), CONFIRMATION_STRING_COLORS);

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
