/*

    CREATE TABLE csgo_table 
    (
        id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        steam_id varchar(64) NOT NULL UNIQUE KEY,
        rango int(2) NOT NULL DEFAULT '0',
        frags int(10) NOT NULL DEFAULT '0',
        Pj varchar(64) NOT NULL,
        hs int(10) NOT NULL DEFAULT '0',
        kills int(10) NOT NULL DEFAULT '0',
        deaths int(10) NOT NULL DEFAULT '0',
        ip varchar(64) NOT NULL
    );

*/

#include <amxmodx>
#include <reapi>
#include <sqlx>

#pragma semicolon 1

#define is_valid_player_alive(%0) (1 <= %0 <= MAX_PLAYERS && is_user_alive(%0))

#define ID_SHOWHUD (taskid - TASK_SHOWHUD)

#define MAXTAGADMS 50

public stock g_szPlugin[ ] = "Rangos CS:GO";
public stock g_szVersion[ ] = "1.0b";
public stock g_szAuthor[ ] = "Hypnotize";//no cambiar el autor
//chingen a su madre ratas con editions a la par del nombre

enum 
{ 
    STEAM_ID, 
    PASSWORD, 
    ADMIN_FLAGS, 
    ADMIN_TYPE, 
    ADMIN_TAG, 
    MAX 
};

enum _:eRangos
{
    rango_name[ 80 ],
    level_req,
    url_rango[ 120 ]
};

new const g_aRangos[ 19 ][ eRangos ] = 
{
    { "Unranked", 200, "https://i.ibb.co/HHzfg5T/0.png" },
    { "Silver I", 688, "https://i.ibb.co/hDWSG8d/1.png" },
    { "Silver II", 1000, "https://i.ibb.co/dgSPLD9/2.png" },
    { "Silver III", 1500, "https://i.ibb.co/Bc6jsjM/3.png" },
    { "Silver IV", 2000, "https://i.ibb.co/3pnjRS7/4.png" },
    { "Silver Elite", 3500, "https://i.ibb.co/GpkgZq0/5.png" },
    { "Silver Elite Master", 4000, "https://i.ibb.co/b6F3PPF/6.png" },
    { "Gold Nova I", 4300, "https://i.ibb.co/JjB8JYH/7.png" },
    { "Gold Nova II", 5700, "https://i.ibb.co/kmrfpqH/8.png" },
    { "Gold Nova III", 6000, "https://i.ibb.co/HVzW4jF/9.png" },
    { "Gold Nova Master", 7100, "https://i.ibb.co/7XMCzyV/10.png" },
    { "Master Guardian I", 8400, "https://i.ibb.co/q7s3Syr/11.png" },
    { "Master Guardian II", 9900, "https://i.ibb.co/hWSbXfh/12.png" },
    { "Master Guardian Elite", 10100, "https://i.ibb.co/P9GNsTk/13.png" },
    { "Distinguished Master Guardian", 11600, "https://i.ibb.co/6Dr0D41/14.png" },
    { "Legendary Eagle", 12000, "https://i.ibb.co/qd5J8Rh/15.png" },
    { "Legendary Eagle Master",13300, "https://i.ibb.co/fX5nPZx/16.png" },
    { "Supreme Master First Class", 14600, "https://i.ibb.co/xFgd2jg/17.png" },
    { "The Global Elite", 0, "https://i.ibb.co/WVqzsg7/18.png" }
};

const m_LastHitGroup = 75; 
const TASK_SHOWHUD = 55555;

new cvar_hs, cvar_knife, cvar_kill, cvar_hegreande;
new g_msgHud, g_iHudTeam, g_iMsgSayText, g_iMsgText;

new g_iRango[ 33 ], g_iFrags[ 33 ], g_iTeam[ 33 ], g_iHs[ 33 ], g_iDeaths[ 33 ], g_iKills[ 33 ];
new g_szPlayerName[ 33 ][ 32 ], g_iAdminPrefix[ 33 ][ 32 ], g_szAdminData[ MAXTAGADMS ][ MAX ][ 33 ];

new g_id[ 33 ];
new Handle:g_hTuple;

enum
{
    REGISTRAR_USUARIO,
    LOGUEAR_USUARIO,
    GUARDAR_DATOS,
    SQL_RANK,
    TOP15
};

enum
{
    NO_LOGUEADO = 0,
    LOGUEADO
}

new const MYSQL_HOST[] = "localhost";
new const MYSQL_USER[] = "db_detodos";
new const MYSQL_PASS[] = "tuperramadremamichan";
new const MYSQL_DATEBASE[] = "dbdb";

new const szTable[ ] = "csgo_table";

new g_iStatus[ 33 ];

public plugin_init( )
{
    register_plugin(
        .plugin_name = g_szPlugin, 
        .version = g_szVersion, 
        .author = g_szAuthor
    );

    RegisterHookChain( RG_CBasePlayer_Killed, "@Killed_OnPlayer", .post = true );
    RegisterHookChain( RG_CBasePlayer_Spawn, "@Spawn_OnPlayer", .post = true );
    RegisterHookChain( RG_CBasePlayer_SetClientUserInfoName, "@changeName_OnPlayer" );
    register_event("HLTV", "startRound_OnPlayer", "a", "1=0", "2=0");
    
    register_event( "StatusValue", "Status_team", "be", "1=1" );
    register_event( "StatusValue", "Status_team_info", "be", "1=2", "2!0" );
    register_event( "StatusValue", "OcultarInfoPlayer", "be", "1=1", "2=0" );

    bind_pcvar_num(
        create_cvar(
            .name = "csgo_kill_normal",
            .string = "2"
        ), cvar_kill
    );

    bind_pcvar_num(
        create_cvar(
            .name = "csgo_kill_knife",
            .string = "4"
        ), cvar_knife
    );

    bind_pcvar_num(
        create_cvar(
            .name = "csgo_kill_hs",
            .string = "3"
        ), cvar_hs
    );

    bind_pcvar_num(
        create_cvar(
            .name = "csgo_kill_knife_hegrenade",
            .string = "5"
        ), cvar_hegreande
    );

    register_clcmd( "say /rank", "checkRank" );
    register_clcmd( "say_team /rank", "checkRank" );
    register_clcmd( "say /top", "checkTop" );
    register_clcmd( "say_team /top", "checkTop" );
    register_clcmd( "say /top15", "checkTop" );
    register_clcmd( "say_team /top15", "checkTop" );
    register_clcmd( "say", "clcmd_say" );
    register_clcmd( "say_team", "clcmd_say" );

    g_iMsgSayText = get_user_msgid( "SayText" );
    g_iMsgText = get_user_msgid( "TextMsg" );

    g_msgHud = CreateHudSyncObj( );
    g_iHudTeam = CreateHudSyncObj( );

    MySQL_Init( );
}

public plugin_cfg( )
{
    new line[ 144 ], file, i = 0;
    file = fopen( "addons/amxmodx/configs/users.ini", "rt" );
    
    while( !feof( file ) )
    {
        fgets(file, line, charsmax( line ) );
        trim(line);
        
        if( !line[ 0 ] || line[ 0 ] == ';' || line[ 0 ] == '/' )
            continue;
        
        i++;
        parse( line, 
            g_szAdminData[ i ][ STEAM_ID ], charsmax( g_szAdminData[ ][ ] ), 
            g_szAdminData[ i ][ PASSWORD ], charsmax( g_szAdminData[ ][ ] ), 
            g_szAdminData[ i ][ ADMIN_FLAGS ], charsmax( g_szAdminData[ ][ ] ), 
            g_szAdminData[ i ][ ADMIN_TYPE ], charsmax( g_szAdminData[ ][ ] ), 
            g_szAdminData[ i ][ ADMIN_TAG ], charsmax( g_szAdminData[ ][ ] )
        );
        
        if( i >= MAXTAGADMS )
        {
            log_amx( "Usted debe aumentar el limite de tag-administradores." );
            log_amx( "El limite establecido es de %i.", MAXTAGADMS );
            break;
        }
    }
    fclose( file );
}

public client_putinserver( id )
{
    if( is_user_bot( id ) )
        return;

    new szAuthid[ 64 ];
    get_user_name( id, g_szPlayerName[ id ], charsmax( g_szPlayerName[ ] ) );

    g_iStatus[ id ] = NO_LOGUEADO;
    g_iAdminPrefix[ id ][ 0 ] = EOS;

    if( is_user_steam( id ) )
        get_user_authid( id, szAuthid, charsmax( szAuthid ) );
    else
        copy( szAuthid, charsmax( szAuthid ), g_szPlayerName[ id ] );

    new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];

    iData[ 0 ] = id;
    iData[ 1 ] = LOGUEAR_USUARIO;

    formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE steam_id= ^"%s^"", szTable, szAuthid );
    
    SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );

    if( is_user_admin( id ) )
    {
        for(new i = 0; i < MAXTAGADMS; i++)
        {
            if( equali( szAuthid, g_szAdminData[i][STEAM_ID] ) )
            {
                formatex( g_iAdminPrefix[ id ], charsmax( g_iAdminPrefix[ ] ), g_szAdminData[ i ][ ADMIN_TAG ] );
                break;
            }
        }
    }
}

public client_disconnected( id )
{
    if( g_iStatus[ id ] == LOGUEADO ) 
    {
        guardar_datos( id );

        g_iStatus[ id ] = NO_LOGUEADO;
    }   
    g_iAdminPrefix[ id ][ 0 ] = EOS;
}

public Status_team( id ) 
    g_iTeam[ id ] = read_data( 2 );

public OcultarInfoPlayer( id )
    ClearSyncHud( id, g_iHudTeam );

public Status_team_info( id ) 
{ 
    if( is_valid_player_alive( id ) ) 
    { 
        new target = read_data( 2 );
        if ( g_iTeam[ id ] == 1 ) 
        { 
            if( get_member( target, m_iTeam ) == TEAM_TERRORIST ) set_hudmessage( 255, 0, 10, -1.0, 0.55, 0, 6.0, 12.0 );
            else set_hudmessage(0, 255, 255, -1.0, 0.55, 0, 6.0, 12.0);
            ShowSyncHudMsg(id, g_iHudTeam, "[%s]^n%s", g_aRangos[ g_iRango[ target ] ][ rango_name ], g_szPlayerName[ target ] );
        }
        else 
        { 
            if ( get_member( target, m_iTeam ) == TEAM_TERRORIST ) set_hudmessage(255, 0, 10, -1.0, 0.55, 0, 6.0, 12.0);
            else set_hudmessage(0, 255, 225, -1.0, 0.55, 0, 6.0, 12.0);
            ShowSyncHudMsg(id, g_iHudTeam, "[%s]^n%s", g_aRangos[ g_iRango[ target ] ][ rango_name ], g_szPlayerName[ target ]);
        }
    }
}

public startRound_OnPlayer( )
{
    for( new i = 1; i <= MAX_PLAYERS; ++i )
    {
        if( g_iStatus[ i ] != LOGUEADO )
            continue;

        guardar_datos( i );
    }
    client_print_color( 0 , print_team_blue, "^x01Sistema de rangos by ^x04%s", g_szAuthor );
}
@Spawn_OnPlayer( id )
{
    if( g_iStatus[ id ] == LOGUEADO ) 
        guardar_datos( id );
}
@Killed_OnPlayer( victim, attacker, shouldgib )
{
    if( !is_valid_player_alive( attacker ) || victim == attacker || get_member( attacker, m_iTeam ) == get_member( victim, m_iTeam ) )
        return;

    if( get_member( attacker, m_LastHitGroup ) == HITGROUP_HEAD ) 
    {
        setLevel( attacker, cvar_hs );
        //setLevel( victim, -1 * cvar_hs );

        ++g_iHs[ attacker ];
    }
    else
    {
        if( GetCurrentWeapon( attacker ) == WEAPON_HEGRENADE )
        {
            setLevel( attacker, cvar_hegreande );
            //setLevel( victim, -1 * cvar_hegreande );
        }
        else if( GetCurrentWeapon( attacker ) == WEAPON_KNIFE )
        {
            setLevel( attacker, cvar_knife );
            //setLevel( victim, -1 * cvar_knife );
        }
        else
        {
            setLevel( attacker, cvar_kill );
            //setLevel( victim, -1 * cvar_kill );
        }
    }
    ++g_iKills[ attacker ];
    ++g_iDeaths[ victim ];
}

public setLevel( id, value )
{
    if( g_iRango[ id ] >= charsmax( g_aRangos ) || g_iRango[ id ] < 0 )
        return;
    
    new iLevel = g_iRango[ id ];

    g_iFrags[ id ] += value;

    while( g_iFrags[ id ] >= g_aRangos[ g_iRango[ id ] >= 19 ? 19 : g_iRango[ id ] ][ level_req ] && g_iRango[ id ] < 19 )
        ++g_iRango[ id ];
    
    if( iLevel < g_iRango[ id ] )
        client_print_color( id, print_team_blue, "^x01Subiste al rango ^x04%s", g_aRangos[ g_iRango[ id ] ][ rango_name ] );

    while( g_iFrags[ id ] < g_aRangos[ g_iRango[ id ]-1 <= 0 ? 0 : g_iRango[ id ]  ][ level_req ] && g_iRango[ id ] > 0 )
        --g_iRango[ id ];

    iLevel = g_iRango[ id ];

    if( iLevel > g_iRango[ id ] )
        client_print_color( id, print_team_blue, "^x01Bajaste al rango ^x04%s", g_aRangos[ g_iRango[ id ] ][ rango_name ] );
    
    if( g_iFrags[ id ] <= 0)
        g_iFrags[ id ] = 0;

}

@changeName_OnPlayer(id, infobuffer[], szNewName[]) 
{
    if (!is_user_connected(id) )
        return HC_SUPERCEDE;
    
    new szOldName[32];
    get_entvar(id, var_netname, szOldName, charsmax(szOldName));
 
    SetHookChainArg(3, ATYPE_STRING, szOldName);
    set_msg_block( get_entvar(id, var_deadflag) != DEAD_NO ? g_iMsgText : g_iMsgSayText, BLOCK_ONCE );
    return HC_SUPERCEDE;
} 

public checkRank( id )
{
    if(  g_iStatus[ id ] != LOGUEADO )
        return;

    new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
    
    iData[ 0 ] = id;
    iData[ 1 ] = SQL_RANK;

    formatex( szQuery, charsmax( szQuery ), "SELECT (COUNT(*) + 1) FROM `%s` WHERE `rango` > '%d' OR (`rango` = '%d' AND `frags` > '%d')", szTable, g_iRango[ id ], g_iRango[ id ], g_iFrags[ id ] );
    SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 ); 
}

public checkTop( id )
{
    new szTabla[ 200 ], iData[ 2 ];
    
    iData[ 0 ] = id;
    iData[ 1 ] = TOP15;
    formatex( szTabla, charsmax( szTabla ), "SELECT Pj, rango, frags FROM %s ORDER BY rango DESC, frags DESC LIMIT 8", szTable );
    
    SQL_ThreadQuery(g_hTuple, "DataHandler", szTabla, iData, 2 );
    
}

public guardar_datos( id ) 
{
    if( g_iStatus[ id ] != LOGUEADO )
        return;

    new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ], szIP[34];

    iData[ 0 ] = id;
    iData[ 1 ] = GUARDAR_DATOS;

    get_user_ip( id, szIP, charsmax( szIP ), true );
    
    formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET rango='%d', frags='%d', Pj=^"%s^", hs='%d', kills='%d', deaths='%d', ip=^"%s^" WHERE id='%d'", 
        szTable, g_iRango[ id ], g_iFrags[ id ], g_szPlayerName[ id ], g_iHs[ id ], g_iKills[ id ], g_iDeaths[ id ], szIP, g_id[ id ] );
    SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
}

public DataHandler( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:flTime ) 
{
    switch( failstate ) 
    {
        case TQUERY_CONNECT_FAILED: 
        {
            log_to_file( "SQL_LOG_TQ.txt", "Error en la conexion al MySQL [%i]: %s", error2, error );
            return;
        }
        case TQUERY_QUERY_FAILED:
        log_to_file( "SQL_LOG_TQ.txt", "Error en la consulta al MySQL [%i]: %s", error2, error );
    }
    
    new id = data[ 0 ];
    
    if( !is_user_connected( id ) )
        return;
    
    switch( data[ 1 ] ) 
    {
        case LOGUEAR_USUARIO: 
        {
            if( SQL_NumResults( Query ) )
            {
                g_id[ id ] = SQL_ReadResult( Query, 0 );
                g_iRango[ id ] = SQL_ReadResult( Query, 2 );
                g_iFrags[ id ] = SQL_ReadResult( Query, 3 );
                g_iHs[ id ] = SQL_ReadResult( Query, 5 );
                g_iKills[ id ] = SQL_ReadResult( Query, 6 );
                g_iDeaths[ id ] = SQL_ReadResult( Query, 7 );
                
                set_task( 1.0, "ShowHUD", id+TASK_SHOWHUD, _, _, "b" );

                g_iStatus[ id ] = LOGUEADO;

                client_print_color( id, print_team_blue, "^x01TU ID DE CUENTA ES ^x04%d.", g_id[ id ]);
                client_print_color( id, print_team_blue, "^x01Bienvenido ^x03%s ^x01tu rango es ^x04%s", g_szPlayerName[ id ], g_aRangos[ g_iRango[ id ] ][ rango_name ] );
            }
            else
            {
                g_iRango[ id ] = 0; 
                g_iFrags[ id ] = 0;
                g_iHs[ id ] = 0;
                g_iKills[ id ] = 0;
                g_iDeaths[ id ] = 0;

                new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ], szAuthid[ 64 ], szIP[34];

                if( is_user_steam( id ) )
                    get_user_authid( id, szAuthid, charsmax( szAuthid ) );
                else
                    copy( szAuthid, charsmax( szAuthid ), g_szPlayerName[ id ] );
                    
                get_user_ip( id, szIP, charsmax( szIP ), true );
                
                iData[ 0 ] = id;
                iData[ 1 ] = REGISTRAR_USUARIO;
                
                formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (steam_id, rango, frags, hs, kills, deaths, Pj, ip) VALUES (^"%s^", %d, %d, %d, %d, %d, ^"%s^", ^"%s^")", 
                    szTable, szAuthid, g_iRango[ id ], g_iFrags[ id ], g_iHs[ id ], g_iKills[ id ], g_iDeaths[ id ], g_szPlayerName[ id ], szIP );
                console_print(0, "%s", szQuery);
                SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
            }
        }
        case REGISTRAR_USUARIO: 
        {
            if( failstate < TQUERY_SUCCESS ) 
            {
                console_print( id, "Error al crear un usuario: %s.", error );
            }
            else
            {
                new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ], szAuthid[ 64 ];

                if( is_user_steam( id ) )
                    get_user_authid( id, szAuthid, charsmax( szAuthid ) );
                else
                    copy( szAuthid, charsmax( szAuthid ), g_szPlayerName[ id ] );

                iData[ 0 ] = id;
                iData[ 1 ] = LOGUEAR_USUARIO;

                formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE steam_id= ^"%s^"", szTable, szAuthid );
                console_print(0, "%s", szQuery);
                SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
            }
        }
        case GUARDAR_DATOS:
        {
            if( failstate < TQUERY_SUCCESS )
            {
                console_print( id, "Error en el guardado de datos." );
            }
            else
            {
                client_print_color( id, print_team_blue, "^x04 Datos guardados en %.0f segundos.", flTime );
            }
        }
        case SQL_RANK:
        {
            if( SQL_NumResults( Query ) )
            {
                static szBuffer[ MAX_MOTD_LENGTH-1 ];
                formatex(szBuffer, charsmax(szBuffer), "http://divstarproject.com/zombie_escape/rank_csgo.php?nick=%s&id=%d&rango=%s&kills=%d&deaths=%d", 
                    g_szPlayerName[ id ], SQL_ReadResult( Query, 0 ), g_aRangos[ g_iRango[ id ] ][ rango_name ], g_iKills[ id ], g_iDeaths[ id ] );
                
                show_motd( id, szBuffer, "RankStats" );
            }
        }
        case TOP15:
        {
            if( SQL_NumResults( Query ) )
            {
                static len, szBuffer[ MAX_MOTD_LENGTH-1 ], i, szName[ 32 ];
                len = 0, i = 0;

                len = format(szBuffer[len], charsmax(szBuffer) - len, "<meta charset=UTF-8>\
            <style>*{margin:0px;}body{color:#fff;background: rgba(2, 0, 0, 0.2) url(https://images7.alphacoders.com/570/570405.png); background-repeat: no-repeat; background-size: cover; background-attachment: fixed;}table{border-collapse:collapse;border: 1px solid #ffff;text-align:center;}</style>\
            <body><table width=100%% border=1><tr bgcolor=#4c4c4c style=^"color:#fff;^"><th width=5%%>#<th width=50%%>Usuario<th width=15%%>Rango\
            <th width=15%%>EXP<th width=15%%>Insignea");
                while( SQL_MoreResults( Query ) )
                {
                    SQL_ReadResult( Query, 0, szName, charsmax( szName ) );
                    len += format( szBuffer[len], charsmax(szBuffer) - len, "<tr><td>%i<td>%s<td>%s<td>%d<td><img src=^"%s^" width=80 hight=30/>",
                        i+1, szName, g_aRangos[ SQL_ReadResult( Query, 1 ) ][ rango_name ], SQL_ReadResult( Query, 2 ), g_aRangos[ SQL_ReadResult( Query, 1 ) ][ url_rango ] );
                    ++i;
                    SQL_NextRow( Query );
                }
                show_motd( id, szBuffer, "Top 8 Rangos" );
            }
        }
        
    }
}

public clcmd_say( id )
{
    static said[ 191 ];
    read_args( said, charsmax( said ) );
    remove_quotes( said );
    replace_all( said, charsmax( said ), "%", " " );
    replace_all( said, charsmax( said ), "#", " " );

    if ( !ValidMessage( said, 1 ) ) 
        return PLUGIN_CONTINUE;

    static color[ 11 ], prefix[ 91 ];
    get_user_team( id, color, charsmax( color ) );
    
    formatex( prefix, charsmax(prefix), "%s ^x04%s^x01[ ^x04%s^x01 ]^x03 %s", is_valid_player_alive( id ) ? "^x01" : "^x01*MUERTO* ", is_user_admin( id ) ? g_iAdminPrefix[ id ] : "", g_aRangos[ g_iRango[ id ] ][ rango_name ], g_szPlayerName[ id ] );
    
    if( is_user_admin( id ) ) format( said, charsmax( said ), "^x04%s", said );
    format( said, charsmax( said ), "%s^x01 :  %s", prefix, said );
    
    static i, team[11];
    for ( i = 1; i <= MAX_PLAYERS; i++ ) 
    {
        if ( !is_user_connected( i ) ) 
            continue;
            
        get_user_team( i, team, charsmax( team ) );
        changeTeamInfo( i, color );
        writeMessage( i, said );
        changeTeamInfo( i, team );
        
    }
    return PLUGIN_HANDLED_MAIN;
}
public changeTeamInfo( player, team[ ] )
{
    message_begin( MSG_ONE, get_user_msgid("TeamInfo"), _, player );
    write_byte( player );
    write_string( team );
    message_end( );
}

public writeMessage( player, message[ ] )
{
    message_begin( MSG_ONE, g_iMsgSayText, {0, 0, 0}, player );
    write_byte( player );
    write_string( message );
    message_end( );
}

public ShowHUD( taskid )
{
    static id;
    id = ID_SHOWHUD;
    
    if ( !is_valid_player_alive( id ) )
    {
        id = get_entvar( id, var_iuser2 );
        if ( !is_valid_player_alive( id ) ) return;
    }

    set_hudmessage( 255, 0, 0, -1.0, 0.87, 1, 0.0, 2.0 );

    if ( id != ID_SHOWHUD )
        ShowSyncHudMsg(ID_SHOWHUD, g_msgHud, "Observando al jugador: ^n%s^n^nRango: %s^nNivel: %d | Exp: %s", g_szPlayerName[ id ], g_aRangos[ g_iRango[ id ] ][ rango_name ], g_iRango[ id ], xAddPoint( g_iFrags[ id ] ) );
    else
        ShowSyncHudMsg(ID_SHOWHUD, g_msgHud, "Rango: %s^nNivel: %d - Exp: %s", g_aRangos[ g_iRango[ id ] ][ rango_name ], g_iRango[ id ], xAddPoint( g_iFrags[ id ] ) );
    
}

public MySQL_Init( )
{
    g_hTuple = SQL_MakeDbTuple( MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DATEBASE );
    
    if( !g_hTuple ) 
    {
        log_to_file( "SQL_ERROR.txt", "No se pudo conectar con la base de datos." );
        return pause( "a" );
    }

    return PLUGIN_CONTINUE;
}
public plugin_end( )
    SQL_FreeHandle( g_hTuple ); 

stock is_user_admin( id )
{
    new __flags= get_user_flags( id );
    return ( __flags>0 && !( __flags&ADMIN_USER ) );
}

stock ValidMessage(text[], maxcount) 
{
    static len, i, count;
    len = strlen(text);
    count = 0;
    
    if (!len)
        return false;
    
    for (i = 0; i < len; i++) 
    {
        if (text[i] != ' ') 
        {
            count++;
            if (count >= maxcount)
                return true;
        }
    }
    return false;
} 
stock xAddPoint(number)
{
    new count, i, str[29], str2[35], len;
    num_to_str(number, str, charsmax(str));
    len = strlen(str);

    for (i = 0; i < len; i++)
    {
        if(i != 0 && ((len - i) %3 == 0))
        {
            add(str2, charsmax(str2), ".", 1);
            count++;
            add(str2[i+count], 1, str[i], 1);
        }
        else add(str2[i+count], 1, str[i], 1);
    }
    
    return str2;
}
WeaponIdType:GetCurrentWeapon( const iId )
{
    new iItem = get_member( iId, m_pActiveItem );
        
    if ( !is_entity( iItem ) )
    {
        return WEAPON_NONE;
    }
    
    new WeaponIdType:iWeapon = get_member( iItem, m_iId );
    
    if ( !( WEAPON_P228 <= iWeapon <= WEAPON_P90 ) )
    {
        return WEAPON_NONE;
    }
    
    return iWeapon;
}