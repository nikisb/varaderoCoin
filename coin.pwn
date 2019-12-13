#include <YSI_Coding\y_hooks>

static coinPickup;
static bool:nadjen;

#define MAX_COINS 20

enum e_CoinLocations
{
	coinSQLID,
	Float:X,
	Float:Y,
	Float:Z,
	coinAdress[28]
};
new coinInfo[MAX_COINS][e_CoinLocations];

new Iterator:CoinList<MAX_COINS>;


DEFINE_HOOK_REPLACEMENT(OnPlayer, OP_);
hook OP_PickUpDynamicPickup(playerid, pickupid)
{
	if(pickupid == coinPickup)
	{				
		va_SendClientMessageToAll(SERVER_COLOR, "Varadero » %s"BELA" ["col_server"%d"BELA"] je pronasao "col_server"Varadero Coin.", ImeIgraca(playerid), playerid);
		PlayerInfo[playerid][xCoin]++;
		sql_user_update_integer( playerid, "xCoin", PlayerInfo[ playerid ][ xCoin ] );
		nadjen = true;		
		if(IsValidDynamicPickup(coinPickup))		
			DestroyDynamicPickup(coinPickup);		
	}
}
hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if(dialogid == DIALOG_COINLOKACIJE)
	{
		if(!response) return 1;
		if(response)
		{	
			new id = 0;
			foreach(new i:CoinList)
			{
				if(listitem == i) break;
				id++;
			}
			SetPlayerPos(playerid, coinInfo[id][X], coinInfo[id][Y]+5, coinInfo[id][Z]);
		}		
		return 1;
	}
	return 0;
}
// timeri

task pocetakTrazenja[60000]()
{
	kreirajCoin();
}

timer nijeNadjen[30000]()
{
	if(nadjen == true) return 1;	
	SendClientMessageToAll(SERVER_COLOR, "Varadero » "BELA"Niko nije pronasao "col_server"Varadero Coin"BELA", novo trazenje za 30 minuta.");
	if(IsValidDynamicPickup(coinPickup))
	DestroyDynamicPickup(coinPickup);
	return 1;
}

// funkcije
kreirajCoin()
{
	if(Iter_Count(CoinList) == 0) return SendClientMessageToAll(CRVENA, "Nije kreirana ni jedna pozicija za COIN!, kontaktirajte admine!");
	new randomizacija = Iter_Random(CoinList);
	if(IsValidDynamicPickup(coinPickup))
		DestroyDynamicPickup(coinPickup);
	coinPickup = CreateDynamicPickup(19607, 1, coinInfo[randomizacija][X], coinInfo[randomizacija][Y], coinInfo[randomizacija][Z], -1, -1, -1, 200, -1, 0);
	va_SendClientMessageToAll(SERVER_COLOR, "Varadero » "BELA"Kreiran je "col_server"Varadero Coin "BELA"u blizini "col_server"%s "BELA"imate 30 minuta da ga pronadjete!",coinInfo[randomizacija][coinAdress]);
	nadjen = false;
	defer nijeNadjen();	
	return 1;
}

protected LoadCoins()
{
	new rows = cache_num_rows();
	if(rows) 
	{
		for(new i; i < rows; i++) 
		{
			new id = Iter_Free(CoinList);

			coinInfo[id][coinSQLID]     = cache_get_field_content_int(i, "coinSQLID");
			coinInfo[id][X]	 			= cache_get_field_content_float(i, "x");
			coinInfo[id][Y]		 		= cache_get_field_content_float(i, "y");
			coinInfo[id][Z]				= cache_get_field_content_float(i, "z");
			cache_get_field_content( i, "coinAdress", coinInfo[id][coinAdress], mySQLKonekcija, 28 );

			Iter_Add(CoinList, id);
		}
	}
	printf("Varadero SQL - Ucitavanje: Varadero Coins (%d)", rows);	
	return 1;
}

stock Get2DPosZone(Float:x, Float:y, zone[], len)
{
 	for(new i = 0; i != sizeof(gSAZones); i++ )
 	{
		if(x >= gSAZones[i][SAZONE_AREA][0] && x <= gSAZones[i][SAZONE_AREA][3] && y >= gSAZones[i][SAZONE_AREA][1] && y <= gSAZones[i][SAZONE_AREA][4])
		{
		    return format(zone, len, gSAZones[i][SAZONE_NAME], 0);
		}
	}
	return 0;
}


// Komande

CMD:kreirajcoin(playerid, params[])
{
	if(PlayerInfo[playerid][xAdmin] < 7 && !IsPlayerAdmin(playerid)) return SendErrorMessage(playerid, "Niste ovlasceni!");
	new id = Iter_Free(CoinList),
	Float:Xz, Float:Yz, Float:Zz,
	coinAdresa[28];

	GetPlayerPos(playerid, Xz,Yz,Zz);
	Get2DPosZone(Xz,Yz,coinAdresa, 28);

	new query[132];
	Iter_Add(CoinList, id);
	coinInfo[id][coinSQLID] = id;						
	coinInfo[id][X] = Xz;
	coinInfo[id][Y] = Yz;
	coinInfo[id][Z] = Zz;	
	strcpy(coinInfo[id][coinAdress], coinAdresa);	

	mysql_format(mySQLKonekcija, query, sizeof(query), "INSERT INTO `coinLocations` (`x`, `y`, `z`, `coinAdress`) VALUES ('%f', '%f', '%f', '%s');", Xz, Yz, Zz, coinAdresa);
	mysql_tquery(mySQLKonekcija, query);
	printf(query);

	SendInfoMessage(playerid, "Uspjesno si kreirao novu lokaciju za coin ID: %d ukupno lokacija: %d", id, Iter_Count(CoinList));
	return 1;
}

CMD:obrisicoin(playerid, params[])
{
	if(PlayerInfo[playerid][xAdmin] < 7 && !IsPlayerAdmin(playerid)) return SendErrorMessage(playerid, "Niste ovlasceni!");
	new id;
	if(sscanf(params, "d", id)) return SendUsageMessage(playerid, "/obrisicoin [ID]");

	if(!Iter_Contains(CoinList, id)) return SendErrorMessage(playerid, "Pogresan ID!");
	new query[52+1];
	mysql_format(mySQLKonekcija, query, sizeof(query), "DELETE FROM `coinLocations` WHERE `coinSQLID`= %d", coinInfo[id][coinSQLID]);
	mysql_tquery(mySQLKonekcija, query);
	SendInfoMessage(playerid, "Uspesno ste obrisali lokaciju za coin ID: %d", id);
	Iter_Remove(CoinList, id);
	return 1;
}
CMD:coinlokacije(playerid, params[])
{
	if(PlayerInfo[playerid][xAdmin] < 7 && !IsPlayerAdmin(playerid)) return SendErrorMessage(playerid, "Niste ovlasceni!");
	new coinStr[40], coinDialog[720], x = 0;
	strcat(coinDialog, "ID\tLokacija Coina");
	foreach(new i:CoinList)
	{
		format(coinStr, sizeof(coinStr), "\n[%d]\t%s", i, coinInfo[i][coinAdress]);
		strcat(coinDialog, coinStr);
		x++;
	}
	ShowPlayerDialog(playerid, DIALOG_COINLOKACIJE, DIALOG_STYLE_TABLIST_HEADERS, D_NASLOV, coinDialog, "Odaberi", "Odustani");	
	if(x == 0) return SendErrorMessage(playerid, "Trenutno nema kreiranih lokacija za coin, kreirajte ih!");
	return 1;
}
