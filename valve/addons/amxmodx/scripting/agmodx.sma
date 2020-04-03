/*
	Adrenaline Gamer Mod X by rtxa

	Acknowledgements:
	Bullit for creating Adrenaline Gamer
	Lev for his Bugfixed and Improved HL Release
	KORD_27 for his hl.inc

	Information:
	An improved Mini AG alternative, made as a plugin for AMX Mod X from zero, to make it easier add improvements, features, fix annoying bugs, etc.
	
	Features:
	AMX Mod X 1.9 or newer
	Bugfixed and Improved HL Release
	Multilingual (Spanish and English 100%)

	More info in: aghl.ru/forum/viewtopic.php?f=19&t=2926
	Contact: usertxa@gmail.com or Discord rtxa#6795
*/

#include <agmodx>
#include <agmodx_const>
#include <agmodx_stocks>
#include <amxmisc>
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <hlstocks>

#define PLUGIN  "AG Mod X"
#define VERSION "Beta 2.0"
#define AUTHOR  "rtxA"

#pragma semicolon 1

// TaskIDs
enum (+=100) {
	TASK_STARTMATCH = 1000,
	TASK_STARTVERSUS,
	TASK_SENDVICTIMTOSPEC,
	TASK_SENDTOSPEC,
	TASK_SHOWSETTINGS,
	TASK_TIMELEFT
};

new Array:gAgCmdList;

// Location system
new gLocationName[128][32]; 		// Max locations (128) and max location name length (32);
new Float:gLocationOrigin[128][3]; 	// Max locations and origin (x, y, z)
new gNumLocations;

// Game player equip
new bool:gGamePlayerEquipExists;

#define TIMELEFT_SETUNLIMITED -1

// timeleft / timelimit system
new gTimeLeft; // if timeleft is set to -1, it means unlimited time
new gTimeLimit;

new cvarhook:gHookCvarTimeLimit;

// ag hud color
new gHudRed, gHudGreen, gHudBlue;

// play_team cmd
new Float:gPlayTeamDelayTime[33];
	
// gamerules flags
new bool:gBlockCmdKill;
new bool:gBlockCmdSpec;
new bool:gBlockCmdDrop;
new bool:gBlockPlayerSpawn;
new bool:gSendVictimToSpec;
new bool:gSendConnectingToSpec;
new bool:gIsSuddenDeath;

// agstart
new bool:gVersusStarted;
new gStartVersusTime;

// Team info
new gNumTeams;
new gTeamsName[HL_MAX_TEAMS][HL_TEAMNAME_LENGTH];
new gTeamsScore[HL_MAX_TEAMS];

// hud sync handles
new gHudDisplayVote;
new gHudShowMatch;
new gHudShowTimeLeft;

// agpause
new bool:gIsPause;

new gGameModeName[32];

// restore score system: array index
#define SCORE_FRAGS 0
#define SCORE_DEATHS 1
new Trie:gTrieScoreAuthId; // handle where it saves all the authids of players playing a versus for rescore system...

// ============= vote system ===============
#define VOTE_YES 1
#define VOTE_NO -1

#define VOTE_RUNNING 0
#define VOTE_DENIED 1
#define VOTE_ACCEPTED 2

new Trie:gTrieVoteList;

new gVotePlayers[MAX_PLAYERS + 1]; // 1: vote yes; 0: didn't vote; -1; vote no;

new gVoteNumFor;
new gVoteNumAgainst;
new gVoteNumUndecided;

new gVoteOption;

new bool:gVoteIsRunning;

new Float:gVoteFailedTime; // in seconds
new Float:gVoteEndTime;
new Float:gVoteDisplayEndTime;

new gVoteCallerName[MAX_NAME_LENGTH];
new gVoteCallerUserId;

new gNumVoteArgs;
new gVoteArg1[32];
new gVoteArg2[32];

new gVoteOptionFwHandle;

new Float:gVoteNextThink = -1.0;
new Float:gVoteDisplayNextThink = -1.0;

// ============= END vote system ===============

// cvar pointers
new gCvarDebugVote;
new gCvarContact;
new gCvarGameMode;
new gCvarGameType;
new gCvarHudColor;
new gCvarSpecTalk;
new gCvarAllowVote;
new gCvarVoteFailedTime;
new gCvarVoteDuration;
new gCvarVoteOldStyle;
new gCvarAgStartMinPlayers;
new gCvarAgStartAllowUnlimited;
new gCvarAmxNextMap;

new gCvarBunnyHop;
new gCvarFallDamage;
new gCvarFlashLight;
new gCvarFootSteps;
new gCvarForceRespawn;
new gCvarFragLimit;
new gCvarFriendlyFire;
new gCvarSelfGauss;
new gCvarTimeLimit;
new gCvarWeaponStay;
new gCvarHeadShot;

new gCvarStartHealth;
new gCvarStartArmor;
new gCvarStartLongJump;

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

new gCvarBanWeapons[SIZE_BANWEAPONS];
new gCvarBanAmmo[SIZE_AMMOENTS];
new gCvarBanBattery;
new gCvarBanHealthKit;
new gCvarBanLongJump;
new gCvarReplaceEgonWithAmmo;

new const gWeaponClass[][] = {
	"weapon_357",
	"weapon_9mmAR",
	"weapon_9mmhandgun",
	"weapon_crossbow",
	"weapon_crowbar",
	"weapon_gauss",
	"weapon_egon",
	"weapon_handgrenade",
	"weapon_hornetgun",
	"weapon_rpg",
	"weapon_satchel",
	"weapon_shotgun",
	"weapon_snark",
	"weapon_tripmine"
};

new const gAmmoClass[][] = {
	"ammo_357",
	"ammo_9mmAR",
	"ammo_9mmbox",
	"ammo_9mmclip",
	"ammo_ARgrenades",
	"ammo_crossbow",
	"ammo_gaussclip",
	"ammo_rpgclip",
	"ammo_buckshot"
};

public plugin_precache() {
	// AG Mod X Version
	create_cvar("agmodx_version", VERSION, FCVAR_SERVER);

	gCvarContact = get_cvar_pointer("sv_contact");

	gCvarDebugVote = create_cvar("sv_ag_debug_vote", "0", FCVAR_SERVER);

	// Chat cvar
	gCvarSpecTalk = create_cvar("ag_spectalk", "0", FCVAR_SERVER | FCVAR_SPONLY);

	// Agstart cvars
	gCvarAgStartMinPlayers = create_cvar("sv_ag_start_minplayers", "2", FCVAR_SERVER);
	gCvarAgStartAllowUnlimited = create_cvar("sv_ag_start_allowunlimited", "0", FCVAR_SERVER); // block start versus with unlimited time
	
	// Vote cvars
	gCvarAllowVote = create_cvar("sv_ag_allow_vote", "1", FCVAR_SERVER | FCVAR_SPONLY);
	gCvarVoteFailedTime = create_cvar("sv_ag_vote_failed_time", "15", FCVAR_SERVER | FCVAR_SPONLY, "", true, 0.0, true, 999.0);
	gCvarVoteDuration = create_cvar("sv_ag_vote_duration", "30", FCVAR_SERVER, "", true, 0.0, true, 999.0);
	gCvarVoteOldStyle = create_cvar("sv_ag_vote_oldstyle", "0", FCVAR_SERVER);

	// Gamemode cvars
	gCvarGameMode = create_cvar("sv_ag_gamemode", "tdm", FCVAR_SERVER | FCVAR_SPONLY);
	gCvarGameType = create_cvar("sv_ag_gametype", "", FCVAR_SERVER | FCVAR_SPONLY);
	gCvarBanHealthKit = create_cvar("sv_ag_ban_healthkit", "0");
	gCvarBanBattery = create_cvar("sv_ag_ban_battery", "0");
	gCvarBanLongJump = create_cvar("sv_ag_ban_longjump", "0");
	gCvarReplaceEgonWithAmmo = create_cvar("sv_ag_replace_egonwithammo", "0");
	gCvarStartHealth = create_cvar("sv_ag_start_health", "100");
	gCvarStartArmor = create_cvar("sv_ag_start_armor", "0");
	gCvarStartLongJump = create_cvar("sv_ag_start_longjump", "0");

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = create_cvar(gAgStartWeapons[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = create_cvar(gAgStartAmmo[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarBanWeapons; i++)
		gCvarBanWeapons[i] = create_cvar(gAgBanWeapons[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarBanAmmo; i++)
		gCvarBanAmmo[i] = create_cvar(gAgBanAmmo[i], "0", FCVAR_SERVER);

	// Multiplayer cvars
	gCvarHeadShot = create_cvar("mp_headshot", "1.0", FCVAR_SERVER);
	gCvarBunnyHop = get_cvar_pointer("mp_bunnyhop");
	gCvarFallDamage = get_cvar_pointer("mp_falldamage");
	gCvarFlashLight = get_cvar_pointer("mp_flashlight");
	gCvarFootSteps = get_cvar_pointer("mp_footsteps");
	gCvarForceRespawn = get_cvar_pointer("mp_forcerespawn");
	gCvarFragLimit = get_cvar_pointer("mp_fraglimit");
	gCvarFriendlyFire = get_cvar_pointer("mp_friendlyfire");
	gCvarSelfGauss = get_cvar_pointer("mp_selfgauss");
	gCvarTimeLimit = get_cvar_pointer("mp_timelimit");
	gCvarWeaponStay = get_cvar_pointer("mp_weaponstay");

	// AG Hud Color
	gCvarHudColor = create_cvar("sv_ag_hud_color", "255 255 0", FCVAR_SERVER | FCVAR_SPONLY); // yellow

	new color[32];
	get_pcvar_string(gCvarHudColor, color, charsmax(color));
	GetStrColor(color, gHudRed, gHudGreen, gHudBlue);

    // keep ag hud color updated
	hook_cvar_change(gCvarHudColor, "CvarHudColorHook");

	// Load mode cvars
	new mode[32];
	get_pcvar_string(gCvarGameMode, mode, charsmax(mode));

	server_cmd("exec gamemodes/%s.cfg", mode);
	server_exec();
}

public plugin_natives() {
	register_native("ag_vote_add", "native_ag_vote_add");
	register_native("ag_vote_remove", "native_ag_vote_remove");
	register_native("ag_vote_exists", "native_ag_vote_exists");
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	// Cache models from teamlist
	GetTeamListModels(gTeamsName, HL_MAX_TEAMS, gNumTeams); // This will fix VGUI Viewport
	CacheTeamListModels(gTeamsName, HL_MAX_TEAMS);

	// Get locations from locs/<mapname>.loc file
	GetLocations(gLocationName, 32, gLocationOrigin, gNumLocations);

	// Multilingual
	register_dictionary("agmodx.txt");
	register_dictionary("agmodx_help.txt");
	register_dictionary("agmodx_votehelp.txt");

	// amxx help translations
	register_dictionary("adminhelp.txt");

	// show current AG mode on game description when you find servers
	register_forward(FM_GetGameDescription, "FwGameDescription");

	// player's hooks
	RegisterHam(Ham_TraceAttack, "player", "PlayerTraceAttack");
	RegisterHam(Ham_Killed, "player", "PlayerPostKilled", true);
	RegisterHam(Ham_Spawn, "player", "PlayerPostSpawn", true);
	RegisterHam(Ham_Spawn, "player", "PlayerPreSpawn");

	gAgCmdList = ArrayCreate();

	ag_register_concmd("agabort", "CmdAgAbort", ADMIN_BAN, "AGCMD_AGABORT", _, true);
	ag_register_concmd("agallow", "CmdAgAllow", ADMIN_BAN, "AGCMD_AGALLOW", _, true);
	ag_register_concmd("agpause", "CmdAgPause", ADMIN_BAN, "AGCMD_AGPAUSE", _, true);
	ag_register_concmd("agstart", "CmdAgStart", ADMIN_BAN, "AGCMD_AGSTART", _, true);
	ag_register_concmd("agnextmode", "CmdAgNextMode", ADMIN_BAN, "AGCMD_AGNEXTMODE", _, true);
	ag_register_concmd("agnextmap", "CmdAgNextMap", ADMIN_BAN, "AGCMD_AGNEXTMAP", _, true);
	ag_register_concmd("agmap", "CmdAgMap", ADMIN_BAN, "AGCMD_AGMAP", _, true);
	
	ag_register_concmd("aglistvotes", "CmdVoteHelp", ADMIN_ALL, "AGCMD_LISTVOTES", _, true);
	ag_register_concmd("timeleft", "CmdTimeLeft", ADMIN_ALL, "AGCMD_TIMELEFT", _, true);
	ag_register_clcmd("vote", "CmdVote", ADMIN_ALL, "AGCMD_VOTE", _, true);
	ag_register_clcmd("yes", "CmdVoteYes", ADMIN_ALL, "AGCMD_YES", _, true);
	ag_register_clcmd("no", "CmdVoteNo", ADMIN_ALL, "AGCMD_NO", _, true);
	ag_register_clcmd("settings", "ShowSettings", ADMIN_ALL, "AGCMD_SETTINGS", _, true);
	ag_register_clcmd("say settings", "ShowSettings", ADMIN_ALL, "AGCMD_SETTINGS", _, true);
	ag_register_clcmd("play_team", "PlayTeam", ADMIN_ALL, "AGCMD_PLAYTEAM", _, true);

	register_concmd("help", "CmdHelp", ADMIN_ALL, "AGCMD_HELP", _, true);

	register_clcmd("spectate", "CmdSpectate"); // block spectate
	register_clcmd("drop", "CmdDrop"); // block drop
	register_clcmd("jointeam", "CmdJoinTeam"); // this will make work the vgui
	register_clcmd("changeteam", "CmdChangeTeam");

	// i create this cmds to set pausable to 0
	register_clcmd("pauseAg", "CmdPauseAg");
	
	// debug for arena, lts and lms
	register_clcmd("userinfo", "CmdUserInfo");

	register_event_ex("30", "EventIntermissionMode", RegisterEvent_Global);

	// Chat and voice 
	register_message(get_user_msgid("SayText"), "MsgSayText");
	register_forward(FM_Voice_SetClientListening, "FwVoiceSetClientListening");

	// Useful for vote think, because it executes every server frame and works even in pause (workaround for set_task())
	register_forward(FM_AllowLagCompensation, "FwAllowLagCompensation");

	gHudDisplayVote = CreateHudSyncObj();
	gHudShowMatch = CreateHudSyncObj();
	gHudShowTimeLeft = CreateHudSyncObj();

	// this saves score of players that're playing a match
	// so if someone get disconnect by any reason, the score will be restored when he returns
	gTrieScoreAuthId = TrieCreate();
	
	CreateVoteSystem();
	StartTimeLeft();
	LoadGameMode();
	StartMode();
}

public FwAllowLagCompensation() {
	if (GetServerUpTime() >= gVoteNextThink && gVoteNextThink != -1) {
		VoteThink();
	}

	if (GetServerUpTime() >= gVoteDisplayNextThink && gVoteDisplayNextThink != -1) {
		VoteDisplayThink();
	}
}

public plugin_cfg() {
	// pause it because "say timeleft" shows wrong timeleft, unless we modify the amx plugin, or put the plugin first and create our own timeleft cmd...
	// humm, maybe use an agmodx_timeleft and disable this one...
	// then read setinfo from user so you can hide the timeleft and only use the one from you clien with timeleft
	pause("cd", "timeleft.amxx");

	// this should fix bad cvar pointer
	gCvarAmxNextMap = get_cvar_pointer("amx_nextmap");
}

public plugin_end() {
	disable_cvar_hook(gHookCvarTimeLimit);
	set_pcvar_num(gCvarTimeLimit, gTimeLimit);

	new TrieIter:handle = TrieIterCreate(gTrieVoteList);
	new value;
	while (!TrieIterEnded(handle)) {
		TrieIterGetCell(handle, value);
		DestroyForward(value);
		TrieIterNext(handle);
	}
	TrieIterDestroy(handle);
	TrieDestroy(gTrieVoteList);
	TrieDestroy(gTrieScoreAuthId);

	ArrayDestroy(gAgCmdList);
}

// Gamemode name that should be displayed in server browser and in splash with server settings data
public FwGameDescription() {
	forward_return(FMV_STRING, gGameModeName);
	return FMRES_SUPERCEDE;
}

public client_putinserver(id) {
	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));

	// restore score by authid
	if (ScoreExists(authid))
		set_task(1.0, "RestoreScore", id, authid, sizeof authid); // delay to avoid some scoreboard glitchs
	else if (gSendConnectingToSpec)
		set_task(0.1, "SendToSpec", id + TASK_SENDTOSPEC); // delay to avoid some scoreboard glitchs

	set_task(3.0, "ShowSettings", id);
	set_task(25.0, "DisplayInfo", id);
}

public client_disconnected(id) {
	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));

	remove_task(TASK_SENDTOSPEC + id);
	remove_task(TASK_SENDVICTIMTOSPEC + id);

	// save score by authid
	if (gVersusStarted && ScoreExists(authid)) {
		new frags = get_user_frags(id);
		new deaths = hl_get_user_deaths(id);
		SaveScore(id, frags, deaths);
		client_print(0, print_console, "%l", "MATCH_LEAVE", id, frags, deaths);
		log_amx("%L", LANG_SERVER, "MATCH_LEAVE", id, frags, deaths);
	}

	return PLUGIN_HANDLED;
}

public PlayerTraceAttack(victim, attacker, Float:damage, Float:dir[3], ptr, bits) {
	if (get_tr2(ptr, TR_iHitgroup) == HIT_HEAD)
		SetHamParamFloat(3, damage * get_pcvar_float(gCvarHeadShot));
	return HAM_IGNORED;
} 

public PlayerPreSpawn(id) {
	// if player has to spec, don't let him spawn...
	if (task_exists(TASK_SENDVICTIMTOSPEC + id) || gBlockPlayerSpawn)
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

public PlayerPostSpawn(id) {
	if (is_user_alive(id)) {// when player joins the server for the first time, he spawns dead...
		if (!gGamePlayerEquipExists) {
			SetPlayerEquipment(id);
		}
	}

	// when he spawn, the hud gets reset so allow him to show settings again
	remove_task(id + TASK_SHOWSETTINGS);
}

public client_kill() {
	if (gBlockCmdKill)
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

public PlayerPostKilled(victim, attacker) {
	if (gSendVictimToSpec)
		set_task(3.0, "SendVictimToSpec", victim + TASK_SENDVICTIMTOSPEC);

	if (gIsSuddenDeath) {
		StartIntermissionMode();
	}
}

stock bool:PlayerKilledHimself(victim, attacker) {
	return (!IsPlayer(attacker) || victim == attacker); // attacker can be worldspawn if player dies by fall
}

public ResetBpAmmo(id) {
	for (new i; i < sizeof gCvarStartAmmo; i++) {
		if (get_pcvar_num(gCvarStartAmmo[i]) != 0)  // only restore backpack ammo set in game_player_equip from the map
			set_ent_data(id, "CBasePlayer", "m_rgAmmo", get_pcvar_num(gCvarStartAmmo[i]), i + 1);
	}
}

public CmdTimeLeft(id) {
	client_print(id, print_console, "timeleft: %i:%02i", 
		gTimeLeft == TIMELEFT_SETUNLIMITED ? 0 : gTimeLeft / 60, // minutes
		gTimeLeft == TIMELEFT_SETUNLIMITED ? 0 : gTimeLeft % 60); // seconds
	return PLUGIN_HANDLED;
}

/*
* Timeleft/Timelimit System
*/
public StartTimeLeft() {
	// from now, i'm going to use my own timeleft and timelimit
	gTimeLimit = get_pcvar_num(gCvarTimeLimit);

	// set mp_timelimit always to empty (this way i can always track changes) and don't let anyone modify it.
	set_pcvar_string(gCvarTimeLimit, "");
	gHookCvarTimeLimit = hook_cvar_change(gCvarTimeLimit, "CvarTimeLimitHook");

	// Start my own timeleft
	gTimeLeft = gTimeLimit > 0 ? gTimeLimit * 60 : TIMELEFT_SETUNLIMITED;
	TimeLeftCountdown();
}

public TimeLeftCountdown() {
	if (task_exists(TASK_STARTVERSUS)) // when player send agstart, freeze timer
		return;

	if (gTimeLeft == 0) {
		UpdateTeamScores(gTeamsScore, gNumTeams);
		if (gVersusStarted && IsATieBreakNeeded(gTeamsScore, gNumTeams)) {
			gIsSuddenDeath = true;
		} else {
			StartIntermissionMode();
			return;
		}
	}

	ShowTimeLeft();

	set_task(1.0, "TimeLeftCountdown", TASK_TIMELEFT);

	gTimeLeft--;
}

public ShowTimeLeft() {
	new r = gHudRed;
	new g = gHudGreen;
	new b = gHudBlue;

	new timerText[128];

	// sudden death
	if (gTimeLeft <= 0 && gIsSuddenDeath) {
		r = 255; 
		g = 50;
		b = 50;

		FormatTimeLeft(abs(gTimeLeft), timerText, charsmax(timerText));
		set_hudmessage(r, g, b, -1.0, 0.02, 0, 0.01, 600.0, 0.01, 0.01);
		ShowSyncHudMsg(0, gHudShowTimeLeft, "%s^n%l", timerText, "SUDDEN_DEATH");

		return;
	}

	// normal behaviour
	if (gTimeLeft > 0) { 
		if (gTimeLeft < 60) { // set red color
			r = 255; 
			g = 50;
			b = 50; 
		}

		FormatTimeLeft(gTimeLeft, timerText, charsmax(timerText));

		set_hudmessage(r, g, b, -1.0, 0.02, 0, 0.01, 600.0, 0.01, 0.01);
		ShowSyncHudMsg(0, gHudShowTimeLeft, timerText);
	} else { // unlimited time
		set_hudmessage(r, g, b, -1.0, 0.02, 0, 0.01, 600.0, 0.01, 0.01); // flicks the hud with out this, maybe is a bug
		ShowSyncHudMsg(0, gHudShowTimeLeft, "%l", "TIMER_UNLIMITED");
	}

	return;
}

FormatTimeLeft(timeleft, output[], length) {
	new days, hours, minutes, seconds;

	const SECONDS_PER_MINUTE = 60;
	const SECONDS_PER_HOUR = SECONDS_PER_MINUTE * 60;
	const SECONDS_PER_DAY = SECONDS_PER_HOUR * 24;

	new seconds_total = timeleft;

	days = seconds_total / SECONDS_PER_DAY;
	seconds_total = seconds_total % SECONDS_PER_DAY;

	hours = seconds_total / SECONDS_PER_HOUR;
	seconds_total = seconds_total % SECONDS_PER_HOUR;

	minutes = seconds_total / SECONDS_PER_MINUTE;
	seconds_total = seconds_total % SECONDS_PER_MINUTE;

	seconds = seconds_total;

	if (days > 0) {
		formatex(output, length, "%id %ih %im %is", days, hours, minutes, seconds);	
	} else if (hours > 0)
		formatex(output, length, "%ih %02im %02is", hours, minutes, seconds);
	else if (minutes > 0)
		formatex(output, length, "%i:%02i", minutes, seconds);
	else // seconds
		formatex(output, length, "%i", seconds);
}

// Ex: If you set mp_timelimit to the same value, this will not get executed
public CvarTimeLimitHook(pcvar, const old_value[], const new_value[]) {
	// i disable the hook to avoid recursion (check cvars.inc)
	disable_cvar_hook(gHookCvarTimeLimit);
	
	new timeLimit = str_to_num(new_value);

	if (timeLimit == 0) {
		if (gVersusStarted && !get_pcvar_num(gCvarAgStartAllowUnlimited)) { // block start versus with unlimited time
			client_print(0, print_center, "%l", "MATCH_DENY_CHANGEUNLIMITED");
		} else {
			gTimeLeft = TIMELEFT_SETUNLIMITED;
			gTimeLimit = timeLimit;
		}
	} else {
		gTimeLeft =  timeLimit * 60;
		gTimeLimit = timeLimit;
	}

	// always leave it empty, so players can't change the cvar value and finish the map (go to intermission mode) by accident...	
	set_pcvar_string(pcvar, ""); 

	enable_cvar_hook(gHookCvarTimeLimit);
}

/* 
* AgStart
*/
public StartVersus() {
	if (get_playersnum() < get_pcvar_num(gCvarAgStartMinPlayers)) {
		client_print(0, print_center, "%l", "MATCH_MINPLAYERS_CENTER", get_pcvar_num(gCvarAgStartMinPlayers));
		return;
	} else if (gTimeLimit <= 0 && !get_pcvar_num(gCvarAgStartAllowUnlimited)) { // block start versus with mp_timelimit 0
		client_print(0, print_center, "%l", "MATCH_DENY_STARTUNLIMITED");
		return;
	}

	// remove previous start match even if doesn't exist
	remove_task(TASK_STARTVERSUS);

	// clean list of authids to begin a new match
	TrieClear(gTrieScoreAuthId);

	// gamerules
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	gBlockCmdKill = true;
	gSendConnectingToSpec = true;
	gBlockPlayerSpawn = true; // if player is dead on agstart countdown, he will be able to spawn...
	gIsSuddenDeath = false;

	// reset score and freeze players who are going to play versus
	new players[MAX_PLAYERS], numPlayers, player;
	get_players(players, numPlayers);

	for (new i; i < numPlayers; i++) {
		player = players[i];
		if (IsInWelcomeCam(player)) { // send to spec players in welcome cam 
			hl_set_user_spectator(player);
		} else if (!hl_get_user_spectator(player)) {
			SaveScore(player);
		}
		FreezePlayer(player);
	}

	// Reset map
	ResetMap();

	gStartVersusTime = 9;
	StartVersusCountdown();
}

public StartVersusCountdown() {
	PlayNumSound(0, gStartVersusTime);

	if (gStartVersusTime == 0) {
		gVersusStarted = true;

		gBlockCmdDrop = false;
		gBlockCmdKill = false;
		gBlockPlayerSpawn = false;

		TrieClear(gTrieScoreAuthId);

		// message holds a lot of time to avoid flickering, so I remove it manually
		ClearSyncHud(0, gHudShowMatch);

		new players[MAX_PLAYERS], numPlayers, player;
		get_players(players, numPlayers);

		for (new i; i < numPlayers; i++) {
			player = players[i];
			if (!hl_get_user_spectator(player)) {
				if (!IsInWelcomeCam(player)) {				
					ResetScore(player);
					SaveScore(player);
					hl_user_spawn(player);
					set_task(0.5, "ShowSettings", player);
				}
			} else {
				FreezePlayer(player, false);
			}
		}

		// it's seems that startversus is in the same frame when it's called, so it still being called
		remove_task(TASK_TIMELEFT);
		remove_task(TASK_STARTVERSUS);

		// set new timeleft according to timelimit
		gTimeLeft = gTimeLimit > 0 ? gTimeLimit * 60 : TIMELEFT_SETUNLIMITED;
		TimeLeftCountdown();

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 15.0, 0.2, 0.5);
	ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_START", gStartVersusTime);

	set_task(1.0, "StartVersusCountdown", TASK_STARTVERSUS);

	gStartVersusTime--;
}

/* 
* AgAbort
*/
public AbortVersus() {
	gVersusStarted = false;

	// clear authids to prepare for the next match
	TrieClear(gTrieScoreAuthId);

	// remove start match hud
	remove_task(TASK_STARTVERSUS);

	// restore gamerules
	gBlockCmdSpec = false;
	gBlockCmdDrop = false;
	gBlockCmdKill = false;
	gSendConnectingToSpec = false;
	gBlockPlayerSpawn = false;
	gIsSuddenDeath = false;

	// restore timeleft according to timelimit
	if (gIsSuddenDeath) {
		gTimeLeft = gTimeLimit > 0 ? gTimeLimit * 60 : TIMELEFT_SETUNLIMITED;
	}

	new players[32], numPlayers, player;
	get_players(players, numPlayers);

	for (new i; i < numPlayers; i++) {
		player = players[i];
		if (is_user_alive(player))
			FreezePlayer(player, false);
		else if (hl_get_user_spectator(player))
			hl_set_user_spectator(player, false);
	}
}

FreezePlayer(id, bool:freeze=true) {
	new flags = pev(id, pev_flags);
	if (freeze) {
		set_pev(id, pev_flags, flags | FL_FROZEN);
		set_pev(id, pev_solid, SOLID_NOT); // this will block weapon pick up
	} else {
		set_pev(id, pev_flags, flags & ~FL_FROZEN);
		set_pev(id, pev_solid, SOLID_BBOX);
	}
}


public SendToSpec(taskid) {
	new id = taskid - TASK_SENDTOSPEC;
	if (is_user_connected(id))
		hl_set_user_spectator(id, true);
}

public SendVictimToSpec(taskid) {
	new id = taskid - TASK_SENDVICTIMTOSPEC;
	if (is_user_connected(id)) {
		if (!is_user_alive(id) || is_user_bot(id)) {
			hl_set_user_spectator(id, true);
		}
	}
}

/*
* AG Say
*/
public MsgSayText(msg_id, msg_dest, receiver) {
	new text[191]; // 192 will crash the sv by overflow if someone send a large message with a lot of %l, %w, etc...
	
	get_msg_arg_string(2, text, charsmax(text)); // get user message
	
	if (text[0] == '*') // ignore server messages
		return PLUGIN_CONTINUE;

	new sender = get_msg_arg_int(1);
	new isReceiverSpec = hl_get_user_spectator(receiver);

	// note: if it's a player message, then it will start with escape character '2' (sets color with no sound)
	if (hl_get_user_spectator(sender)) {
		if (contain(text, "^x02(TEAM)") == 0) {
			if (!isReceiverSpec) // only show messages to spectator
				return PLUGIN_HANDLED;
			else
				replace(text, charsmax(text), "(TEAM)", "(ST)"); // Spectator Team
		} else {
			if (gVersusStarted && !get_pcvar_num(gCvarSpecTalk)) {
				if (sender == receiver)
					client_print(sender, print_chat, "%l", "SPEC_CANTTALK");
				return PLUGIN_HANDLED;
			} else {
				replace(text, charsmax(text), "^x02", "^x02(S) ");
			}
		}
	} else {
		if (contain(text, "^x02(TEAM)") == 0) { // Team
			if (isReceiverSpec)
				return PLUGIN_HANDLED;
			else
				replace(text, charsmax(text), "(TEAM)", "(T)"); 
		} else
			replace(text, charsmax(text), "^x02", "^x02(A) ");
			
	}

	// replace all %h with health
	replace_string(text, charsmax(text), "%h", fmt("%i", get_user_health(sender)), false);

	// replace all %a with armor
	replace_string(text, charsmax(text), "%a", fmt("%i", get_user_armor(sender)), false);

	// replace all %p with longjump
	replace_string(text, charsmax(text), "%p", hl_get_user_longjump(sender) ? "Yes" : "No", false);

	// replace all %l with location
	replace_string(text, charsmax(text), "%l", gLocationName[FindNearestLocation(sender, gLocationOrigin, gNumLocations)], false);

	// replace all %w with name of current weapon
	new ammo, bpammo, weaponid = get_user_weapon(sender, ammo, bpammo);

	if (weaponid) {
		new weaponName[32];
		get_weaponname(weaponid, weaponName, charsmax(weaponName));
		replace_string(weaponName, charsmax(weaponName), "weapon_", "");
		replace_string(text, charsmax(text), "%w", weaponName, false);
	}

	// replace all %q with ammo of current weapon
	new ammoMsg[16], arGrenades;

	if (weaponid == HLW_MP5)
		arGrenades = hl_get_user_bpammo(sender, HLW_CHAINGUN);

	FormatAmmo(weaponid, ammo, bpammo, arGrenades, ammoMsg, charsmax(ammoMsg));
	replace_string(text, charsmax(text), "%q", ammoMsg, false); 

	// send final message
	set_msg_arg_string(2, text);

	return PLUGIN_CONTINUE;
}

stock FormatAmmo(weaponid, ammo, bpammo, arGrenades, output[], len) {
	new formatOption;
	switch (weaponid) {
		case HLW_NONE: 		formatOption = 0;
		case HLW_CROWBAR:	formatOption = 0;
		case HLW_CROSSBOW: 	formatOption = 2;
		case HLW_GLOCK: 	formatOption = 2;
		case HLW_MP5: 		formatOption = 3;
		case HLW_PYTHON: 	formatOption = 2;
		case HLW_RPG: 		formatOption = 2;
		case HLW_SHOTGUN: 	formatOption = 2;
		default: 			formatOption = 1;
	}

	switch (formatOption) {
		case 0: copy(output, len, ""); 
		case 1: copy(output, len, fmt("%i", ammo < 0 ? bpammo : ammo + bpammo));
		case 2: copy(output, len, fmt("%i/%i", ammo, bpammo));
		case 3: copy(output, len, fmt("%i/%i/%i", ammo, bpammo, arGrenades));
	}
}

/*
* Block Voice of Spectators
*/
public FwVoiceSetClientListening(receiver, sender, bool:listen) {
	if (receiver == sender)
		return FMRES_IGNORED;

	if (gVersusStarted && !get_pcvar_num(gCvarSpecTalk) && hl_get_user_spectator(sender) && !hl_get_user_spectator(receiver)) {
		engfunc(EngFunc_SetClientListening, receiver, sender, false);
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

/*
* Location System
*/
public GetLocations(name[][], size, Float:origin[][], &numLocs) {
	new file[128], map[32], text[2048];

	get_mapname(map, charsmax(map));
	formatex(file, charsmax(file), "locs/%s.loc", map);
	
	if (file_exists(file))
		read_file(file, 0, text, charsmax(text));

	new i, j, nLen;
	j = -1;

	while (nLen < strlen(text)) {
		if (j == -1) {
			nLen += 1 + copyc(name[i], size, text[nLen], '#'); // you must plus one to skip #
			j++;
			numLocs++;
		} else {
			new number[16];
			
			nLen += 1 + copyc(number, sizeof number, text[nLen], '#'); // you must plus one to skip #
			origin[i][j] = str_to_float(number);
			
			j++;

			// if we finish to copy origin, then let's start with next location
			if (j > 2) {
				i++;
				j = -1;
			}
		}
	}
}

// return the index of the nearest location for the player from an array
public FindNearestLocation(id, Float:locOrigin[][3], numLocs) {
	new Float:userOrigin[3], Float:nearestOrigin[3], idxNearestLoc;
	
	pev(id, pev_origin, userOrigin);

	// initialize nearest origin with the first location
	nearestOrigin = locOrigin[0];
	
	for (new i; i < numLocs; i++) {
		if (vector_distance(userOrigin, locOrigin[i]) <= vector_distance(userOrigin, nearestOrigin)) {
			nearestOrigin = locOrigin[i];
			idxNearestLoc = i;
		}
	}

	return idxNearestLoc;
}

public CmdHelp(id, level, cid) {
	ProcessCmdHelp(id, .start_argindex = 1, .do_search = false, .main_command = "help");
	return PLUGIN_HANDLED;
}

ProcessCmdHelp(id, start_argindex, bool:do_search, const main_command[], const search[] = "")
{
	new user_flags = get_user_flags(id);

	// HACK: ADMIN_ADMIN is never set as a user's actual flags, so those types of commands never show
	if (user_flags > 0 && !(user_flags & ADMIN_USER))
	{
		user_flags |= ADMIN_ADMIN;
	}

	new clcmdsnum = ArraySize(gAgCmdList);

	const MaxDefaultEntries    = 10;
	const MaxCommandLength     = 32;
	const MaxCommandInfoLength = 128;

	new HelpAmount = MaxDefaultEntries; // default entries

	new start  = clamp(read_argv_int(start_argindex), .min = 1, .max = clcmdsnum) - 1; // Zero-based list;
	new amount = !id ? read_argv_int(start_argindex + 1) : HelpAmount;
	new end    = min(start + (amount > 0 ? amount : HelpAmount), clcmdsnum);

	console_print(id, "^n----- %l -----", "TITLE_CMDHELP");

	new info[MaxCommandInfoLength];
	new command[MaxCommandLength];
	new command_flags;
	new bool:is_info_ml;
	new index;

	for (index = start; index < end; ++index)
	{
		get_concmd(ArrayGetCell(gAgCmdList, index), command, charsmax(command), command_flags, info, charsmax(info), user_flags, id, is_info_ml);

		if (is_info_ml)
		{
			LookupLangKey(info, charsmax(info), info, id);
		}

		console_print(id, "%3d: %s %s", index + 1, command, info);
	}

	console_print(id, "----- %l -----", "HELP_ENTRIES", start + 1, end, clcmdsnum);

	formatex(command, charsmax(command), "%s%c%s", main_command, do_search ? " " : "", search);

	if (end < clcmdsnum)
	{
		console_print(id, "----- %l -----", "HELP_USE_MORE", command, end + 1);
	}
	else if (start || index != clcmdsnum)
	{
		console_print(id, "----- %l -----", "HELP_USE_BEGIN", command);
	}
}


public CmdSpectate(id) {
	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));

	if (!hl_get_user_spectator(id)) // note: setting score while player is in spec will mess up scoreboard (bugfixed hl bug?)
		ResetScore(id);

	if (gBlockCmdSpec) {
		if (!ScoreExists(authid)) // only players playing a match can spectate
			return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

// maybe we need to show old style menu because VGUI Viewport just let you select the first four teams.
public CmdChangeTeam(id) {
	ShowVGUITeamMenu(id);
	return PLUGIN_HANDLED;
}

public ShowVGUITeamMenu(id) {
	static msgVGUIMenu;

	if (!msgVGUIMenu)
		msgVGUIMenu = get_user_msgid("VGUIMenu");

	message_begin(MSG_ONE, get_user_msgid("VGUIMenu"), _, id);
	write_byte(2);
	message_end();
}

public CmdJoinTeam(id) {
	new option = read_argv_int(1); 
	switch (option) {
		case 1, 2, 3, 4: { // in vgui viewport there are only four buttons where you choose the first 4 teams, maybe is better to show a menu to show all team (max 10 teams)
			if (!equal(gTeamsName[option - 1], "")) {
				hl_set_user_model(id, gTeamsName[option - 1]);
				if (hl_get_user_spectator(id))
					client_cmd(id, "spectate");
			}
		}
	}
	return PLUGIN_HANDLED;
}

public CmdDrop() {
	if (gBlockCmdDrop)
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

// I made this function for foreigners so they can differentiate the order of the month and the day...
GetPluginBuildDate(output[], len) {
	format_time(output, len, "%d %b %Y", parse_time(__DATE__, "%m:%d:%Y")); // 15 Nov 2018
}

// We need to use director hud msg because there aren't enough hud channels, unless we make a better gui that use less channels
// We are limited to 128 characters, so that is bad for multilingual or to show more settings ...
public ShowSettings(id) {
	// avoid hud overlap
	if (task_exists(id + TASK_SHOWSETTINGS) || !is_user_connected(id))
		return;
		
	new arg[32], buildDate[32];

	// left - top
	GetPluginBuildDate(buildDate, charsmax(buildDate));
	get_pcvar_string(gCvarContact, arg, charsmax(arg));
	set_dhudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.02, 0, 0.0, 10.0, 0.2);
	show_dhudmessage(id, "AG Mod X %s Build %s^n%s", VERSION, buildDate, arg);

	// center - top
	if (gVersusStarted) {
		set_dhudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.02, 0, 0.0, 10.0, 0.2);
		show_dhudmessage(id, "^n%l", "MATCH_STARTED");
	}

	// right - top
	set_dhudmessage(gHudRed, gHudGreen, gHudBlue, -0.05, 0.02, 0, 0.0, 10.0, 0.2);
	show_dhudmessage(id, "%l", "SETTINGS_VARS", gGameModeName, gTimeLimit, 
		get_pcvar_num(gCvarFragLimit), 
		get_pcvar_num(gCvarFriendlyFire) ? "On" : "Off", 
		get_pcvar_num(gCvarForceRespawn) ? "On" : "Off",
		get_pcvar_num(gCvarSelfGauss) ? "On" : "Off");

	set_task(10.0, "ShowSettings", id + TASK_SHOWSETTINGS); // this will stop hud overlap
}

public CmdAgPause(id, level, cid) {
	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s", cmd);
		return PLUGIN_HANDLED;
	}

	log_amx("AgPause: %N", id);

	PauseGame();

	return PLUGIN_HANDLED;	
}

public CmdAgStart(id, level, cid) {
	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s", cmd);
		return PLUGIN_HANDLED;
	}

	new arg[32];
	read_argv(1, arg, charsmax(arg));

	if (equal(arg, "")) { 
		StartVersus();
		return PLUGIN_HANDLED;
	}

	// from here, where're going to get which players are going to play versus...
	new target[33], player;

	for (new i = 1; i < read_argc(); i++) {
		read_argv(i, arg, charsmax(arg));
		player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
		if (player)
			target[player] = player;
		else
			return PLUGIN_HANDLED;
	}

	
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_connected(i)) {
			if (i == target[i])
				hl_set_user_spectator(i, false);
			else {
				hl_set_user_spectator(i, true);
				set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
			}
		}		
	}

	log_amx("AgStart: %N", id);

	StartVersus();

	return PLUGIN_HANDLED;
}

public CmdAgAbort(id, level, cid) {
	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s", cmd);
		return PLUGIN_HANDLED;
	}

	log_amx("AgAbort: %N", id);

	AbortVersus();

	return PLUGIN_HANDLED;
}

public CmdAgAllow(id, level, cid) {
	if (!IsUserServer(id)) {
		new cmd[16], args[32];
		read_argv(0, cmd, charsmax(cmd));
		read_args(args, charsmax(args));
		client_cmd(id, "vote %s %s", cmd, args);
		return PLUGIN_HANDLED;
	}

	if (!gVersusStarted)
		return PLUGIN_HANDLED;

	new arg[32], player;
	read_argv(1, arg, charsmax(arg));

	if (equal(arg, ""))
		player = id;
	else 
		player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);

	if (!player)
		return PLUGIN_HANDLED;

	log_amx("AgAllow: %N to %N", id, player);

	AllowPlayer(player);

	return PLUGIN_HANDLED;
}

public AllowPlayer(id) {
	if (!is_user_connected(id) || !gVersusStarted)
		return PLUGIN_HANDLED;

	if (hl_get_user_spectator(id)) {
		// create a key for this new guy so i can save his score when he gets disconnect...
		SaveScore(id);

		hl_set_user_spectator(id, false);

		ResetScore(id);

		client_print(0, print_console, "%l", "MATCH_ALLOW", id);
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, -1.0, 0, 0.0, 5.0); 
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_ALLOW", id);	
	}

	return PLUGIN_HANDLED;
}

public CmdAgNextMode(id, level, cid) {
	new arg[32];
	read_argv(1, arg, charsmax(arg));
	strtolower(arg);

	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s %s", cmd, arg);
		return PLUGIN_HANDLED;
	}

	if (TrieKeyExists(gTrieVoteList, arg)) {
		log_amx("AgNextMode: ^"%s^" ^"%N^"", arg, id);
		set_pcvar_string(gCvarGameMode, arg); // set next mode
	} else {
		client_print(id, print_console, "%l", "INVALID_MODE");
	}

	return PLUGIN_HANDLED;
}

public CmdAgNextMap(id, level, cid) {
	new arg[32];
	read_argv(1, arg, charsmax(arg));

	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s %s", cmd, arg);
		return PLUGIN_HANDLED;
	}    

	if (is_map_valid(arg)) {
		log_amx("AgNextMap: ^"%s^" ^"%N^"", arg, id);
		set_pcvar_string(gCvarAmxNextMap, arg); // set new mode
	} else {
		client_print(id, print_console, "%l", "INVALID_MAP");
	}

	return PLUGIN_HANDLED;
}

public CmdChangeMode(id, level, cid) {
	new arg[32];
	read_argv(0, arg, charsmax(arg));
	strtolower(arg);

	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s", cmd);
		return PLUGIN_HANDLED;
	}   

	if (TrieKeyExists(gTrieVoteList, arg)) {
		log_amx("Change gamemode: ^"%s^" ^"%N^"", arg, id);
		ChangeMode(arg);
	}

	return PLUGIN_HANDLED;
}

public CmdAgMap(id, level, cid) {
	new arg[32];
	read_argv(1, arg, charsmax(arg));

	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s %s", cmd, arg);
		return PLUGIN_HANDLED;
	} 

	if (is_map_valid(arg)) {
		log_amx("AgMap: ^"%s^" ^"%N^"", id, arg);
		ChangeMap(arg);
	} else {
		console_print(id, "%l", "INVALID_MAP");
	}


	return PLUGIN_HANDLED;
}

public CmdUserInfo(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new target[32];
	read_argv(1, target, charsmax(target));

	if (equal(target, "")) {
		PrintUserInfo(id, id);
		return PLUGIN_HANDLED;
	}

	new player = cmd_target(id, target);

	if (!player)
		return PLUGIN_HANDLED;

	PrintUserInfo(id, player);

	return PLUGIN_HANDLED;
}

stock PrintUserInfo(caller, target) {
	new model[16];
	new team = hl_get_user_team(target);

	new iuser1 = pev(target, pev_iuser1);
	new iuser2 = pev(target, pev_iuser2);

	new alive = is_user_alive(target);
	new dead = pev(target, pev_deadflag);

	hl_get_user_model(target, model, charsmax(model));

	client_print(caller, print_chat, "Team: %i; Model: %s; iuser1: %i; iuser2: %i Alive: %i; Deadflag: %i IsInWelcomeCam: %i", team, model, iuser1, iuser2, alive, dead, IsInWelcomeCam(caller));
}

/* 
* Vote system
*/
CreateVoteSystem() {
	gTrieVoteList = TrieCreate();
	ag_vote_add("agabort", "OnVoteAgAbort");
	ag_vote_add("agallow", "OnVoteAgAllow");
	ag_vote_add("agnextmap", "OnVoteAgNextMap");
	ag_vote_add("agnextmode", "OnVoteAgNextMode");
	ag_vote_add("agpause", "OnVoteAgPause");
	ag_vote_add("agstart", "OnVoteAgStart");
	ag_vote_add("agmap", "OnVoteAgMap");
	ag_vote_add("map", "OnVoteAgMap");
	ag_vote_add("mp_bunnyhop", "OnVoteBunnyHop");
	ag_vote_add("mp_falldamage", "OnVoteFallDamage");
	ag_vote_add("mp_flashlight", "OnVoteFlashLight");
	ag_vote_add("mp_footsteps", "OnVoteFootSteps");
	ag_vote_add("mp_forcerespawn", "OnVoteForceRespawn");
	ag_vote_add("mp_fraglimit", "OnVoteFragLimit");
	ag_vote_add("mp_friendlyfire", "OnVoteFriendlyFire");
	ag_vote_add("mp_selfgauss", "OnVoteSelfGauss");
	ag_vote_add("mp_timelimit", "OnVoteTimeLimit");
	ag_vote_add("mp_weaponstay", "OnVoteWeaponStay");
	ag_vote_add("ag_gauss_fix", "OnVoteGaussFix");
}

public OnVoteTimeLimit(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}
	
	if (!check) {
		set_pcvar_string(gCvarTimeLimit, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
		new num = str_to_num(arg2);
		if (num < 0) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFriendlyFire(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}
	
	if (!check) {
		set_pcvar_string(gCvarFriendlyFire, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteBunnyHop(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}
	
	if (!check) {
		set_pcvar_string(gCvarBunnyHop, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFallDamage(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarFallDamage, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFlashLight(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarFlashLight, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFootSteps(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarFootSteps, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFragLimit(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarFragLimit, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteSelfGauss(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarSelfGauss, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteGaussFix(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		new num = str_to_num(arg2);
		set_pcvar_num(gCvarSelfGauss, !num);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteForceRespawn(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarForceRespawn, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteWeaponStay(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarWeaponStay, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteAgAbort(id, check, argc) {
	if (argc != 1) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check)
		AbortVersus();
	
	return true;
}

public OnVoteAgStart(id, check, argc) {
	if (argc != 1) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		StartVersus();
	} else {
		if (get_playersnum() < get_pcvar_num(gCvarAgStartMinPlayers)) {
			console_print(id, "%l", "MATCH_MINPLAYERS", get_pcvar_num(gCvarAgStartMinPlayers));
			return false;
		}
	}
	
	return true;
}

public OnVoteAgPause(id, check, argc) {
	if (argc != 1) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		PauseGame();
	}
	
	return true;
}

public OnVoteAgMap(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	// Rename vote always to agmap to be consistent
	formatex(arg1, 31, "%s", "agmap");

	if (!check) {
		ChangeMap(arg2);
	} else {
		if (!is_map_valid(arg2)) {
			client_print(id, print_console, "%l", "INVALID_MAP");
			return false;
		}
	}

	return true;
}

public OnVoteAgNextMap(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarAmxNextMap, arg2);
	} else {
		if (!is_map_valid(arg2)) {
			client_print(id, print_console, "%l", "INVALID_MAP");
			return false;
		}
	}

	return true;
}

public OnVoteAgNextMode(id, check, argc, arg1[], arg2[]) {
	if (argc != 1) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		ChangeMode(arg2);
	}

	return true;
}

public OnVoteAgAllow(id, check, argc, arg1[], arg2[]) {
	if (argc > 2) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	static userid;
	if (!check) {
		AllowPlayer(find_player_ex(FindPlayer_MatchUserId, userid));
	} else {
		new player;
		if (equal(arg2, "")) { // allow yourself
			userid = get_user_userid(id);
		} else if ((player = cmd_target(id, arg2, CMDTARGET_ALLOW_SELF))) {
			get_user_name(player, arg2, 31);
			userid = get_user_userid(player);
		} else {
			return false;
		}
	}

	return true;
}

public OnVoteChangeMode(id, check, argc, arg1[]) {
	if (!check)
		ChangeMode(arg1);
	return true;
}

LoadGameMode() {
	new fileName[32];
	new handleDir = open_dir("gamemodes", fileName, charsmax(fileName));

	if (!handleDir)
		return;

	new mode[32];
	get_pcvar_string(gCvarGameMode, mode, charsmax(mode));

	do {
		// get index for file type
		new len = strlen(fileName) - 4;
		if (len < 0) len = 0;

		if (equali(fileName[len], ".cfg")) {
			new name[32], info[64];
			
			read_file(fmt("gamemodes/%s", fileName), 0, name, charsmax(name)); // first line specifies what game name that should be displayed in server browser and in splash with server settings data
			read_file(fmt("gamemodes/%s", fileName), 1, info, charsmax(info)); // second line is help text displayed when someone types help in console
			
			replace_string(info, charsmax(info), "/", ""); // remove comments
			replace_string(name, charsmax(name), "/", ""); // remove comments

			trim(fileName);
			replace(fileName[len], charsmax(fileName), ".cfg", "");
			strtolower(fileName);

			if (equal(mode, fileName))
				gGameModeName = name;

			// create cmd and vote for gamemode
			ag_register_concmd(fileName, "CmdChangeMode", ADMIN_BAN, fmt("- %s", info));
			ag_vote_add(fileName, "OnVoteChangeMode"); 

			strtoupper(fileName);
			AddTranslation("en", CreateLangKey(fmt("%s%s", "AGVOTE_", fileName)), fmt("- %s", info));
			strtolower(fileName);
		}
	} while (next_file(handleDir, fileName, charsmax(fileName)));

	close_dir(handleDir);
}

public CmdGenericVote(id) {
	new args[128];
	new cmdName[32];
	read_argv(0, cmdName, charsmax(cmdName));
	read_args(args, charsmax(args));
	client_cmd(id, "vote %s %s", cmdName, args);
	return PLUGIN_HANDLED;
}

public CmdVoteYes(id) {
	gVotePlayers[id] = VOTE_YES;
	return PLUGIN_HANDLED;
}

public CmdVoteNo(id) {
	gVotePlayers[id] = VOTE_NO;
	return PLUGIN_HANDLED;
}

public CmdVote(id) {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("CmdVote");

	if (!get_pcvar_num(gCvarAllowVote))
		return PLUGIN_HANDLED;

	// Print help on console
	new argc = read_argc();
	if (argc == 1) {
		client_print(id, print_console, "%l", "VOTE_HELP");
		return PLUGIN_HANDLED;
	}

	// get timeleft to call a new vote
	new Float:timeleft = gVoteFailedTime - GetServerUpTime();

	if (timeleft > 0) {	
		client_print(id, print_console, "%l", "VOTE_DELAY", floatround(timeleft, floatround_floor));
		return PLUGIN_HANDLED;
	} else if (gVoteIsRunning) {
		client_print(id, print_console, "%l", "VOTE_RUNNING");
		return PLUGIN_HANDLED;
	}

	ResetVote();

	read_argv(1, gVoteArg1, charsmax(gVoteArg1));
	read_argv(2, gVoteArg2, charsmax(gVoteArg2));

	gVoteCallerUserId = get_user_userid(id);
	gNumVoteArgs = argc - 1;
	
	// If vote doesn't exist
	if (!TrieGetCell(gTrieVoteList, gVoteArg1, gVoteOptionFwHandle)) {
		client_print(id, print_console, "%l", "VOTE_NOTFOUND");
		return PLUGIN_HANDLED;
	}
	
	// execute vote callback, this checks that the required arguments are correct and gives a result
	new voteResult;
	ExecuteForward(gVoteOptionFwHandle, voteResult, id, true, gNumVoteArgs, PrepareArray(gVoteArg1, sizeof(gVoteArg1), true), PrepareArray(gVoteArg2, sizeof(gVoteArg2), true));

	if (!voteResult)
		return PLUGIN_HANDLED;

	get_user_name(id, gVoteCallerName, charsmax(gVoteCallerName));

	// Vote Log

	new voteArgs[128];
	if (strlen(gVoteArg2)) {
		formatex(voteArgs, charsmax(voteArgs), "%s %s", gVoteArg1, gVoteArg2);
	} else {
		formatex(voteArgs, charsmax(voteArgs), "%s", gVoteArg1);
	}

	log_amx("%L", LANG_SERVER, "LOG_VOTE_STARTED", voteArgs, id);

	// ==============
	new Float:time = GetServerUpTime();

	// Start Vote
	gVoteIsRunning = true;
	gVotePlayers[id] = VOTE_YES;

	gVoteNextThink = gVoteDisplayNextThink = time;
	gVoteEndTime = gVoteDisplayEndTime = time + get_pcvar_num(gCvarVoteDuration);
	
	return PLUGIN_HANDLED;
}

public VoteDisplayThink() {
	if (GetServerUpTime() > gVoteDisplayEndTime) {
		gVoteDisplayNextThink = -1.0;
		return;
	}

	if (get_pcvar_num(gCvarVoteOldStyle) <= 0)
		DisplayVote(gVoteOption);
	else
		DisplayVoteOldStyle(gVoteOption);
	
	gVoteDisplayNextThink = GetServerUpTime() + 1.0;
}

public VoteThink() {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("VoteThink");

	new Float:time = GetServerUpTime();

	if (time > gVoteEndTime) {
		gVoteIsRunning = false;
		
		gVoteOption = VOTE_DENIED;
		DenyVote();

		gVoteNextThink = -1.0;
		return;
	}

	gVoteOption = CalculateVote(gVoteNumFor, gVoteNumAgainst, gVoteNumUndecided);

	switch (gVoteOption) {
		case VOTE_ACCEPTED: DoVote();
		case VOTE_DENIED: DenyVote();
	}

	if (gVoteOption != VOTE_RUNNING) {
		gVoteIsRunning = false;
		gVoteDisplayEndTime = time + 3.0; // add 3 more seconds to show vote was denied or accepted
		gVoteNextThink = -1.0;
		return;
	}

	gVoteNextThink = GetServerUpTime() + 1.0;
}

CalculateVote(&numFor, &numAgainst, &numUndecided) {
	new players[MAX_PLAYERS], numPlayers;
	get_players(players, numPlayers);

	numFor = numAgainst = numUndecided = 0;

	// count votes
	for (new i; i < numPlayers; i++) {
		switch (gVotePlayers[players[i]]) {
			case VOTE_YES: numFor++;
			case VOTE_NO: numAgainst++;
		}
	}
	
	numUndecided = get_playersnum() - (numFor + numAgainst);

	// show vote hud
	if (numFor > numAgainst && numFor > numUndecided) // accepted
		return VOTE_ACCEPTED;
	else if (numAgainst > numFor && numAgainst > numUndecided) // denied
		return VOTE_DENIED;
	else // in progress
		return VOTE_RUNNING;
}

DisplayVote(option) {
	// reduce flickering by using long hold times.
	if (option == VOTE_RUNNING) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.125, 0, 0.0, get_pcvar_num(gCvarVoteDuration) + 5.0, 0.0, 0.0);
	} else {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.125, 0, 0.0, 5.0, 0.0, 0.0);
	}
	
	switch (option) {
		case VOTE_ACCEPTED:	ShowSyncHudMsg(0, gHudDisplayVote, "%l", "VOTE_ACCEPTED", gVoteArg1, gVoteArg2, gVoteCallerName);
		case VOTE_DENIED: 	ShowSyncHudMsg(0, gHudDisplayVote, "%l", "VOTE_DENIED", gVoteArg1, gVoteArg2, gVoteCallerName);
		case VOTE_RUNNING: 	ShowSyncHudMsg(0, gHudDisplayVote, "%l", "VOTE_START", gVoteArg1, gVoteArg2, gVoteCallerName, gVoteNumFor, gVoteNumAgainst, gVoteNumUndecided);
	}
}

DisplayVoteOldStyle(option) {
	switch (option) {
		case VOTE_ACCEPTED:	client_print(0, print_center,"%l", "VOTE_ACCEPTED", gVoteArg1, gVoteArg2, gVoteCallerName);
		case VOTE_DENIED: 	client_print(0, print_center, "%l", "VOTE_DENIED", gVoteArg1, gVoteArg2, gVoteCallerName);
		case VOTE_RUNNING: 	client_print(0, print_center,"%l", "VOTE_START", gVoteArg1, gVoteArg2, gVoteCallerName, gVoteNumFor, gVoteNumAgainst, gVoteNumUndecided);
	}
}

public DoVote() {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("DoVote");

	new caller = find_player_ex(FindPlayer_MatchUserId, gVoteCallerUserId);
	
	// if vote caller is not connected, cancel it...
	if (!caller)
		return;

	// Vote Log

	new voteArgs[128];
	if (strlen(gVoteArg2)) {
		formatex(voteArgs, charsmax(voteArgs), "%s %s", gVoteArg1, gVoteArg2);
	} else {
		formatex(voteArgs, charsmax(voteArgs), "%s", gVoteArg1);
	}

	log_amx("%L", LANG_SERVER, "LOG_VOTE_ACCEPTED", voteArgs, caller);

	// ==============

	ExecuteForward(gVoteOptionFwHandle, _, caller, false, gNumVoteArgs, PrepareArray(gVoteArg1, sizeof(gVoteArg1), true), PrepareArray(gVoteArg2, sizeof(gVoteArg2), true));
}

public DenyVote() {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("DenyVote");

	new caller = find_player_ex(FindPlayer_MatchUserId, gVoteCallerUserId);

	// Vote Log

	new voteArgs[128];
	if (strlen(gVoteArg2)) {
		formatex(voteArgs, charsmax(voteArgs), "%s %s", gVoteArg1, gVoteArg2);
	} else {
		formatex(voteArgs, charsmax(voteArgs), "%s", gVoteArg1);
	}

	log_amx("%L", LANG_SERVER, "LOG_VOTE_DENIED", voteArgs, caller);

	// ==============

	gVoteFailedTime = GetServerUpTime() + get_pcvar_num(gCvarVoteFailedTime);
}

public ResetVote() {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("ResetVote");

	gVoteIsRunning = false;

	gVoteArg1[0] = gVoteArg2[0] = '^0';

	// reset user votes
	arrayset(gVotePlayers, 0, sizeof gVotePlayers);	
}

public CmdVoteHelp(id) {
	ProcessVoteHelp(id, .start_argindex = 1, .main_command = "aglistvotes");
	return PLUGIN_HANDLED;
}

ProcessVoteHelp(id, start_argindex, const main_command[])
{
	const MaxDefaultEntries    = 10;
	const MaxCommandLength     = 32;
	const HelpAmount = MaxDefaultEntries;

	new clcmdsnum;

	new Array:cmdNameList = ArrayCreate(MaxCommandLength);
	{
		new TrieIter:handle = TrieIterCreate(gTrieVoteList);
		
		new cmd[32];

		while (!TrieIterEnded(handle)) {
			TrieIterGetKey(handle, cmd, sizeof(cmd));

			ArrayPushString(cmdNameList, cmd);

			TrieIterNext(handle);

			clcmdsnum++;
		}

		TrieIterDestroy(handle);
	}

	new start  = clamp(read_argv_int(start_argindex), .min = 1, .max = clcmdsnum) - 1; // Zero-based list;
	new amount = !id ? read_argv_int(start_argindex + 1) : HelpAmount;
	new end    = min(start + (amount > 0 ? amount : HelpAmount), clcmdsnum);

	console_print(id, "^n----- %l -----", "TITLE_VOTEHELP");

	new command[MaxCommandLength];
	new index;

	for (index = start; index < end; ++index) {
		ArrayGetString(cmdNameList, index, command, sizeof(command));

		new key[32];
		copy(key, sizeof(key), command);

		strtoupper(key);

		new langKey[32];
		formatex(langKey, charsmax(langKey), "%s%s", "AGVOTE_", key);

		if (GetLangTransKey(langKey) != TransKey_Bad)
			console_print(id, "%3d: %s %l", index + 1, command, langKey);
		else
			console_print(id, "%3d: %s %l", index + 1, command, "CMD_NOINFO");
	}

	console_print(id, "----- %l -----", "HELP_ENTRIES", start + 1, end, clcmdsnum);

	formatex(command, charsmax(command), "%s", main_command);

	if (end < clcmdsnum)
	{
		console_print(id, "----- %l -----", "HELP_USE_MORE", command, end + 1);
	}
	else if (start || index != clcmdsnum)
	{
		console_print(id, "----- %l -----", "HELP_USE_BEGIN", command);
	}

	ArrayDestroy(cmdNameList);

	return PLUGIN_HANDLED;
}

public ChangeMode(const mode[]) {
	set_pcvar_string(gCvarGameMode, mode); // set new mode

	// we need to reload the map so cvars can take effect
	new map[32];
	get_mapname(map, charsmax(map));
	set_pcvar_string(gCvarAmxNextMap, map);

	StartIntermissionMode();
}

// i want to show score when map finishes so you can take a pic, engine_changelevel() will change it instantly
public ChangeMap(const map[]) {
	set_pcvar_string(gCvarAmxNextMap, map);
	StartIntermissionMode();
} 

public PlayTeam(caller) {
	if (gPlayTeamDelayTime[caller] < get_gametime()) 
		gPlayTeamDelayTime[caller] = get_gametime() + 0.75;
	else 
		return PLUGIN_HANDLED;

	new sound[128];
	read_argv(1, sound, charsmax(sound));

	new team = hl_get_user_team(caller);

	new players[32], numPlayers, player;
	get_players_ex(players, numPlayers, GetPlayers_ExcludeDead);

	for (new i; i < numPlayers; i++) {
		player = players[i];
		if (team == hl_get_user_team(player))
			PlaySound(player, sound);
	}

	return PLUGIN_HANDLED;
}

StartMode() {
	new arg[32];
	get_pcvar_string(gCvarGameType, arg, charsmax(arg));
		
	// doesn't work in plugin_precache :/
	if (get_pcvar_num(gCvarReplaceEgonWithAmmo))
		ReplaceEgonWithAmmo();

	BanGamemodeEnts();

	SetGameModePlayerEquip(); //  set an equipment when user spawns
}

/*
* Set player equipment of current gamemode
*/
SetGameModePlayerEquip() {
	// i need to add maybe a check for game_player_equip that are not used in masters, whatever, only in spawn...
	new ent = find_ent_by_class(0, "game_player_equip");

	// if map has a game_player_equip, ignore gamemode cvars, looks like miniag works like that
	// also this will avoid problems in maps like 357_box or bootbox
	if (ent) {
		gGamePlayerEquipExists = true;
		return;
	}
	
	ent = create_entity("game_player_equip");

	for (new i; i < SIZE_WEAPONS; i++) {
		if (get_pcvar_num(gCvarStartWeapons[i]))
			DispatchKeyValue(ent, gWeaponClass[i], "1");
	}

	if (get_pcvar_bool(gCvarStartLongJump)) {
		DispatchKeyValue(ent, "item_longjump", "1");
	}
}

SetPlayerEquipment(id) {
	set_user_health(id, get_pcvar_num(gCvarStartHealth));
	set_user_armor(id, get_pcvar_num(gCvarStartArmor));

	ResetBpAmmo(id);
}


BanGamemodeEnts() {
	if (get_pcvar_num(gCvarBanLongJump))
		remove_entity_name("item_longjump");

	if (get_pcvar_num(gCvarBanBattery))
		remove_entity_name("item_battery");

	if (get_pcvar_num(gCvarBanHealthKit))
		remove_entity_name("item_healthkit");

	for (new i; i < SIZE_BANWEAPONS; i++) {
		if (get_pcvar_num(gCvarBanWeapons[i]))
			remove_entity_name(gWeaponClass[i]);
	}

	for (new i; i < SIZE_AMMOENTS; i++) {
		if (get_pcvar_num(gCvarBanAmmo[i]))
			remove_entity_name(gAmmoClass[i]);
	}
}

// Advertise about the use of some commands in AG mod x
public DisplayInfo(id) {
	client_print(id, print_chat, "%l", "DISPLAY_INFO1");
	client_print(id, print_chat, "%l", "DISPLAY_INFO2");
}

// We can't pause the game from the server because is not connected, unless you have created the sv in-game. "Can't pause, not connected."
PauseGame() {
	new players[MAX_PLAYERS], numPlayers;
	get_players(players, numPlayers);

	if (numPlayers < 1)
		return;
	
	set_cvar_num("pausable", 1);
	console_cmd(players[0], "pause; pauseAg");

	gIsPause = gIsPause ? false : true;
}

public CmdPauseAg(id) {
	set_cvar_num("pausable", 0);	
	return PLUGIN_HANDLED;
}

public ReplaceEgonWithAmmo() {
	new num, idx, ents[64], Float:origin[3];

	while (num < sizeof ents && (ents[num] = find_ent_by_class(idx, "weapon_egon"))) {
		idx = ents[num];
		num++;
	}

	for (new i; i < num; i++) {
		pev(ents[i], pev_origin, origin);
		remove_entity(ents[i]);

		ents[i] = create_entity("ammo_gaussclip");
		entity_set_origin(ents[i], origin);
		DispatchSpawn(ents[i]);
	}
}

/*
* Restore Score
*/
public bool:ScoreExists(const authid[]) {
	return TrieKeyExists(gTrieScoreAuthId, authid);
}

// save score by authid
SaveScore(id, frags = 0, deaths = 0) {
	new authid[MAX_AUTHID_LENGTH], score[2];

	get_user_authid(id, authid, charsmax(authid));

	score[SCORE_FRAGS] = frags;
	score[SCORE_DEATHS] = deaths;

	TrieSetArray(gTrieScoreAuthId, authid, score, sizeof score);
}

public GetScore(const authid[], &frags, &deaths) {
	new score[2];
	TrieGetArray(gTrieScoreAuthId, authid, score, sizeof score);

	frags = score[SCORE_FRAGS];
	deaths = score[SCORE_DEATHS];
}

public RestoreScore(authid[], id) {	
	new frags, deaths;

	if (ScoreExists(authid)) {
		GetScore(authid, frags, deaths);
		set_user_frags(id, frags);
		hl_set_user_deaths(id, deaths);
	}
}

ResetScore(id) {
	set_user_frags(id, 0);
	hl_set_user_deaths(id, 0);
}

public CvarHudColorHook(pcvar, const old_value[], const new_value[]) {
	GetStrColor(new_value, gHudRed, gHudGreen, gHudBlue);
}

public EventIntermissionMode() {
	gBlockCmdKill = true;
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	gVersusStarted = false; // allow specs at the end to talk

	new players[MAX_PLAYERS], numPlayers;
	get_players(players, numPlayers);

	for (new i; i < numPlayers; i++) {
		FreezePlayer(players[i]); // sometimes in intermission mode, player can move...
	}
}

public StartIntermissionMode() {
	new ent = create_entity("game_end");
	if (is_valid_ent(ent))
		ExecuteHamB(Ham_Use, ent, 0, 0, 1.0, 0.0);
}

UpdateTeamScores(team_scores[HL_MAX_TEAMS], numTeams) {
	if (numTeams < 2)
		return;

	arrayset(team_scores, 0, HL_MAX_TEAMS);

	new players[32], numPlayers;
	get_players(players, numPlayers);
	
	new plr, team;
	for (new i; i < numPlayers; i++) {
		plr = players[i];
		team = hl_get_user_team(plr); // actually if he is in spectator, he has no team...
		if (team)
			team_scores[team - 1] += hl_get_user_frags(plr);
	}
}

IsATieBreakNeeded(team_scores[HL_MAX_TEAMS], numTeams) {
	if (numTeams < 2)
		return false;

	// get max score
	new maxScore = team_scores[0];
	for (new i; i < numTeams; i++) {
		if (team_scores[i] > maxScore)
			maxScore = team_scores[i];
	}

	new matches;
	for (new i; i < numTeams; i++) {
		if (team_scores[i] == maxScore)
			matches++;
	}

	return matches > 1 ? true : false;
}

public CacheTeamListModels(teamlist[][], size) {
	new file[128];
	for (new i; i < size; i++) {
		formatex(file, charsmax(file), "models/player/%s/%s.mdl", teamlist[i], teamlist[i]);
		if (file_exists(file))
			engfunc(EngFunc_PrecacheModel, file);
	}
}

bool:IsObserver(id) {
	return get_ent_data(id, "CBasePlayer", "m_afPhysicsFlags") & PFLAG_OBSERVER > 0 ? true : false;
}


bool:IsInWelcomeCam(id) {
	return IsObserver(id) && !hl_get_user_spectator(id) && get_ent_data(id, "CBasePlayer", "m_iHideHUD") & (HIDEHUD_WEAPONS | HIDEHUD_HEALTH);
}

IsUserServer(id) {
	if (is_dedicated_server()) {
		if (!id) {
			return true;
		}
	} else { // listen server
		new ip[MAX_IP_LENGTH];
		get_user_ip(id, ip, charsmax(ip), true);
		if (equal(ip, "loopback")) {
			return true;
		}
	} 
	return false;
}

ag_register_concmd(const cmd[], const function[], flags = -1, const info[] = "", FlagManager = -1, bool:info_ml = false) {
	new idx = register_concmd(cmd, function, flags, info, FlagManager, info_ml);
	if (idx) {
		ArrayPushCell(gAgCmdList, idx);
	}
	return idx;
}

ag_register_clcmd(const cmd[], const function[], flags = -1, const info[] = "", FlagManager = -1, bool:info_ml = false) {
	new idx = register_clcmd(cmd, function, flags, info, FlagManager, info_ml);
	if (idx) {
		ArrayPushCell(gAgCmdList, idx);
	}
	return idx;
}

public native_ag_vote_add(plugin_id, argc) {
	if (argc < 2)
		return false;

	new voteName[32]; get_string(1, voteName, charsmax(voteName));
	new funcName[64]; get_string(2, funcName, charsmax(funcName)); // the callback function

	new fwHandle = CreateMultiForward(funcName, ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_ARRAY, FP_ARRAY);

	if (fwHandle == -1)
		return false;

	TrieSetCell(gTrieVoteList, voteName, fwHandle);

	// i hate this behaviour from miniag, it's much better to use all votes only with "vote <votename>"
	// because this way leads to a possibly overlap of commands from other plugins, whatever...
	register_clcmd(voteName, "CmdGenericVote");

	return true;
}

public native_ag_vote_remove(plugin_id, argc) {
	if (argc < 1)
		return false;

	new voteName[32]; get_string(1, voteName, charsmax(voteName));

	if (TrieKeyExists(gTrieVoteList, voteName)) {
		new handle;
		TrieGetCell(gTrieVoteList, voteName, handle);
		TrieDeleteKey(gTrieVoteList, voteName);
		DestroyForward(handle);
		return true;
	}

	return false;
}

public native_ag_vote_exists(plugin_id, argc) {
	if (argc < 1)
		return false;

	new voteName[32]; get_string(1, voteName, charsmax(voteName));

	if (TrieKeyExists(gTrieVoteList, voteName))
		return true;

	return false;
}
