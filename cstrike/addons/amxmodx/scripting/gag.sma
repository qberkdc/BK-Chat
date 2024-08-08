#include <amxmodx>
#include <amxmisc>
#include <nvault>

#define PLUGIN  "[CH] Chat Gag"
#define VERSION "1.2"
#define AUTHOR  "Berk"

enum {
	SEC = 0,
	MIN,
	HOUR,
	DAY
}

new database
new datas[128]
new const dataname[32] = "GAG_DATABASE"
new const datakey[128] = "%s="

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_concmd("gag", "cmd_gag");
	register_concmd("ungag", "cmd_ungag");
	
	database = nvault_open(dataname);
}

public plugin_natives() {
	register_native("get_user_gag_time", "native_get_user_gag_time", 1);
}

public native_get_user_gag_time(id) {
	return datas[id];
}

public client_connect(id) {
	database_load(id);
}

public client_disconnected(id) {
	database_save(id);
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

public cmd_gag(id) {
	new user[128]; read_argv(1, user, charsmax(user));
	new time[128]; read_argv(2, time, charsmax(time));
	new target = cmd_target(id, user, 0);
	new amount = str_to_num(time);
	new timestamp = get_systime();
	
	if(!(flag_control(id, ADMIN_CHAT))) {
		client_print(id, print_console, "[CH-GAG] You are not authorized for this");
		return PLUGIN_HANDLED;
	}
	
	if(!target) {
		client_print(id, print_console, "[CH-GAG] User not found");
		return PLUGIN_HANDLED;
	}
	
	if(target == id) {
		client_print(id, print_console, "[CH-GAG] Nega is you !");
		return PLUGIN_HANDLED;
	}
	
	if((flag_control(target, ADMIN_IMMUNITY))) {
		client_print(id, print_console, "[CH-GAG] You are not gag this user is immunity");
		return PLUGIN_HANDLED;
	}
	
	if(is_user_bot(target)) {
		client_print(id, print_console, "[CH-GAG] User is bot");
		return PLUGIN_HANDLED;
	}
	
	if(!amount) {
		client_print(id, print_console, "[CH-GAG] You are negative amount entered");
		return PLUGIN_HANDLED;
	}
	
	if(amount > 86400) {
		amount = 86400;
	}
	
	if(datas[target] > timestamp) {
		client_print(id, print_console, "[CH-GAG] This player already gagged");
		return PLUGIN_HANDLED;
	}
	
	new admin_name[128]; get_user_name(id, admin_name, charsmax(admin_name));
	new target_name[128]; get_user_name(target, target_name, charsmax(target_name));
	new times[4]; time_format(amount, times);
	new fone[256]; formatex(fone, charsmax(fone), "%dD %dH %dM %dS", times[DAY], times[HOUR], times[MIN], times[SEC]);
	
	client_print(0, print_chat, "^7ADMIN %s^7 gagged his player %s^7 %s", admin_name, target_name, fone);
	datas[target] = timestamp + amount;
	database_save(target);
	
	return PLUGIN_HANDLED;
}

public cmd_ungag(id) {
	new user[128]; read_argv(1, user, charsmax(user));
	new timestamp = get_systime();
	new target = cmd_target(id, user, 0);
	
	if(!(flag_control(id, ADMIN_CHAT))) {
		client_print(id, print_console, "[CH-GAG] You are not authorized for this");
		return PLUGIN_HANDLED;
	}
	
	if(!target) {
		client_print(id, print_console, "[CH-GAG] User not found");
		return PLUGIN_HANDLED;
	}
	
	if(target == id) {
		client_print(id, print_console, "[CH-GAG] Nega is you !");
		return PLUGIN_HANDLED;
	}
	
	if(is_user_bot(target)) {
		client_print(id, print_console, "[CH-GAG] User is bot");
		return PLUGIN_HANDLED;
	}
	
	if(datas[target] < timestamp) {
		client_print(id, print_console, "[CH-GAG] This player already ungagged");
		return PLUGIN_HANDLED;
	}
	
	new admin_name[128]; get_user_name(id, admin_name, charsmax(admin_name));
	new target_name[128]; get_user_name(target, target_name, charsmax(target_name));
	
	client_print(0, print_chat, "^7ADMIN %s^7 ungagged his player %s", admin_name, target_name);
	datas[target] = timestamp-1;
	database_save(target);
	
	return PLUGIN_HANDLED;
}

public flag_control(id, flag) {
	if(get_user_flags(id) & flag) {
		return 1;
	}
	else {
		return 0;
	}
}

//	Save Data
public database_save(id) {
	new szAuth[33]; get_user_authid(id , szAuth , charsmax(szAuth));
	new szKey[64]; formatex(szKey , 63 , datakey , szAuth);
	new szData[256]; formatex(szData , 255 , "%d" , datas[id])
	
	nvault_pset(database , szKey , szData)
}

//	Load Data
public database_load(id) {
	new szAuth[33]; get_user_authid(id , szAuth , charsmax(szAuth));
	new szKey[40]; formatex(szKey , 63 , datakey , szAuth);
	new szData[256]; formatex(szData , 255, "%d", datas[id]);
	
	nvault_get(database, szKey, szData, 255)
	replace_all(szData , 255, "#", " ")
	
	new data[128]; parse(szData, data, 127);
	
	datas[id] = str_to_num(data);
}