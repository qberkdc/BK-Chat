#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <cstrike>

#define PLUGIN "[CH] Experienced Chat"
#define VERSION "1.21"
#define AUTHOR "--chcode"

#define MAX 150
#define TAG "CH"

//	Precache Types
#define PRE_MODEL 0
#define PRE_SOUND 1
#define PRE_GENERIC 2
#define PRE_MODEL_PLAYER 3

native get_user_gag_time(id);

new Tag[MAX][1024];
new TagAccess[MAX][1024];
new LastMsg[33][256]
new SpamBlock[33] = 0
new TagID
new FloodBlock[33]

new const CFGDIR[] = "addons/amxmodx/configs/"
new const CFGNAME[] = "ch_chat.cfg"
new const CUSTOM_CHAT_SOUND[] = "sound/chat.wav"

enum {
	SEC = 0,
	MIN,
	HOUR,
	DAY
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_clcmd("say", "CmdSay")
	register_clcmd("say_team", "CmdSayTeam")
	register_concmd("ch_tag_add", "cmd_add_tag")
	register_concmd("ch_cfg_tag_add", "auto_cmd_add_tag")
	register_concmd("ch_tag_reload", "ReloadTags")
	
	new cfgfile[128]; formatex(cfgfile, charsmax(cfgfile), "%s%s", CFGDIR,CFGNAME);
	if(!(file_exists(cfgfile)))
	{
		set_fail_state("Tag config's not found: %s requires", CFGNAME);
	}
	
	//	Cvars
	register_cvar("ch_flood_delay", "1.25")
	register_cvar("ch_spam_limit", "1")
	register_cvar("ch_dead_chat", "1")
	register_cvar("ch_custom_chat_sound", "1")
	register_cvar("ch_auto_advers_time", "0") 	// If you want do not send message, use zero value: 0 / default: 80
	register_cvar("ch_auto_advers_msg", "^^0[^^2%s^^0] ^^7This server using ^^3CH Chat^^7")
	register_cvar("ch_log_chat", "1");
}

stock time_format(time, time_array[]) {
	for(new i = 0; i < 86400; i++) {
		if(time > 0) {
			time -= 1;
			time_array[SEC] += 1;
		}
	}
	
	for(new i = 0; i < 1440; i++) {
		if(time_array[SEC] >= 60) {
			time_array[SEC] -= 60;
			time_array[MIN]++;
		}
	}
	
	for(new i = 0; i < 24; i++) {
		if(time_array[MIN] >= 60) {
			time_array[MIN] -= 60;
			time_array[HOUR]++;
		}
	}
	
	for(new i = 0; i < 1; i++) {
		if(time_array[HOUR] >= 24) {
			time_array[HOUR] -= 24;
			time_array[DAY]++;
		}
	}
}

public get_gag(id) {
	return get_user_gag_time(id);
}

public plugin_cfg()
{
	AutoTag(); TagCount();
	
	if(get_cvar_num("ch_auto_advers_time")) {
		set_task(float(get_cvar_num("ch_auto_advers_time")), "AutoAds", _, _, _, "b"); }
		
	if(get_cvar_num("ch_custom_chat_sound")) {
		StartPrecache(); }
}

//	Precache Files
public StartPrecache() {
	Precache(PRE_SOUND, CUSTOM_CHAT_SOUND, "");
}

//	Precache Method
public Precache(type, const file[], const loc[])
{
	new file_f[128]; new file_t[20]
	
	if(type == 0) file_t = "Model"; if(type == 1) file_t = "Sound"; if(type == 2) file_t = "Generic"; if(type == 3) file_t = "Model";
	
	if(type != 3)
		formatex(file_f, 127, "%s%s", loc, file);
	else
		formatex(file_f, 127, "%s%s/%s%s", loc, file, file, ".mdl");
		
	replace(file_f, 127, "sound/", "");
	
	if(file_exists(file_f)) {
		if(type == 3) server_print("%s  |  %s%s/%s%s", file_t, loc, file, file, ".mdl");
		if(type != 3) server_print("%s  |  %s%s", file_t, loc, file); }
	else {
		if(type == 3) server_print("%s  |  %s%s/%s%s", "Fail", loc, file, file, ".mdl");
		if(type != 3) server_print("%s  |  %s%s", "Fail", loc, file); }
	
	switch(type) {
		case 0: 	engfunc(EngFunc_PrecacheModel, file_f); case 1: 	engfunc(EngFunc_PrecacheSound, file_f); case 2: 	engfunc(EngFunc_PrecacheGeneric, file_f); case 3: 	engfunc(EngFunc_PrecacheModel, file_f);
	}
}

public client_disconnected(id)
{
	LastMsg[id] = ""
	SpamBlock[id] = 0
}

public ResetTagID()
{
	TagID = 1
}

public ReloadTags(id)
{
	if(!IsFlag(id, ADMIN_IMMUNITY))
	{
		client_print(id, print_console,"You can't use this command");
		return PLUGIN_HANDLED;
	}
	
	for(new i = 0;i < MAX; i++)
	{
		Tag[i] = ""
		TagAccess[i] = ""
	}
	
	TagID = 1
	server_cmd("exec %s%s", CFGDIR, CFGNAME)
	console_print(id, "^^0[^^2%s^^0] ^^7Tag's are reloaded", TAG)
	return PLUGIN_HANDLED;
}

public AutoTag()
{
	TagID = 1
	server_cmd("exec %s%s", CFGDIR, CFGNAME)
}

public TagCount()
{
	server_print("Added this server %d tags", TagID)
}

public AutoAds()
{
	if(get_cvar_num("ch_auto_advers_time"))
	{
		new txt_m[562]; get_cvar_string("ch_auto_advers_msg", txt_m, charsmax(txt_m));
		client_print(0, print_chat, txt_m);
	}
} 

public cmd_add_tag(id)
{
	if(!IsFlag(id, ADMIN_IMMUNITY))
	{
		client_print(id, print_console,"You can't use this command");
		return PLUGIN_HANDLED;
	}
	
	new Arg[2][1024]
	
	read_argv(1, Arg[0], 1023)
	read_argv(2, Arg[1], 1023)
	
	if(strlen(Arg[0]) < 2)
	{
		client_print(id, print_console,"Tag not added, tag name so short");
		server_print("Tag not added, tag name so short");
		return PLUGIN_HANDLED;
	}
	
	if(strlen(Arg[1]) < 1)
	{
		client_print(id, print_console,"Tag not added, tag flags so short");
		server_print("Tag not added, tag flags so short ");
		return PLUGIN_HANDLED;
	}
	
	for(new i = 1; i < MAX; i++)
	{
		if(equal(Tag[i], Arg[0]))
		{
			client_print(id, print_console,"Tag not added, already this tag name have");
			server_print("Tag not added, already this tag name have");
			return PLUGIN_HANDLED;
		}
	}

	new fileloc[128]
	formatex(fileloc, 127, "%s%s", CFGDIR, CFGNAME)
		
	new addcmd[128]
	formatex(addcmd, 127, "ch_cfg_add_tag ^"%s^" ^"%s^"", Arg[0], Arg[1])
		
	write_file(fileloc, addcmd)
		
	client_print(id, print_console,"Tag added successful")
	client_print(id, print_console,"Tag Name: %s", Arg[0])
	client_print(id, print_console,"Tag Flags: %s", Arg[1])
		
	setTag(Arg[0], Arg[1]);
	
	return PLUGIN_HANDLED;
}

public auto_cmd_add_tag(id)
{
	if(!IsFlag(id, ADMIN_IMMUNITY))
	{
		client_print(id, print_console,"You can't use this command");
		return PLUGIN_HANDLED;
	}
	
	new Arg[2][1024]
	
	read_argv(1, Arg[0], 1023)
	read_argv(2, Arg[1], 1023)
	
	if(strlen(Arg[0]) < 2)
	{
		client_print(id, print_console,"Tag not added, tag name so short");
		server_print("Tag not added, tag name so short");
		return PLUGIN_HANDLED;
	}
	
	if(strlen(Arg[1]) < 1)
	{
		client_print(id, print_console,"Tag not added, tag flags so short");
		server_print("Tag not added, tag flags so short ");
		return PLUGIN_HANDLED;
	}
	
	for(new i = 1; i < MAX; i++)
	{
		if(equal(Tag[i], Arg[0]))
		{
			client_print(id, print_console,"Tag not added, already this tag name have");
			server_print("Tag not added, already this tag name have");
			return PLUGIN_HANDLED;
		}
	}
	
	setTag(Arg[0], Arg[1]);
	
	return PLUGIN_HANDLED;
}

public CmdSay(id)
{
	SayMsg(id)
	return PLUGIN_HANDLED_MAIN;
}

public CmdSayTeam(id)
{
	if(get_user_team(id) == 3)
	{
		SayMsg(id)
	}
	else
	{
		SayTeamMsg(id)
	}
	
	return PLUGIN_HANDLED_MAIN;
}

public SayMsg(id)
{
	new Name[254]
	get_user_name(id, Name, charsmax(Name))
	new Message[254], Args[254];
	
	read_args(Args, 253)
	remove_quotes(Args)

	formatex(Message, charsmax(Message), "%s", Args)
	
	if(equali(Message, LastMsg[id]))
	{
		if(SpamBlock[id] < get_cvar_num("ch_spam_limit"))
			SpamBlock[id] += 1
	}
	else
	{
		SpamBlock[id] = 0
	}
	
	if(SpamBlock[id] == get_cvar_num("ch_spam_limit"))
	{
		client_print(id, print_chat, "^^0[^^2%s^^0] ^^7Please do not repeat same message", TAG)
		return PLUGIN_HANDLED
	}
		
	if(FloodBlock[id]) 
	{
		client_print(id, print_chat, "^^0[^^2%s^^0] ^^7Do it slowly ok?", TAG)
		return PLUGIN_HANDLED;
	}
	
	set_task(get_cvar_float("ch_flood_delay"), "un_flood", id)
	
	remove_color(Name, strlen(Name));
	remove_color(Message, strlen(Message));
	
	Send(0, id, print_chat, "%s%s ^^7%s: %s%s", is_user_alive(id) ? "" : get_user_team(id) == 3 ? "^^5(Spec) ^^7" : "^^1(Dead) ^^7", getTag(id), Name, isAdmin(id, ADMIN_CHAT) ? "^^2" : "^^7", Message)
	
	FloodBlock[id] = 1
	LastMsg[id] = Message
	
	return PLUGIN_HANDLED;
}

public SayTeamMsg(id)
{
	new Name[254]
	get_user_name(id, Name, charsmax(Name))
	new Message[254], Args[254];
	
	read_args(Args, 253)
	remove_quotes(Args)

	formatex(Message, charsmax(Message), "%s", Args)
	
	if(equali(Message, LastMsg[id]))
	{
		if(SpamBlock[id] < get_cvar_num("ch_spam_limit"))
			SpamBlock[id] += 1
	}
	else
	{
		SpamBlock[id] = 0
	}
	
	if(SpamBlock[id] == get_cvar_num("ch_spam_limit"))
	{
		client_print(id, print_chat, "^^0[^^2%s^^0] ^^7Please do not repeat same message", TAG)
		return PLUGIN_HANDLED
	}
		
	if(FloodBlock[id]) 
	{
		client_print(id, print_chat, "^^0[^^2%s^^0] ^^7Do it slowly ok?", TAG)
		return PLUGIN_HANDLED;
	}
	
	set_task(get_cvar_float("ch_flood_delay"), "un_flood", id)
	
	remove_color(Name, strlen(Name));
	remove_color(Message, strlen(Message));
	
	Send(1, id, print_chat, "%s^^3(Team) %s ^^7%s: %s%s", is_user_alive(id) ? "" : get_user_team(id) == 3 ? "^^5(Spec) ^^7" : "^^1(Dead) ^^7", getTag(id), Name, isAdmin(id, ADMIN_CHAT) ? "^^2" : "^^7", Message)
	
	FloodBlock[id] = 1
	LastMsg[id] = Message
	
	return PLUGIN_HANDLED;
}

public un_flood(id)
{
	FloodBlock[id] = 0
}

stock setTag(const tagName[1024], const tagFlags[1024])
{
	Tag[TagID] = tagName
	TagAccess[TagID] = tagFlags
			
	server_print("Tag Added: ID %d | %s  %s", TagID, tagName, tagFlags)
			
	TagID += 1
}

stock getUserFlags(id)
{
	new szFlag, szFlags[32]
	szFlag = get_user_flags(id)
	get_flags(szFlag, szFlags, 31)
	return szFlags;
}

stock getTag(id)
{
	new UserTag[1024];
	
	for(new i = 1;i <= MAX;i++)
	{
		if(strlen(Tag[i]) < 1)
		{
			UserTag = ""
			break;
		}
		
		if(equali(TagAccess[i], getUserFlags(id))) 
		{
			UserTag = Tag[i];
			break;
		}
	}
	
	return UserTag;
}

//	Stock : Check Flags by (Berk)
stock IsFlag(id, flag)
{
	if(get_user_flags(id) & flag)
	{ return true; }
	else
	{ return false; }
}

//	Stock : Send Message by (Berk)
stock Send(const team = 0, sender, type, const msg[], any:...)
{
	if(strlen(msg) < 1) {
		client_print(sender, print_chat, "^^0[^^2%s^^0] ^^7Your message cannot be empty", TAG)
		return PLUGIN_HANDLED;
	}
	
	new timestamp = get_systime();
	new times[4]; time_format(get_gag(sender)-timestamp, times);
	new fone[256]; formatex(fone, charsmax(fone), "%dd %dh %dm %ds", times[DAY], times[HOUR], times[MIN], times[SEC]);
	
	if(get_gag(sender) > timestamp) {
		client_print(sender, print_chat, "[CH-GAG] You are gagged! timeleft: %s", fone);
		return PLUGIN_HANDLED;
	} else {
		static text[1024]; vformat(text, 1023, msg, 5);
		
		if(get_cvar_num("ch_log_chat")) {
			new logtext[1024];
			
			format(logtext, charsmax(logtext), "%s", text);
			remove_color(logtext, charsmax(logtext));
			log_to_file("chat_log.txt", logtext);
		}
		
		server_print(text);
		
		for(new i = 1;i < get_maxplayers(); i++)
		{
			if(team)
			{
				if(get_user_team(sender) == get_user_team(i))
				{
					if(get_cvar_num("ch_dead_chat"))
					{
						client_print(i, type, text);
						client_print(i, print_console, text);
						if(get_cvar_num("ch_custom_chat_sound")) {
							client_cmd(i, "spk %s", CUSTOM_CHAT_SOUND); }
					}
					else
					{
						if(is_user_alive(sender))
						{
							client_print(i, type, text);
							client_print(i, print_console, text);
							if(get_cvar_num("ch_custom_chat_sound")) {
								client_cmd(i, "spk %s", CUSTOM_CHAT_SOUND); }
						}
						else if(!is_user_alive(i))
						{
							client_print(i, type, text);
							client_print(i, print_console, text);
							if(get_cvar_num("ch_custom_chat_sound")) {
								client_cmd(i, "spk %s", CUSTOM_CHAT_SOUND); }
						}
					}
				}
			}
			else
			{
				if(get_cvar_num("ch_dead_chat"))
				{
					client_print(i, type, text);
					client_print(i, print_console, text);
					if(get_cvar_num("ch_custom_chat_sound")) {
						client_cmd(i, "spk %s", CUSTOM_CHAT_SOUND); }
				}
				else
				{
					if(is_user_alive(sender))
					{
						client_print(i, type, text);
						client_print(i, print_console, text);
						if(get_cvar_num("ch_custom_chat_sound")) {
							client_cmd(i, "spk %s", CUSTOM_CHAT_SOUND); }
					}
					else if(!is_user_alive(i))
					{
						client_print(i, type, text);
						client_print(i, print_console, text);
						if(get_cvar_num("ch_custom_chat_sound")) {
							client_cmd(i, "spk %s", CUSTOM_CHAT_SOUND); }
					}
				}
			}
		}
	}
}

//	Stock : User is admin?
stock isAdmin(id, flag)
{
	if(get_user_flags(id) & flag)
	{ return 1; }
	else
	{ return 0; }
}