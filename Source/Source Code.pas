{  Ver 1.0c
   Copyright 2014 Sai Ram Ramisetty
   
   This program (Epic Adventure) is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02110-1301, USA.                                                                                               }

PROGRAM EPIC_ADVENTURE;
USES wincrt, winprocs, strings;

CONST
     Sprites_Number = 7; {Number of Animations used in combat}
     Maps_Number = 4; {Number of Maps in the overworld}

     HPC = 30; {These 'C' constants are used to balance game difficulty}
     MPC = 60; {Each time a player levels up, they can increase a stat by} 
     ATKC = 6; {their respective 'C' value.}

     Base_HP = 100; {The 'base' HP, MP, and ATK values a hypothetical "level 0" character would have}
     Base_MP = 60;
     Base_Atk = 20;

     FB_COST = 60; {THE MP Cost of a fireball attack}

     FB_Factor = 1; {The amount of extra damage a fireball does is ATK div FB_Factor}
     Max_Factor = 4; {The amount of extra damage done when the player reaces a 100% attack power}
     Crit_Factor = 5; {A small chance of a critical hit, causing extra damage}  

     Map_Specials: set of Char = ['N','P'];
     {The lower these factors, the more extra damage they cause}

TYPE
    Sprite_Array = Array[1..Sprites_Number,1..6,1..7] of string[17]; {A 4D Array of ascii animations}
                                                  {The 1st dimension stores which animation is being loaded.
                                                  Each number corresponds to a different animation.
                                                  The 2nd layer stores each frame of the animation (MAX 6 frames).
                                                  The 3rd layer stores each 'line'/row of each frame as a 17 char
                                                  long string.}

    MAP_Array = Array[1..Maps_Number,1..23] OF STRING[19];   {Array of each MAP. Maps are 19x23 in size}

    Character_Record = record {Personal Character Values unique to each player}
            Name: String[9]; {The player's name}
            Look: Char; {The player can select how they want to appear in game} 
            Combats_won, Combats_lost: Integer; {The number of Combats the player has won/lost}

    {Player in Combat Stats; these change during Combat}
            HP: Integer; {The player's current HP (Hitpoints), or Health}
            MP: Integer; {The player's current MP (Magic Points)}

    {Player Stats; these can be incremented}
            MAX_HP,MAX_MP: Integer; {The player's max HP and MP}
            ATK: Integer; {The amount of damage a player can do in Combat}
            XP: Integer; {The player needs to meet the XP requirement to level up, and increase HP, MP or ATK}
            Level: integer; {The player's level}

    {Player Overworld variables: these are used in the overworld}
            X, Y : byte; {the player's co-ordinates}
            Area : byte; {The area code for the player's current area}

            Game_Progress : byte; {How far into the Game the player has progressed}
            Game_Time: byte; {Time of 24-hour Day, ranging from 0 to 2; each an 8 hour block}

            Password : string[4]; {A 4 digit password used by the player to delete their record file}

    END;

    Enemy_Record = record  {Settings for the enemy}
            Name: String[9];
            LEVEL, HP, MP, MAX_HP, MAX_MP, ATK: Integer;
            XP_Factor: integer; {The XP that the enemy gives you is XPFactor * their level}
            Retreat_possible : boolean; {Whether the player can retreat from combat with the enemy or not}
    END;

    NPC_Record = record {Overworld NPCs}
       X,Y : byte; {Overworld position on the map}
    END;

    Save_File = file of Character_Record; {The save file containing players' data}

    Pattern = string[3]; {Patterns}

VAR   
  Combat_Sprites : Sprite_Array; {All the animations used during Combat.}
  MAP : Map_Array;

  {Unique PLAYER variables}

  Player : Character_Record; {This record contains the player's unique Character info}
  DAD : NPC_Record; {The NPC in the first room of the game.}
  Current_Player_Pos : byte; {The position of the current player's record in the record file.}
  SAVE : Save_File;

  Enemy : Enemy_Record; {The player engages in combat with one enemy at a time, whose stats are stored in this record}
  QUIT_GAME, QUIT_MID_COMBAT : boolean; {Whether the user wants to quit the game, and if they quit mid combat}

{*****************}
{MISC. SUBPROGRAMS}
{*****************}

PROCEDURE Key_Buffer_Clear;
BEGIN
     IF KeyPressed = True THEN {Clear the keyboard buffer, preventing the user's key presses being read by the program }
        Readkey;               {Useful when animations are being played}
     {ENDIF}
END {Key_Buffer_Clear};

PROCEDURE Delay(Delay_Amount: integer; Delay_Skippable : boolean);
                {Calling a delay like this is much slower than having it in the subprogram itself}
VAR             {Therefore, this delay procedure is unsuitable for battle and quick animations, i.e. low values of delay}
   Timer1,Timer2:longint;    {If Delay_Skippable is true, then the player can skip the delay by pressing a key}
BEGIN
     Timer1:=GetTickCount;
     REPEAT    
         Timer2 := GetTickCount - Timer1;
         IF Delay_Skippable = FALSE THEN
            Key_Buffer_Clear;
         {ENDIF}
     UNTIL (Timer2 >= Delay_Amount) OR ( (KeyPressed) AND (Delay_Skippable = TRUE) );
END;

PROCEDURE LOAD_Maps; {Load the maps into the array from the file at the start of the game}
VAR
   Map_INDEX,Map_Line_Index: byte;
   Map_File : text;
BEGIN
     Map_Index:= 1;
     Assign(Map_File,'MAP.txt'); {Assigns the MAP File}
     Reset(Map_File);
     REPEAT
           Map_Line_Index:= 1;
           REPEAT
                 Readln(Map_File,Map[Map_Index,Map_Line_Index]);
                 Inc(Map_Line_Index);
           UNTIL Map_Line_Index > 23; {Loaded one map}
           Inc(Map_Index);
     UNTIL Map_Index > 4; {Loaded all maps}
     Close(Map_File); 
END {LOAD_Maps};

PROCEDURE LOAD_Sprites; {Load the sprites into the array at the start of the game}
VAR
   INDEX_Frame,INDEX_SpriteLines,INDEX_SPRITE: Byte;
   Sprites_File : TEXT;
BEGIN
     INDEX_SPRITE:= 0;
     Assign(Sprites_File,'Sprites.txt'); {Assigns the Sprite File}
     Reset(Sprites_File);
     REPEAT
         Inc(INDEX_SPRITE);
         INDEX_Frame:= 1;
         INDEX_SpriteLines:= 1;
         REPEAT
               REPEAT
                     Readln(Sprites_File,Combat_Sprites[INDEX_SPRITE,INDEX_FRAME,INDEX_SpriteLines]);
                     {Reads into array one line at a time}
                     Inc(INDEX_SpriteLines); {Each new line is the next row of the sprite}
               UNTIL INDEX_SpriteLines > 7; {Until the final row in the sprite is reached}
               INC(INDEX_FRAME); {At which point, the process restarts on the next Frame of the sprite, at row 1}
               INDEX_SpriteLines := 1;
         UNTIL INDEX_Frame > 6; {Until all the rows are filled}
     UNTIL INDEX_SPRITE = Sprites_Number; {Until all animations are made}
     Close(SPRITES_File); {The text file can be closed as ALL SPRITES are loaded}
END {LOAD_Sprites};

PROCEDURE INITIALIZE; {Initialises variables for the game, loads files etc.}
VAR
   Save_file_Exist : byte;
BEGIN
     RANDOMIZE;
     StrCopy(WindowTitle,'EPIC ADVENTURE');
     Assign(SAVE, 'SAVE.DAT'); {Associate SAVE file}

     {$I-}
     Reset(SAVE);
     {$I+}

     Save_File_Exist := IOResult; {Checks if SAVE file exists}

     IF Save_file_Exist <>  0 THEN {The SAVE file does not exist, so create it}
        Rewrite(SAVE);
     {ENDIF}

     LOAD_Sprites;
     LOAD_Maps;
END {INITIALIZE};

PROCEDURE Delete_Save(Pos_Index :byte); {The position of the save file to be deleted}
BEGIN
    WHILE Pos_Index < (filesize(SAVE) -1) DO
    {Filesize -1 is the position of the last record}
    BEGIN
        Inc(Pos_Index);
        Seek(SAVE,Pos_Index);
        Read(SAVE,Player);
        Seek(SAVE,Pos_Index-1);
        Write(SAVE,Player);
    END;
    {Truncate the file, removing the duplicate made by moving every record back}
    Seek(SAVE,Filesize(SAVE)-1);
    Truncate(SAVE);
END {Delete_Save};

PROCEDURE Save_Game; {Save the player's progress}
VAR
   Pos_Index : byte; {Used for sorting the record file}
BEGIN
     IF Current_Player_Pos > 0 THEN {move the save file to the front, as it was the most recently accessed}
     BEGIN
          Seek(SAVE,Filesize(SAVE)); {Temporarily save the current file at the end of the file}
          Write(SAVE,Player);
         
          Pos_Index:= Filesize(SAVE);
          WHILE Pos_Index > 0 DO {Move each record back one position, creating a duplicate at the front which can}
          BEGIN                  {Be overwritten by the temporarily saved file}
              Dec(Pos_Index);
              Seek(SAVE,Pos_Index);
              Read(SAVE,Player);
              Seek(SAVE,Pos_Index+1);
              Write(SAVE,Player);     
          END{WHILE};


          Seek(SAVE,Filesize(SAVE)-1); {Load the temporary saved file}
          Read(SAVE,Player);
          Seek(SAVE,0);
          Write(SAVE,Player); {Save it in the first slot}

          Delete_Save(Current_Player_Pos+1);
  {Current_Player_Pos + 1 is the position of the player file before they were moved to the front, which is to be deleted}

          Seek(SAVE,Filesize(SAVE)-1); {Delete the temporary save}
          Truncate(SAVE);

          Current_Player_Pos:= 0; {The current save file is now at the start of the SAVE file}
     END
     ELSE
     BEGIN
          Seek(SAVE,Current_Player_Pos);
          Write(SAVE,Player);
     END{IF};
END {Save_Game};

PROCEDURE Clr(Y,Lines_To_Clear : byte); {Starts from (0,Y) an/d clears 'Lines_To_Clear' # of lines following it.}
VAR
   Counter : Byte;
BEGIN
     Counter := 0;
     WHILE Counter <= Lines_To_Clear DO
     BEGIN
        GOTOXY(0,Y+Counter);
        ClrEOL;
        Inc(Counter);
     END;{WHILE}
END {CLR};

PROCEDURE TRANSITION(Print : Pattern); {A transition animation that fills the whole screen}
VAR
   Timer1, Timer2 : Longint;
   Counter : integer;
BEGIN
    Counter:= 0;
    GotoXY(1,1);    
    Timer1:= gettickcount;
    REPEAT    
         Timer2 :=  gettickcount - Timer1;
         IF Timer2 > 2 THEN
         BEGIN
              Write(PRINT,' ');
              Inc(Timer1,2);
              Inc(Counter);
              Key_Buffer_Clear;
         END{IF};
    UNTIL (Counter > 498);
    Write(PRINT);
    counter:= 0;
    Timer1:= gettickcount;
    GotoXY(1,1);
    REPEAT    
         Timer2 :=  gettickcount - Timer1;
         IF Timer2 > 2 THEN
         BEGIN
              Write('    ');
              Inc(Timer1,2);
              Inc(Counter);
              Key_Buffer_Clear;
         END{IF};
    UNTIL (Counter > 498);
    clrscr;
END {TRANSITION};

{******************}
{COMBAT SUBPROGRAMS}
{******************}

PROCEDURE COMBAT_Set_Enemy_Stats; {Initialises the enemy's stats}
VAR
   Stat_Boost,HP_Boost,Atk_Boost,MP_Boost : Byte;
BEGIN
     Stat_boost:= Enemy.Level; {These points are to be distributed randomly}
     {They distribute like the player's stat points at the start of the game}       

     HP_Boost:= Random(Stat_boost+1);
     MP_Boost:= Random(Stat_boost - HP_Boost + 1);
     Atk_Boost:=Stat_boost - HP_Boost - MP_Boost;

     Enemy.Max_HP := Base_HP + (HP_Boost * HPC);
     Enemy.Max_MP := Base_MP + (MP_Boost * MPC);
     Enemy.ATK := Base_Atk + Atk_Boost * ATKC;
     Enemy.XP_Factor := 1;
     Enemy.Retreat_possible := TRUE;
END {COMBAT_Set_Enemy_Stats};

PROCEDURE COMBAT_RESULTS(Result : char);
BEGIN
     ClrScr;
     GotoXY(1,4);
     CASE Result OF
          'W' : BEGIN
                     Inc(Player.Combats_Won);
                     WRITELN('You have won!');
                     Writeln('XP Gained: ',Enemy.Level);
                END;
          'L' : BEGIN
                     Inc(Player.Combats_Lost);
                     Writeln('You lost...');
                END;
          'R' : BEGIN
                     Inc(Player.Combats_Lost);
                     Writeln('You retreated');
                END;
     END{CASE};
     GotoXY(1,1);
     Writeln('°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°');
     Writeln('END OF MATCH # ',Player.Combats_Won+Player.Combats_Lost);
     Writeln('°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°');
     GOTOXY(1,5);
     Write('XP until next level: ',(Player.Level)*(Player.Level) - Player.XP);

     Readkey;
     ClrScr;
END {COMBAT_RESULTS};


PROCEDURE Level_Up; {Appears after combat, if the player has met the requirements to level up}
VAR
   Upgrade_Selection : byte; {Position of cursor}
   User_Input : char;
BEGIN
     Upgrade_Selection:= 1;
     ClrScr;
     Writeln('°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°');
     Writeln('LEVEL UP!');
     Writeln('°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°');
     Writeln;
     Writeln('You are now level ',Player.Level + 1,'!');
     Writeln('Please select which skill you would like to level up:');
     Writeln;
     Writeln(' ':11,') HP : ',Player.Max_HP,' >> ',Player.Max_HP+HPC);
     Writeln(' ':11,') MP : ',Player.Max_MP,' >> ',Player.Max_MP+MPC);
     Writeln(' ':11,') ATK: ',Player.Atk,'  >> ',Player.Atk+ATKC);

     REPEAT
           REPEAT
                 Clr(12,2); {Clears the 'Are you sure' Message if the loop is repeating}
                 GotoXY(10, Upgrade_Selection + 7);
                 Write('Þ ');
                 GotoXY(10, Upgrade_Selection + 7); {Move the blinker back to the cursor, increasing visibility}
                 User_Input:= Readkey;
                 Write('  ');

                 CASE Upcase(User_Input) OF
                      'W' : IF (Upgrade_Selection > 1) THEN {CURSOR MOVEMENT}
                               Dec(Upgrade_Selection)
                            ELSE
                               Upgrade_Selection:= 3;
                            {ENDIF}
                      'S' : IF (Upgrade_Selection < 3) THEN
                               Inc(Upgrade_Selection)
                            ELSE
                               Upgrade_Selection:= 1;
                            {ENDIF}
                 END{CASE};      
           UNTIL User_Input IN [#32,#13];

           GotoXY(1,12);
           Write('Are you sure you want to upgrade ');
           CASE Upgrade_Selection OF
               1: Write('HP to ',Player.Max_HP+HPC);
               2: Write('MP to ',Player.Max_MP+MPC);
               3: Write('ATK to ',Player.ATK+ATKC);
           END{CASE};
           Writeln('?');
           Write('Press ''Y'' to confirm, or or any other key to return.');
           User_Input:= Readkey;
     UNTIL UpCase(User_Input) = 'Y';

     Writeln;
     Writeln;
     Dec(Player.XP,(Player.Level*Player.Level)); {Resets the XP spent on levelling up}
     Inc(Player.Level);

     CASE Upgrade_Selection OF
          1: BEGIN
                  Inc(Player.Max_HP,HPC);
                  Write('HP UPGRADED!');
             END;
          2: BEGIN
                  Inc(Player.Max_MP,MPC);
                  Write('MP UPGRADED!');
             END;

          3: BEGIN
                  Inc(Player.Atk,ATKC);
                  Write('ATK UPGRADED!');
             END;
     END{CASE};

     Player.HP := Player.Max_HP; {Players HP and MP are restored after levelling up}
     Player.MP := Player.Max_MP;
     Save_Game; {Writes the player's info back to file}
     Readkey;
     ClrScr;
END {Level_Up};

PROCEDURE COMBAT_ANIMATE(Sprite,Start_frame,End_frame : integer);{Sprite decides which animation is being played}
VAR                                          {Start_Frame and end_frame decide where to start and stop the animation}
    Animation_Frame, Index_Spritelines: Byte;
BEGIN
     Animation_FRAME := Start_Frame-1;
     REPEAT
           BEGIN
                Inc(Animation_Frame);
                Index_Spritelines:= 1;
                REPEAT
                      GotoXY(30,6+Index_Spritelines);
                      Writeln(Combat_Sprites[Sprite,Animation_FRAME,INDEX_SpriteLines]);
                      Inc(INDEX_SpriteLines); {Each new line is the next row of the sprite}
                UNTIL INDEX_SpriteLines > 7; {Until the final row in the sprite is reached}
           END{IF};
           Delay(130,FALSE);
     UNTIL (Animation_FRAME >= end_frame);
     GOTOXY(80,25);
END {COMBAT_ANIMATE};

PROCEDURE COMBAT_UPDATE_STATS; {Prints updated stats to the screen}
BEGIN
     GOTOXY(6,3);
     Write('HP: ',Player.HP:4,'/',Player.MAX_HP);
     GOTOXY(60,3);
     Write('HP: ',Enemy.hp:4,'/',Enemy.max_HP);
     GOTOXY(6,4);
     Write('MP: ',Player.MP:4,'/',Player.MAX_MP);
     GOTOXY(60,4);
     Write('MP: ',Enemy.Mp:4,'/',Enemy.max_MP);
END {COMBAT_UPDATE_STATS};

PROCEDURE COMBAT_PLAYER_ATTACK(VAR Return : boolean); {The user attacks}
VAR
   Attack_Power,Attack_type,Crit_chance: shortint;
   Timer1,Timer2: longint;
   Player_Dmg:integer;
   User_Attack: Char;
   Bar_Direction_Right : boolean;
BEGIN
        Timer1:= gettickcount;
        Return := False; {The user does not want to return to the previous menu}
        Attack_Power:= 1;
        Clr(17,7); {Clears the menu bar and options}
        GOTOXY(1,17);
        Writeln('=                   !'); ; {Draws the attack bar}
        Writeln;
        Writeln('    A) Melee');
        IF Player.MP >= FB_COST THEN
           Writeln('    F) Fireball (',FB_COST,'MP)');
        {ENDIF}
        Write('  Esc) Return ');
        REPEAT
              REPEAT
                    Timer2 :=  gettickcount - Timer1;
                    IF Timer2 > 15 THEN
                    BEGIN
                         IF (Attack_Power = 20) THEN {If the bar has reached the max value, change direction}
                            Bar_Direction_Right := False; {Left}
                         {ENDIF}

                         IF (Attack_Power = 1) THEN
                            Bar_Direction_Right := True; {Right}
                         {ENDIF}

                         CASE Bar_Direction_Right OF
                              True : Inc(Attack_Power);
                              False : Dec(Attack_Power);
                         END{CASE};

                         GotoXY(Attack_Power,17);
                         Write('=');
                         Inc(Timer1,15);

                         IF Attack_Power <= 19 THEN
                            Write(' '); {Delete the markers on the way back left}
                         {ENDIF}
                    END{IF};
              UNTIL Keypressed;
              User_Attack:= READKEY;

              IF (Upcase(User_Attack) = 'F') AND (Player.MP < FB_Cost) THEN
              BEGIN
                 GOTOXY(11,24);
                 Write('Insufficient MP! You need at least ', FB_Cost, 'MP to cast Fireball.');
              END{IF};
        UNTIL (Upcase(User_Attack) in ['A',#27]) OR ( (Upcase(User_Attack) = 'F') AND (Player.MP >= FB_Cost) );

        IF Attack_Power = 20 THEN {A bonus for getting the highest attack possible}
        BEGIN
              inc(Attack_Power,Attack_Power div Max_Factor);
              GOTOXY(24,17);
              writeln('Max Power!');
        END{if};

        Crit_chance:= Random(6); {A random chance for the player's attack to cause extra damage}
        IF Crit_chance = 0 THEN
        BEGIN
              inc(Attack_Power,Attack_Power div Crit_Factor);
              GOTOXY(24,18);
              writeln('Critical Hit!');
        END{if};

        CASE UpCase(User_Attack) OF
             'A' : Attack_Type:= 1;
             'F' : BEGIN
                        Attack_Type:= 2;
                        Dec(Player.MP,FB_COST);
                        inc(Attack_Power,Attack_Power div FB_FACTOR);
                   END;
             #27 : Return := True;
        END{CASE};

        IF Return = False THEN {IF the player does not want to return to the combat submenu, proceed with attack}
        BEGIN
             Player_Dmg:=(Attack_Power*Player.ATK) div 20;
             {If the player hit the bar when it was full (20), it will do maximum damage}

             Dec(Enemy.hp,Player_Dmg);
             IF Enemy.HP < 0 THEN
                Enemy.HP := 0; {Negative health is aesthetically unpleasing}
             {ENDIF}

             Combat_Animate(Attack_Type,1,4);  {Animate the attack}

             GOTOXY(42,6);
             WRITE(Player_Dmg:3,'! ');
             COMBAT_UPDATE_STATS;
             Combat_Animate(Attack_Type,5,6);
        END{IF};
END {COMBAT_PLAYER_ATTACK};

PROCEDURE COMBAT_ENEMY_ATTACK; {The enemy attacks}
VAR
   Enemy_Dmg, Enemy_Attack_Type: byte;
BEGIN
        Enemy_Dmg :=Random(Enemy.Atk div 2) + Enemy.Atk div 2 + 1; {AI will attack RANDOMLY in top half of their atk range}

        IF Enemy.MP >= FB_COST THEN {Enemies are aggressive and will use fireballs whenever they can}
           Enemy_Attack_Type := 2   {NB: In almost all cases, this is the smartest thing for the player to do as well!}
        ELSE
           Enemy_Attack_Type := 1; {Melee attack}
        {ENDIF}

        IF Enemy_Attack_Type = 2 THEN {Fireball}
        BEGIN
           Inc(Enemy_Dmg,Enemy_Dmg div FB_FACTOR);
           Dec(Enemy.MP,FB_COST);
        END{IF};

        Combat_Animate(2+Enemy_Attack_Type,1,4);
        Dec(Player.HP,Enemy_Dmg);

        IF Player.HP < 0 THEN                                                    
           Player.HP := 0; {Negative health is aesthetically unpleasing}
        {ENDIF}

        GOTOXY(30,6);
        WRITE(Enemy_Dmg:3,'! ');
        COMBAT_UPDATE_STATS;
        Combat_Animate(2+Enemy_Attack_Type,5,6);
END {COMBAT_ENEMY_ATTACK};

PROCEDURE COMBAT_SUBMENU(VAR Retreat,Quit : boolean);
VAR
   Action_Selection : byte;
   User_Input : Char;
   Attack_Cancelled : boolean;
BEGIN
     Action_Selection:= 1;
     Attack_Cancelled:= False;

     REPEAT
           REPEAT     
                 Clr(17,7); {Clears the attack bar and options}
                 GOTOXY(4,19);
                 Write('  ) Attack');
                 GOTOXY(4,20);
                 Write('  ) Retreat');
               
                 GotoXY(4, Action_Selection + 18);
                 Write('Þ ');
                 GotoXY(4, Action_Selection + 18);

                 User_Input:= Readkey;
                 Write('  ');

                 CASE Upcase(User_Input) OF
                      'W' : IF (Action_Selection > 1) THEN {CURSOR MOVEMENT}
                               Dec(Action_Selection)
                            ELSE
                               Action_Selection:= 2;
                            {ENDIF}
                      'S' : IF (Action_Selection < 2) THEN
                               Inc(Action_Selection)
                            ELSE
                               Action_Selection:= 1;
                            {ENDIF}
                 END{CASE};
           UNTIL User_Input IN [#32,#13,#27];

           IF User_Input <> #27 THEN
              CASE Action_Selection OF
                1: COMBAT_PLAYER_ATTACK(Attack_Cancelled); {Draws the GUI for attack}
                2: IF Enemy.Retreat_possible = TRUE THEN
                      Retreat:= TRUE
                   ELSE
                   BEGIN
                        GOTOXY(35,24);
                        Write('Cannot Retreat!');
                        Delay(1000,TRUE);
                   END{IF};
              END{CASE}
           ELSE
              Quit:= TRUE;
           {ENDIF}

     UNTIL ((Action_Selection = 2) AND (Enemy.Retreat_Possible = True))
     OR ((Action_Selection = 1) AND (Attack_Cancelled = FALSE)) OR (QUIT = TRUE);
END {COMBAT_SUBMENU};

PROCEDURE INITIALIZE_COMBAT_SCREEN;
BEGIN
     Writeln('     ',Player.Name,' - LV.',Player.Level);
     GOTOXY(60,1);
     Write(Enemy.Name,' - LV.',Enemy.Level);
     COMBAT_UPDATE_STATS; {Print HP, etc. to screen}

     GOTOXY(1,15);
     IF Enemy.Retreat_Possible=FALSE THEN
        Write('•!•!•!•!•!•!•!•') {A UI Guide to show if you can retreat from battle}
     ELSE
        Write(' / / / / / / / ');
     Write('•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••');
     {ENDIF}
END {INITIALIZE_COMBAT_SCREEN};

PROCEDURE COMBAT;
VAR
   Retreat,Quit : Boolean; {Retreat from combat/Quit the game}
   FirstHit: Byte; {Whether the player or the enemy gets the first attack}
   User_Input: char;
BEGIN
     IF Enemy.Retreat_Possible = FALSE THEN
        Transition('³ ¡')
     ELSE
        Transition('³ /');
     Enemy.HP:= Enemy.max_HP;
     Enemy.MP:= Enemy.max_MP;

     Quit:= FALSE;
     Retreat:= False;

     INITIALIZE_COMBAT_SCREEN;

     FirstHit:=RANDOM(2); {50 % chance that the enemy gets first attack}
     IF FirstHit = 0 THEN
        COMBAT_ENEMY_ATTACK;
     {ENDIF}

     WHILE (Player.HP > 0) AND (Enemy.HP > 0) AND (Retreat = FALSE) AND (Quit = FALSE) DO {COMBAT LOOP}
     BEGIN
           Combat_Animate(1,1,1); {Reset sprites to standby}
           Clr(6,0); {Clears the Damage indicator from the previous attack}          
           Clr(17,2); {Clear the attack options from the previous attack}

           IF (Enemy.HP > 0) AND (Player.HP > 0) AND (Retreat = False) THEN
              COMBAT_SUBMENU(Retreat,QUIT); {The player can choose to attack}
           {ENDIF}

           IF (Enemy.HP > 0) AND (Player.HP > 0) AND (Retreat = False) AND (QUIT = FALSE) THEN {The enemy attacks}
              COMBAT_ENEMY_ATTACK;
           {ENDIF}

           IF Quit = TRUE THEN
           BEGIN
                       Clrscr;                                       
                       Writeln('Do you wish to quit the game? (Y)');
                       Writeln('Any progress made since last saving will be lost!');
                       Write('Press ESC to return to the game.');
                       GotoXY(WhereX-1,WhereY);
                       REPEAT
                             User_Input:= upcase(Readkey);
                       UNTIL User_Input IN ['Y',#27];
                       Quit:= UpCase(User_Input) IN ['Y'];
                       IF QUIT = FALSE THEN
                       BEGIN
                            ClrScr;
                            INITIALIZE_COMBAT_SCREEN;
                       END{IF};
           END{IF};                     
     END{WHILE}; {End of Combat}

     IF Enemy.HP <= 0 THEN {The player has won}
     BEGIN
         Combat_animate(5,1,6); {Animate Enemy DEATH}
         Readkey;

         Inc(Player.XP,Enemy.Level*Enemy.XP_Factor); {Give player experience points}
     
         WHILE (Player.Level)*(Player.Level) - Player.XP <= 0 DO
                Level_Up; {The player has met the XP req. for leveling up!}
         {ENDWHILE}; {The player might level up more than once from one battle}

         Combat_Results('W'); {Show results for a WIN}

     END
     ELSE IF (Player.HP <= 0) THEN {the player has lost}
          BEGIN 
             Combat_animate(6,1,6);  {Animate Player's DEATH}
             Readkey;
             Combat_Results('L'); {Show results for a Loss}
          END
          ELSE IF (QUIT = FALSE) THEN
               BEGIN
                    Combat_animate(7,1,6);  {Animate Player's RETREAT}
                    Readkey;
                    Combat_Results('R'); {Show results for a retreat}
               END{IF};
	  {ENDIF}
     {ENDIF}
     Quit_Game:= Quit;
     Quit_Mid_Combat:= Quit;
END {COMBAT};

{*********************}
{OVERWORLD SUBPROGRAMS}
{*********************}

FUNCTION AREA_NAME : STRING; {Returns the area code with a name}
BEGIN
     CASE Player.AREA OF
          1: Area_Name:= 'Home';
          2: Area_Name:= 'Town A';
          3: Area_Name:= 'Rebel Territory';
          4: Area_Name:= 'Rebel Hideout';
     END{CASE};
END {AREA_NAME};

PROCEDURE Game_PRINT_AREA_MAP; {Prints the Map to the screen}
VAR
   Map_Line_Index,Line_Pos : byte;
BEGIN
     GotoXY(1,1);
     Map_Line_Index:= 1;
     Line_Pos := 1;
     REPEAT
           REPEAT
                 IF NOT ((Map[Player.Area,Map_Line_Index,Line_Pos]) IN Map_Specials) THEN
                    Write(Map[Player.Area,Map_Line_Index,Line_Pos])
                 ELSE Write(' ');
                 {ENDIF}
                 Inc(Line_Pos);
           UNTIL Line_Pos > 19;
           Inc(Map_Line_Index);
           Line_Pos:= 1;
           Writeln;
     UNTIL Map_Line_Index > 23;
END {Game_PRINT_AREA_MAP};

PROCEDURE Game_PRINT_INFO; {The player's details are printed to the screen}
VAR
   Counter: byte;
BEGIN
     GotoXY(20, 1);
     write('*', player.name, '* LV. ',player.level);
     GotoXY(20, 2);
     Write('HP: ', player.hp,'/',player.max_hp,'   MP: ', player.mp,'/',player.max_mp);
     GotoXY(20, 4);
     Write('AREA: ',Area_Name);
     GotoXY(20, 5);
     write('---------------');
     Counter := 0;
     REPEAT
           GotoXY(20, 6 + Counter);
           ClrEOL;
           Inc(Counter);
     UNTIL Counter > 3;
END {Game_PRINT_INFO};

PROCEDURE Game_SCREEN_SET;
BEGIN
     ClrScr;
     Game_PRINT_INFO;
     Game_PRINT_AREA_MAP;
END {Game_SCREEN_SET};

PROCEDURE TIMEPASS; {The passage of time in the Game}
BEGIN
     IF Player.Game_Time = 2 THEN
        Player.Game_Time:= 0
     ELSE
        Inc(Player.Game_Time);
     {ENDIF}
     Game_SCREEN_SET;
END {TIMEPASS};

PROCEDURE DISPLAY_MESSAGE(Message:String); {Prints a message to the screen and waits for player response}
VAR
   User_Input : Char;
BEGIN
     REPEAT
           GotoXY(20,7);
           ClrEol;
           Write(Message);
           GotoXY(20,9);
           Write('Press SPACE/ENTER to continue.');
           GotoXY(WhereX-1,WhereY);
           User_Input:= Readkey;
     UNTIL User_Input IN [#32,#13];
     GotoXY(20,7);
     ClrEol;
     GotoXY(20,9);
     ClrEol;
END {DISPLAY_MESSAGE};

PROCEDURE INPUT_A1(pu:char); {Special inputs for Area 1}
BEGIN
      IF (Player.X> 9) AND (Player.Game_Progress = 0) THEN
         Player.X := 9;
      {ENDIF}

      IF (Player.x = 3) AND (Player.y = 2) AND (Player.Game_Progress > 0) AND (upcase(pu) = 'E') THEN
      BEGIN {BED}
            Transition('Z z');
            Player.HP := Player.Max_HP;
            Player.MP := Player.Max_MP;
            TimePass; {The player sleeps safely, and will not risk an encounter with an 'Bad Dream'.}
      END{IF};
END {INPUT_A1};

PROCEDURE INPUT_A2(pu:char); {Special inputs for Area 2}
BEGIN
    IF (player.x = 2) AND (player.y = 2) AND (Player.Game_Time = 0) AND (UPCASE(pu) = 'E') THEN
    BEGIN {ENTER BATTLE with MIRROR}
                       Enemy.name:=Player.Name;
                       Enemy.Level:= Player.Level;

                       Enemy.Max_HP := Player.Max_HP;
                       Enemy.Max_MP := Player.Max_MP;
                       Enemy.ATK := Player.ATK;
                       Enemy.XP_Factor:= 2;
                       Enemy.Retreat_possible := False;
                       Combat;
                       TimePass;
    END{IF};
END {INPUT_A2};

PROCEDURE A3_TallGrass; {Tall grass in Area 3}
VAR
   WinTestCounter : integer; {These two variables are used for checking if the player defeated the rebel}
   WinTest : boolean;
   Encounter_Chance : byte; {Chance of an encounter with the enemy}

BEGIN
    GotoXY(20,7);
    IF (Player.Game_Progress < 4) THEN
      Write('You can hear rebels rustling in the tall grass.')
    ELSE IF (Player.Game_Progress < 10) THEN
             Write('You can hear shifting in the tall grass.')
         ELSE
             Write('You can''t hear anything.');
    {ENDIF}
    Encounter_Chance := Random(25);
    CASE Encounter_Chance OF
    0: IF (Player.Game_Progress < 4) THEN
       BEGIN
         Enemy.name:='REBEL #' + chr(Player.Game_Progress+48);
         Enemy.Level:= 2 + Player.Game_Progress;

         COMBAT_Set_Enemy_Stats; {Calculate's the enemies' stats from their level}

         WinTestCounter:= Player.Combats_Won;
         Combat;
         TimePass;
         WinTest:= WinTestCounter < Player.Combats_Won; {The player has won the last battle; i.e. they defeated the rebel}

         IF WinTest = TRUE THEN
            Inc(Player.Game_Progress);
         {ENDIF}
       END{IF};
    1: IF (Player.Game_Progress < 10) THEN
       BEGIN
         Enemy.name:='BANDIT';
         Enemy.Level:= Random(2)+1;

         COMBAT_Set_Enemy_Stats; {Calculate's the enemies' stats from their level}
         Combat;
         TimePass;
       END{IF};
    END{CASE};
END {A3_TALLGRASS};

PROCEDURE INPUT_A3(pu:char); {Special inputs for Area 3}
BEGIN
    IF (Player.x > 18) AND (Player.Game_Progress < 5) THEN {The player is not allowed to progress}
       Player.x:=18;

    IF Map[3,Player.Y,Player.X] = '×' THEN {Rebels can attack}
       A3_TallGrass  {NOTE: × and the letter 'x' are different; the former is a symbol}
    ELSE
    BEGIN
       GotoXY(20,7);
       ClrEol;
    END{IF};
END {INPUT_A3};

PROCEDURE INPUT_A4(pu:char); {Special inputs for Area 4}
VAR
   WinTestCounter : integer; {These two variables are used for checking if the player defeated each Guard}
   WinTest : boolean;
BEGIN
    IF (Player.Y IN [8,11,14,17]) THEN   {These are the 'ledges' which allow only one way travel.}
    BEGIN
         IF (Player.x in [7,9]) THEN
            Player.X:= 8;
         {ENDIF}
         IF (Player.x <> 8) THEN
            Dec(Player.Y);
         {ENDIF}
    END{IF};


    IF (Player.x = 8) AND (Player.y = ((Player.Game_Progress-2)*3-1)) AND (Player.Game_Progress < 9) THEN
    {The player is fighting the elite four}
       BEGIN
         WinTestCounter:= Player.Combats_Won;
         Enemy.Level:= Player.Game_Progress + 4;
         Enemy.Retreat_possible := False;

         GotoXY(Player.X,Player.Y);
         Write(Player.Look);

         CASE Player.Game_Progress OF
         5: IF Player.Y = 8 THEN
            BEGIN
                  Enemy.Name:= 'GREG';
                  DISPLAY_MESSAGE('GREG: Hey you, get out!');
                  Enemy.Atk:= 20;
                  Enemy.MAX_MP:= 60;
                  Enemy.MAX_HP:= 310;
            END{IF};
         6: IF Player.Y = 11 THEN
            BEGIN
                  Enemy.Name:= 'MURRAY';
                  DISPLAY_MESSAGE('MURRAY: You''ll never make it to the King!');
                  Enemy.Atk:= 68;
                  Enemy.MAX_MP:= 60;
                  Enemy.MAX_HP:= 100;
            END{IF};
         7: IF Player.Y = 14 THEN
            BEGIN
                  Enemy.Name:= 'ANTHONY';
                  DISPLAY_MESSAGE('ANTHONY: I will get revenge for my fallen comrades!');
                  Enemy.Atk:= 50;
                  Enemy.MAX_MP:= 300;
                  Enemy.MAX_HP:= 160;
            END{IF};
         8: IF Player.Y = 17 THEN
            BEGIN
                  Enemy.Name:= 'JEFF';
                  DISPLAY_MESSAGE('JEFF: Zzzz.. Huh, What are you doing here?!');
                  Enemy.Atk:= 38;
                  Enemy.MAX_MP:= 60;
                  Enemy.MAX_HP:= 310;
            END{IF};
         END{CASE};

         WinTestCounter:= Player.Combats_Won;
         Combat;
         TimePass;
         WinTest:= WinTestCounter < Player.Combats_Won; {The player has won the last Combat}
         IF WinTest = True THEN
         BEGIN
              INC(Player.Game_Progress);
              Inc(Player.Y);
         END
         ELSE
             Dec(Player.Y);
       {ENDIF}
    END{IF};
END {INPUT_A4};

PROCEDURE TENT;
VAR
   Bad_Dream_Chance:byte;
BEGIN
   TimePass; {The player rests}
   Bad_Dream_Chance:=Random(3); {Chance of an encounter with a 'Bad Dream'}
   Player.HP := Player.Max_HP; {But first, restore HP and MP}
   Player.MP := Player.Max_MP;
   IF (Bad_Dream_Chance = 0) AND (Player.Game_Progress < 10) THEN
   BEGIN
         Enemy.Level:= Player.Level;
         Enemy.Name:= 'Bad Dream';
         COMBAT_Set_Enemy_Stats; {Calculate's the enemies' stats from their level}
         Enemy.Retreat_possible := False;
         Combat;
   END
   ELSE
         Transition('Z z');
   {ENDIF}
   Game_SCREEN_SET;
END {TENT};

PROCEDURE USER_INPUT;
VAR                    
   User_Input:char; {The user's key input into the program, e.g. move up with a value of 'W'}
BEGIN
      GotoXY(Player.X,Player.Y);
      Write(Player.look);
      GotoXY(Player.X,Player.Y);
      User_Input:= Upcase(Readkey); {Here, we get the player's input}

      GotoXY(player.x,player.y); {place the player in the correct position}
      Write(' ');

      IF (User_Input IN ['A','D','W','S']) AND (Player.HP < Player.Max_HP) THEN
      BEGIN
         Inc(Player.HP,Player.Max_HP DIV 40); {HP restores as you move, or if you press against a wall}
         Game_PRINT_INFO;
      END{IF};

      IF Player.HP > Player.Max_HP THEN
      BEGIN
         Player.HP := Player.Max_HP;
         Game_PRINT_INFO;
      END{IF};


      IF (NOT ((Map[Player.Area,Player.Y,Player.X]) IN Map_Specials)) AND (Upcase(User_Input) IN ['A','D','W','S']) THEN
      BEGIN
           GotoXY(player.x,player.y); {replace the block the player was on in the correct position}
           Write(Map[Player.Area,Player.Y,Player.X]);
      END{IF};  

      CASE Upcase(User_Input) OF {As the maps are an array of string, they are in the form (y,x)}
           'A': IF (Map[Player.Area,Player.Y,Player.x-1] <> '•') THEN
                Dec(player.x);
                {ENDIF}
           'D': IF (Map[Player.Area,Player.Y,Player.x+1] <> '•') THEN
                Inc(player.x);
                {ENDIF}
           'W': IF (Map[Player.Area,Player.Y-1,Player.x] <> '•') THEN
                Dec(player.y);
                {ENDIF}
           'S': IF (Map[Player.Area,Player.Y+1,Player.x] <> '•') THEN
                Inc(player.y);
                {ENDIF}
           'T': IF Player.Game_Progress >= 5 THEN {The player has a tent}
                   Tent;
                {ENDIF}

           #27 : QUIT_GAME := TRUE;
           '1' : BEGIN
                       Clrscr;                                       
                       Write('Do you wish to save the game? (Y/N)');
                       REPEAT
                             User_Input:= upcase(Readkey);
                       UNTIL User_Input IN ['Y','N'];

                       IF UpCase(User_Input) = 'Y' THEN
                          Save_Game; 
                       {ENDIF}
                       Game_SCREEN_SET;
                 END;
      END{CASE};

      IF (QUIT_GAME = FALSE) AND NOT (User_Input IN ['T',#27]) THEN {Do not enable events immediately after a tent is used}
      BEGIN
           CASE PLAYER.AREA OF {Specific input restrictions/actions for each area}
                1: Input_A1(User_Input);
                2: Input_A2(User_Input);
                3: Input_A3(User_Input);
                4: Input_A4(User_Input);
           END;{CASE}
      END{IF};         
END {USER_INPUT};

{*****************************}
{HOME AREA SPECIFIC PROCEDURES}
{*****************************}

PROCEDURE DAD_AI; {MAKES THE DAD NPC SEEM MORE LIFELIKE}
VAR
  DMove:byte; {Randomly selects the direction the NPC will move}
  Random_Message:byte; {Randomises the messages given to the player}
BEGIN
     GotoXY(DAD.x, DAD.y);
     Write(' ');

     IF (Player.Game_Time = 2) AND (Player.Game_Progress = 1) THEN
        DMove:= 20 {If it is night and the player has spoken to DAD, DAD falls asleep and stops moving.}
     ELSE
        DMove:= Random(20); {Randomly selects axis of movement for DAD. 0 is x-axis movement. 1 is y-axis movement.
     {ENDIF}                {Any other value, DAD will stay still.}

     CASE DMove OF
          0: BEGIN  {DAD will move across the x-axis, we only need to know if it will increase or decrease}
                    DMove := Random(2);      {DMove is re-used here, 0 will increase, 1 will decrease}
                    CASE DMove OF
                         0: Inc(DAD.x);
                         1: Dec(DAD.x);
                    END;{CASE}
             END;
          1: BEGIN
                    DMove := Random(2);      {DMove is re-used here, 0 will increase, 1 will decrease}
                    CASE DMove OF
                         0: Inc(DAD.y);
                         1: Dec(DAD.y);
                    END;{CASE}
             END;
     END{CASE};

     IF DAD.x >9 THEN      {set restrictions on the minimum/maximum x and y values for DAD}
        DAD.x:=9;
     {ENDIF}
     IF DAD.x <4 THEN
        DAD.x:=  4;
     {ENDIF}
     IF DAD.y >9 THEN
        DAD.y:=9;
     {ENDIF}
     IF DAD.y <4 THEN
        DAD.y:=4;
     {ENDIF}

     GotoXY(DAD.x, DAD.y); {place the NPC in the correct position}
     Write('*');

     IF (DAD.x = player.x) AND (DAD.y = player.y) THEN
     BEGIN
        GotoXY(Player.X,Player.Y);
        Write(Player.look); {Put player on top}
        IF (Player.Game_Progress >= 1) THEN {Displays a different message after the first time.}
        BEGIN
             IF Player.Game_Time in [0,1] THEN
                DISPLAY_MESSAGE('DAD: Hurry, '+ Player.name+ '!')
             ELSE
             BEGIN
               DISPLAY_MESSAGE('DAD: *ZZZZzzzZzzZZ*');
               Random_Message := Random(100);
               {4 messages for the player}
               CASE Random_Message Of
                    0..50: DISPLAY_MESSAGE('DAD: ...the king...');
                    51..60: DISPLAY_MESSAGE('DAD: ...go....');
                    61..93: DISPLAY_MESSAGE('DAD: ...*SNORE*...');
                    94..99: DISPLAY_MESSAGE('DAD: GO AWAY, '+ Player.name+ '! I''M TRYING TO SLEEP!!!');
               END{CASE};
             END{IF};
        END
        ELSE {Displays a special message the first time the player meets DAD}
        BEGIN
          Player.Game_Progress := 1; {The player has met DAD!}
          CASE Player.Game_Time OF
            0: DISPLAY_MESSAGE('DAD: Good morning, '+ Player.name+ '.');
            1: DISPLAY_MESSAGE('DAD: You''ve slept in, '+ Player.name+ '!');
            2: DISPLAY_MESSAGE('DAD: *yawn*. I''m tired, '+ Player.name+ '.');
          END{CASE};
          DISPLAY_MESSAGE('DAD: Oh yeah, The king''s been kidnapped by rebels!');
          DISPLAY_MESSAGE('DAD: You should probably go save him.');
        END{IF};
     END{IF};
END {DAD_AI};

PROCEDURE DAD_NOTE;
BEGIN
    GotoXY(9,2);

    Write(')');
    GotoXY(20,7);

    IF (Player.x = 9) AND (Player.y = 2) THEN
    BEGIN
       GotoXY(Player.X,Player.Y);
       Write(Player.Look);
       DISPLAY_MESSAGE('Gone out for a while.');
       DISPLAY_MESSAGE('From, DAD.');
    END{IF};
END {DAD_NOTE};

PROCEDURE HOME_BED;
BEGIN
     GOTOXY(2,2);
     Write('|¬|'); 
     GotoXY(20,8);
     IF (Player.x = 3) AND (Player.y = 2) AND (Player.Game_Progress > 0) THEN
     BEGIN
          WRITE('Press E to rest in this bed!');
          GotoXY(20,9);
          WRITE('(Restores HP and MP)');
     END
     ELSE
     BEGIN
          ClrEOL;
          GotoXY(20,9);
          ClrEOL;
     END{IF};
END {HOME_BED};

PROCEDURE AREA_HOME;
BEGIN 
   IF (Player.Game_Progress = 0) THEN
   BEGIN
       GotoXY(20,7);
       Write('Use the W, A, S, D keys to move. Go speak to "*".');
   END;{IF} {this help only prints when player hasn't met DAD}

   IF (Player.Game_Progress < 10) THEN
      DAD_AI
   ELSE
      DAD_NOTE;
   {ENDIF}

   HOME_BED;

   GotoXY(10,9);
   IF Player.Game_Progress = 0 THEN
        Write('|')
   ELSE Write(' ');
   {ENDIF}

   User_Input;
END {AREA_HOME};

{**************************}
{TOWN A SPECIFIC PROCEDURES}
{**************************}

PROCEDURE TOWN_A_SIGN;
BEGIN
    GotoXY(18,3);
    Write('¶');
    GotoXY(20,7);

    IF (Player.x = 18) AND (Player.y = 3) THEN
       WRITE('*WARNING! REBEL TERRITORY AHEAD*')
    ELSE CLREOL;
    {ENDIF}
END {TOWN_A_SIGN};

PROCEDURE MIRROR_AI;
BEGIN
     GotoXY(2,2);
     Write('¤');
     IF (player.x = 2) and (player.y = 2) then
     BEGIN
          GotoXY(20,8);
          IF (Player.Game_Time = 0) AND (Player.Game_Progress < 10) THEN
          BEGIN
             writeln('You see a hazy reflection in the magic mirror...');
             GotoXY(20,10);
             write('Press E to take a closer look.');
          END
          ELSE
          BEGIN
             writeln('You can''t see anything in the mirror.'); 
             GotoXY(20,10);
             IF (Player.Game_Progress < 10) THEN
             write('Maybe you should come back again later?');
          END{IF};
     END{IF}
     ELSE
     BEGIN
          GotoXY(20,8);
          clreol;
          GotoXY(20,10);
          clreol;
     END;
END {MIRROR_AI};

PROCEDURE AREA_TOWN_A;
BEGIN
   TOWN_A_Sign; {the procedure for the sign}
   MIRROR_AI;
   User_Input;
END {AREA_TOWN_A};

{***********************************}
{REBEL TERRITORY SPECIFIC PROCEDURES}
{***********************************}

PROCEDURE GUARD_AI;
BEGIN
     GotoXY(18,2);
     Write('©|');

     IF (player.x = 18) and (player.y = 2) THEN
     BEGIN
          GotoXY(Player.X,Player.Y);
          Write(Player.look); {Put player on top}
          IF Player.Game_Progress < 4 THEN
          BEGIN          
                DISPLAY_MESSAGE('GREG: I hope no one attacks my friends in the tall grass!');
                DISPLAY_MESSAGE('GREG: That would be really mean.');
          END
          ELSE
          BEGIN
                DISPLAY_MESSAGE('GREG: Oh no, where''s my rebel squadron?!');
                DISPLAY_MESSAGE('GREG: Maybe they went back to the hideout!');
                DISPLAY_MESSAGE('You found a TENT!');
                DISPLAY_MESSAGE('Press T to use the tent at any time.');
                DISPLAY_MESSAGE('Using it restores your HP and MP!');
                Player.Game_Progress:= 5;
          END{IF};
     END{IF};
END {Guard_AI};

PROCEDURE AREA_REBEL_TERRITORY;
BEGIN
   IF Player.Game_Progress <= 4 THEN
         Guard_AI;
   {ENDIF}
   User_Input;
END {AREA_REBEL_TERRITORY};

PROCEDURE Game_Complete;
VAR
   Counter : integer;
BEGIN
    Save_Game;
    Transition('% ÷');

    Counter:= 0;
    GotoXY(22,2);
    Write('CONGRATULATIONS, YOU SAVED THE KING!!!');
    REPEAT
         GotoXY(1,1);
         Inc(Counter);
         IF Counter MOD 2 = 0 THEN
         BEGIN
              Write('% ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷');
              GotoXY(1,3);
              Write('÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ %');
         END
         ELSE
         BEGIN
              Write('÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ %');
              GotoXY(1,3);
              Write('% ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷ % ÷');
         END{IF};
         Delay(300,TRUE);
    UNTIL (Keypressed) AND (Counter > 5);
END{Game_Complete};

PROCEDURE KING_AI;
BEGIN
     GotoXY(18,22);
     Write('Ø');

     IF (player.x = 18) and (player.y = 22) THEN
     BEGIN
           DISPLAY_MESSAGE('KING: Thank-you for rescuing me!');
           DISPLAY_MESSAGE('KING: I''m sure the rebels will leave now.');
           DISPLAY_MESSAGE('KING: We can finally lead peaceful lives...');
           DISPLAY_MESSAGE('KING: ...');
           Player.Game_Progress:= 10;
           Quit_Game := True;
           Game_Complete;
     END{IF};
END {KING_AI};

PROCEDURE REBEL_GUARD_1;
BEGIN
     GOTOXY(8,8);
     Write('©');
END {REBEL_GUARD_1};

PROCEDURE REBEL_GUARD_2;
BEGIN
     GOTOXY(8,11);
     Write('$');
END {REBEL_GUARD_2};

PROCEDURE REBEL_GUARD_3;
BEGIN
     GOTOXY(8,14);
     Write('®');
END {REBEL_GUARD_3};

PROCEDURE REBEL_GUARD_4;
BEGIN
     GOTOXY(8,17);
     Write('§');
END {REBEL_GUARD_4};

PROCEDURE AREA_REBEL_HIDEOUT;
BEGIN
      IF Player.Game_Progress < 6 THEN
         Rebel_Guard_1;
      {ENDIF}
      IF Player.Game_Progress < 7 THEN
         Rebel_Guard_2;
      {ENDIF}
      IF Player.Game_Progress < 8 THEN
         Rebel_Guard_3;
      {ENDIF}
      IF Player.Game_Progress < 9 THEN
         Rebel_Guard_4;
      {ENDIF}
      IF Player.Game_Progress < 10 THEN
          King_AI;
      {ENDIF}
      User_Input;
END {AREA_REBEL_HIDEOUT};

{********************}
{MAIN GAME PROCEDURES}
{********************}
PROCEDURE FIND_Symbol(Area: Integer; Symbol:Char; VAR SX,SY: byte);
BEGIN
     SY:= 24;
     SX:= 19;
     WHILE (MAP[Area,SY,SX] <> Symbol) AND (SY > 0) DO
     BEGIN
           Dec(SY);
           SX:= 19;
           WHILE (MAP[Area,SY,SX] <> Symbol) AND (SX > 0) DO
                 Dec(SX);
           {ENDWHILE}
     END{WHILE};
END {FIND_Symbol};

PROCEDURE Overworld;
BEGIN
      Game_SCREEN_SET;
      REPEAT
            CASE Player.AREA OF {Perform the appropriate events for each area}
                 1: AREA_HOME;
                 2: AREA_TOWN_A;
                 3: AREA_REBEL_TERRITORY;
                 4: AREA_REBEL_HIDEOUT;
            END{CASE};
      UNTIL ((Map[Player.Area,Player.Y,Player.X]) IN ['N','P']) OR (QUIT_GAME = TRUE) OR (PLAYER.HP <= 0);

      IF (Map[Player.Area,Player.Y,Player.X]) = 'N'
      THEN
          BEGIN 
               Inc(Player.Area);
               FIND_Symbol(Player.Area,'P',Player.X,Player.Y); {Sends the player to the 'P' on the next map}
               Inc(Player.X); {The Player won't be on the 'P' spot, but next to it}
          END{IF}
          ELSE IF (Map[Player.Area,Player.Y,Player.X]) = 'P'
          THEN
               BEGIN
                    Dec(Player.Area);
                    FIND_Symbol(Player.Area,'N',Player.X,Player.Y); {Sends the player to the 'N' on the previous map}
                    Dec(Player.X);
               END{IF}         
END {Overworld};

PROCEDURE Game_INITIALIZE;
BEGIN
     Quit_Game := False;                                                       
     Quit_Mid_Combat:= False;
     {Randomise Initial position values for the first NPC, DAD}
     REPEAT
      DAD.X:= Random(3)+3;
     UNTIL (DAD.x <> player.x); {Makes sure DAD can't start adjacent to or on the player, or on a wall}

     REPEAT
      DAD.y:= Random(3)+3;
     UNTIL (DAD.y <> player.y);
END {Game_INITIALIZE};

PROCEDURE PLAYER_INITIALIZE; {When the player starts a new game or dies}
BEGIN
     Player.HP := Player.Max_HP;
     Player.MP := Player.Max_MP;
     Player.x:= 3;
     Player.y:= 2;
     Player.Area := 1;
END {PLAYER_INITIALIZE};                            

PROCEDURE Game;
VAR
   User_Input : char;
BEGIN
     Transition('« »');
     Game_INITIALIZE;
     REPEAT
                 REPEAT {This loop allows the user to move from one area to another.}
                        Overworld;
                 UNTIL (QUIT_GAME = TRUE) OR (Player.HP <= 0); {This is when the player loses or wants to quit}
          
                 IF (QUIT_GAME = TRUE) AND (QUIT_MID_COMBAT = FALSE) THEN
                 BEGIN 
                       Clrscr;                                       
                       Writeln('Do you wish to save the game before you quit? (Y/N)');
                       Write('Press ESC to return to the game.'); {Ask the user if they want to save their changes}

                       REPEAT
                             User_Input:= upcase(Readkey);
                       UNTIL User_Input IN ['Y','N',#27];
                       Quit_game:= UpCase(User_Input) IN ['Y','N'];

                       IF UpCase(User_Input) = 'Y' THEN
                          Save_Game; 
                       {ENDIF}
                 END
                 ELSE IF (Player.HP <= 0) THEN
                      BEGIN
                            PLAYER_INITIALIZE;
                            Transition('X x');
                      {ENDIF}
                 END{IF};
     UNTIL (Quit_game = TRUE);
END {Game};

{*********************}
{MAIN MENU SUBPROGRAMS}
{*********************}

PROCEDURE GET_PASSWORD(VAR Input_Pass : String; Can_Exit:boolean);
VAR
   User_Input : Char;
   Test,User_Input_Number: integer;
   StartX,Counter : byte;
BEGIN
  Input_PASS := ''; {Initialise the string}
  StartX:= WhereX;
  REPEAT
     Write('    ');
     GotoXY(StartX,WhereY);
     Counter:=Length(Input_Pass); {Print any of the password already entered}
     WHILE Counter > 0 DO
     BEGIN
        Dec(Counter);
        Write('*'); {Hide the characters}
     END{WHILE};
     User_Input := Readkey; {Get input}
     Val(User_Input,User_Input_Number,Test); {Check if user entered a number}       
     IF (Test = 0) AND (Length(Input_Pass) < 4) THEN {The user entered a number}
     BEGIN
        Input_Pass:= Input_Pass + User_Input; {Add the user's entered number to the password}
        Write(User_Input);
        Delay(200,True); {Briefly display the number the user has entered}
     END
     ELSE
        IF User_Input = #8 THEN {The user pushed backspace; delete their last entered number}
        BEGIN
           Delete(Input_Pass,Length(Input_Pass),1);
           GotoXY(WhereX-1,WhereY);
        END{IF};
     {ENDIF}
  UNTIL ((User_Input = #13) AND (Length(Input_Pass) = 4)) OR ((User_Input = #27) AND (CAN_EXIT = TRUE));
  IF (User_Input = #27) AND (CAN_EXIT = TRUE) THEN
     Input_PASS := '';
  {ENDIF}
END {GET_PASSWORD};

PROCEDURE MM_CHARACTER_CREATE; {CHARACTER CREATION SCREEN}
VAR
     User_Input: char;
     LookChoice, Test: Integer;
     Atk_Boost,HP_Boost,MP_Boost, Stat_boost: byte;
     Temp_Pass:string;
BEGIN
     ClrScr;

     Writeln('Welcome to EPIC ADVENTURE!':54);
     Writeln;

     REPEAT
      Writeln;
      Write('Please enter a player name (Max 9 characters): ');
      Readln(Player.name);

      Writeln('Ah, your name is ',player.name,'? (Press C to change, or any other key to continue.)');
      User_input := Readkey;
     UNTIL (UpCase(User_input) <> 'C');

     REPEAT
      REPEAT
             Writeln;
             player.look:= ' '; {We reset the look at the start of the loop to give the player a chance to change it}
             Writeln('Select a "look" for your character by pressing a number.');
             Writeln('1: O');
             Writeln('2: X');
             Writeln('3: º');
             Writeln('4: @');

             User_input := Readkey;
             Val(User_input, LookChoice, test);

             {Converts the user's input into an integer that can be used in a case statement. If it is 0, it is valid}

             Writeln;
             IF NOT (LookChoice IN [1..4]) OR (TEST <> 0) THEN {Invalid entry}
             BEGIN
                  write('Please enter a number from 1 to 5.');
                 writeln;
             END{IF};

      UNTIL LookChoice IN [1..4];

      CASE LookChoice OF              {Here, we convert the number input into a special character.}
           1: Player.look:='O';
           2: Player.look:='X';
           3: Player.look:='º';
           4: Player.look:='@';
      END{CASE};

      Writeln('You have selected: ', Player.look);
      Writeln('Press C to change, or any other key to continue.');
      User_input := readkey;

     UNTIL (UpCase(User_input) <> 'C');
     Writeln;

     Writeln(player.name, ', it is time to select your skills. They will be randomised.');

     REPEAT
           Writeln;
           Player.Level:= 3; {The player starts at level 3.}
           Stat_boost:= 3; {These points to be distributed randomly}

           HP_Boost:= Random(Stat_boost+1);
           MP_Boost:= Random(Stat_boost - HP_Boost + 1);
           Atk_Boost:=Stat_boost - HP_Boost - MP_Boost;

           Player.Max_HP := Base_HP + (HP_Boost * HPC);
           Player.Max_MP := Base_MP + (MP_Boost * MPC);
           Player.ATK := Base_ATK + (Atk_Boost * ATKC);

           IF Player.name = 'SQUID' THEN {'Easter Egg'/Cheat!}
           BEGIN
                Inc(Player.ATK,ATKC);
                Inc(Player.Max_HP,HPC);
                Inc(Player.Max_MP,MPC);
                Inc(Player.Level,3);
           END{IF};

           Writeln('Your stats are:');
           Writeln('HP: ',Player.Max_HP);
           Writeln('MP: ',Player.Max_MP);
           Writeln('ATK: ',Player.ATK);
           Writeln;
           Writeln('Press C to roll another set of stats, or any other key to continue.');
           User_input := Readkey;
     UNTIL (UpCase(User_input) <> 'C');
     Writeln;
     Writeln('Please enter a 4-digit numeric password.');
     Writeln('This will be used if you want to delete your character.');
     Writeln;
     Write('Pass: ');
     GET_PASSWORD(Temp_Pass,FALSE);   
     Player.Password:=Temp_Pass;

     {Initialise other variables}
     Player.XP := 0;
     Player.Combats_won := 0;
     Player.Combats_lost:= 0;

     {Initialise OVERWORLD Variables}
     Player.Game_Time := Random(3); {Sets the time of day randomly. 0 is morning, 1 is afternoon, 2 is night}
     Player.Game_Progress:= 0;

     {Initial position values for the player}
     Game_Initialize;
     Player_Initialize;

     Current_Player_Pos := Filesize(SAVE); {The current player is the new one that was just created.}
     Seek(SAVE,Current_Player_Pos);
     Write(SAVE,Player);

     Save_Game; {Move the file to the front}

     Writeln;
     Writeln(player.name, ', your adventure is about to begin!');
     Writeln;
     Write('(Press any key to continue)');
     Readkey;
END {MM_CHARACTER_CREATE};

PROCEDURE PRINT_STATS(Indent : byte); {Indent is the value for how far to the right the info will be}
BEGIN
     Writeln(' ':Indent,'Name               : ', Player.Name,' (',Player.Look,')');
     Writeln(' ':Indent,'Level              : ', Player.Level);
     Writeln(' ':Indent,'XP Until Next Level: ', Player.Level*Player.Level - Player.XP);
     Writeln;
     Writeln(' ':Indent,'HP                 : ',Player.HP,'/',Player.MAX_HP);
     Writeln(' ':Indent,'MP                 : ',Player.MP,'/',Player.MAX_MP);
     Writeln(' ':Indent,'Attack             : ',Player.ATK);
     Writeln;
     Writeln(' ':Indent,'Area               : ',Area_Name);
     Writeln(' ':Indent,'# of Battles       : ', Player.Combats_won + Player.Combats_lost);
     Writeln(' ':Indent,'Game Completion    : ', Player.Game_Progress*10,'%');
END {PRINT_STATS};

PROCEDURE MM_CHARACTER_LOAD(Var Player_Selected : boolean);
VAR
   Save_Selection : byte;
   User_Input : char;
   Test_Pass : String;
BEGIN
    Player_Selected := FALSE;
     
    ClrScr;
    Writeln('===============================================================================');
    Writeln('LOAD FILE');
    Writeln('===============================================================================');
    Writeln('Use A and D to move forward and back between user files.');
    Writeln('Press BACKSPACE to delete a save file.');
    Save_Selection := 0; {Initialise the variable}

    REPEAT
     IF Filesize(SAVE) > 0 THEN
     BEGIN
        REPEAT
             Clr(6,20); {Clear the next 18 lines}
             GOTOXY(1,7);
             {Print Player Character Details}
             GotoXY(1,23);
             Write('--------------------------------------------------------------------------------');

             IF (Save_Selection = filesize(SAVE)-1) THEN
                GotoXY(78,23)
             ELSE
                GotoXY((79 div (filesize(SAVE)-1) * (Save_Selection) ),23);
             {ENDIF}
             Write('///');
             GotoXY(31,7);
             IF Save_Selection > 0 THEN {Indicate to the user that they can go backward}
                Write('««  ')
             ELSE
                Write('    ');
             {ENDIF}
             Write('FILE: ',Save_Selection+1,'/',Filesize(SAVE));
             IF (Save_Selection < Filesize(SAVE) - 1) THEN {Indicate to the user that they can go forwad}
                Write('  »»')
             ELSE
                Write('    ');
             {ENDIF}
             Writeln;
             Writeln;
             Seek(SAVE,Save_Selection);
             Read(SAVE,Player);

             PRINT_STATS(25);
             Writeln;

             GOTOXY(10,2); {Move cursor back to title}
             User_Input:= Readkey; {Get input from user}

             IF (UpCase(User_Input) = 'A') AND (Save_Selection > 0) THEN {CURSOR MOVEMENT}
                 Dec(Save_Selection);
             {ENDIF}

             IF (UpCase(User_Input) = 'D') AND (Save_Selection < Filesize(SAVE) - 1) THEN
                 Inc(Save_Selection);
             {ENDIF}

        UNTIL User_Input IN [#32,#27,#13,#8];

        Player_Selected := User_Input IN [#32,#13]; {User HAS selected their character}              
     END
     ELSE
     BEGIN
        Writeln; 
        Write('No Save Files Exist.');
        GotoXY(WhereX-1,WhereY);
        Readkey;
     END{IF};

     IF Player_Selected = TRUE THEN
     BEGIN
       ClrScr;
       Current_Player_Pos := Save_Selection;
       Write('Character File ''',Player.Name,''' loaded.');
       GotoXY(WhereX-1,WhereY);
       Readkey;
     END{IF};

     IF USER_INPUT = #8 THEN
     BEGIN
         GotoXY(1,24);

         Write('Please enter your deletion password: ');
         GET_PASSWORD(Test_Pass,TRUE);
         Clr(24,0);
         IF Test_Pass = Player.Password THEN
         BEGIN
              Write('Are you sure you want to delete your Save File? (Y/N)');
              REPEAT
                    User_Input := Readkey;
              UNTIL UpCase(User_Input) IN ['Y','N'];
              IF UpCase(User_Input) = 'Y' THEN
              BEGIN
                   Delete_SAVE(Save_Selection);
                   Save_Selection:= 0;
              END{IF};         
         END
         ELSE IF Length(Test_Pass) = 4 THEN
              BEGIN
                   Write('Incorrect Password!');
                   Delay(1000,False);
              END{IF};
         {ENDIF}
     END{IF};
    UNTIL (Filesize(Save) = 0) OR (User_Input = #27) OR (Player_Selected = True);
END {MM_CHARACTER_LOAD};

PROCEDURE MM_TOP_PLAYERS;                                        
CONST
     Shrink = 1.3;
TYPE
    Players = record
      Name : string[9];
      Level: integer;
      Combatswon : integer;
      Combatslost : integer;
    END;
VAR
   TopPlayers : Array[1..16] OF Players;
   ArrayPos,FilePos,Gap,Players_Loaded,Maximum: byte;
   Swapped : boolean;
BEGIN
     ArrayPos:= 1;
     FilePos:= 1;
     Players_Loaded:= 0;

     IF Filesize(SAVE) > 0 THEN
     BEGIN
      REPEAT {Only read from the 15 most recent records}
           Seek(SAVE,FilePos - 1);
           Read(SAVE,Player);

           IF Player.Game_Progress = 10 THEN
           BEGIN
                TopPlayers[ArrayPos].Name := Player.Name;
                TopPlayers[ArrayPos].Level := Player.Level;
                TopPlayers[ArrayPos].Combatswon := Player.Combats_won;
                TopPlayers[ArrayPos].Combatslost := Player.Combats_lost;
                Inc(ArrayPos);
           END{IF};
           Inc(FilePos);
      UNTIL (FilePos > Filesize(SAVE)) OR (ArrayPos > 15);

      Players_Loaded:= ArrayPos-1;
      Gap:= Players_Loaded;

      REPEAT
           ArrayPos:= 1;
           Gap:= trunc(Gap/shrink);
           IF Gap < 1 THEN
              Gap:= 1;
           {ENDIF}
           Swapped:= False;
           REPEAT
                 IF TopPlayers[ArrayPos].Level > TopPlayers[ArrayPos + Gap].Level THEN
                 BEGIN
                    TopPlayers[16]:= TopPlayers[ArrayPos]; {Swap the next lowest position to the lowest level player}
                    TopPlayers[ArrayPos]:= TopPlayers[ArrayPos + Gap];
                    TopPlayers[ArrayPos + Gap]:=TopPlayers[16];{The 16th slot of the array is used for temporary storage}
                    Swapped:= True;
                 END{IF};
                 Inc(ArrayPos);
           UNTIL (ArrayPos + Gap) > Players_Loaded
      UNTIL (Gap = 1) AND (Swapped = False);
    END{IF};

    ClrScr;
    Writeln('===============================================================================');
    Writeln('HALL OF FAME');
    Writeln('===============================================================================');
    Writeln;
    Writeln('The lowest level players who saved the king are shown here.');
    Writeln;

    ArrayPos:=1;
    IF (Players_Loaded = 0) THEN
        Write('No one has completed the game yet!')
    ELSE
    BEGIN
          Writeln('| RANK |   NAME   | LEVEL | BATTLES |'); {Table header}
          WHILE ((ArrayPos <= Players_Loaded)) DO
          BEGIN
               Write('| ',ArrayPos:4);
               Write(' | ',TopPlayers[ArrayPos].Name:8);
               Write(' | ',TopPlayers[ArrayPos].Level:5);
               Writeln(' | ',TopPlayers[ArrayPos].CombatsWon+TopPlayers[ArrayPos].CombatsLost:7,' |');
               Inc(ArrayPos);
          END{WHILE};
    END{IF};

    Readkey;
END {MM_TOP_PLAYERS};

PROCEDURE MM_MAIN_MENU; {The game's main menu}
VAR
   Menu_Selection : byte; {Position of cursor on main menu}
   User_Input : char;
   EXIT_GAME, Save_Loaded : boolean;
BEGIN
  EXIT_GAME:= FALSE;
  IF Filesize(Save) > 0 THEN
        Menu_Selection:= 2 {If a SAVEFILE exists, go to the 'load character' position by default}
  ELSE Menu_Selection:= 1; {Otherwise, go to 'create character'}
  {ENDIF}

  REPEAT
     ClrScr;
     Writeln('   ___  ___  ___   ___    ___  ___  __   __ ___  _  _  _____  _   _  ___  ___ ');
     Writeln('  | __|| _ \|_ _| / __|  /   \|   \ \ \ / /| __|| \| ||_   _|| | | || _ \| __|');
     Writeln('  | _| |  _/ | | | (__   | - || |) | \ V / | _| | .` |  | |  | |_| ||   /| _| ');
     Writeln('  |___||_|  |___| \___|  |_|_||___/   \_/  |___||_|\_|  |_|   \___/ |_|_\|___|');
     Writeln;
     Writeln;
     Writeln;
     Writeln(' ':11,') CREATE a NEW character');
     Writeln(' ':11,') LOAD a saved character');
     Writeln(' ':11,') VIEW a list of players who have saved the king');
     Writeln(' ':11,') EXIT the game');

     REPEAT
           GotoXY(10, Menu_Selection + 7);
           Write('Þ ');
           GotoXY(10, Menu_Selection + 7); {Move the blinker back to the cursor, increasing visibility}

           User_Input:= Readkey;
           Write('  ');

           CASE Upcase(User_Input) OF
                'W' : IF (Menu_Selection > 1) THEN {CURSOR MOVEMENT}
                          Dec(Menu_Selection)
                      ELSE
                          Menu_Selection:= 4;
                      {ENDIF}                                           
                'S' : IF (Menu_Selection < 4) THEN
                          Inc(Menu_Selection)
                      ELSE
                          Menu_Selection:= 1;
                      {ENDIF}
           END{CASE};
     UNTIL User_Input in [#32,#13,#27];

     IF (User_Input in [#32,#13]) AND (Menu_Selection in [1..3]) {If the player made a selection} THEN
     BEGIN
        CASE Menu_Selection OF
             1: MM_Character_Create;
             2: MM_Character_Load(Save_Loaded);
             3: MM_Top_Players;
        END{CASE};

        IF (Menu_Selection = 1) OR ((Menu_Selection = 2) AND (Save_Loaded = True)) THEN {If the player made/loaded a save file}
           Game;
        {ENDIF}

     END{IF};

     EXIT_GAME := (Menu_Selection = 4) OR (User_Input = #27);
     {This exists outside the case statement so that the player can go straight into the game after loading}
  UNTIL EXIT_GAME = TRUE;
END {MM_MAIN_MENU};

BEGIN {MAINLINE}
     INITIALIZE;
     MM_Main_Menu;                                                                 
     Close(SAVE);
     DONEWINCRT;
END. {MAINLINE}                 