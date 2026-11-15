'
' ================================================================
' Miner's Claim - QB64 v0.3.0 (Python v1.0.0 mechanics port)
' 320x200 scrolling mining game prototype
'
' Controls
'   Store:
'     1-8  Buy supplies
'     L    Leave the Mercantile
'     V    Save game
'     O    Load game
'     Q    Quit
'
'   Mine:
'     Arrow keys  Move / dig into adjacent tile
'     L           Place ladder on current open tile
'     M           Enter Mercantile when near the store
'     S           Enter Assay Office when near it
'     T           Drop a TNT stick, 10-second fuse
'     P           Pick up loose blasted ore nearby
'     V           Save game
'     O           Load game
'     Q           Quit
'
' Notes
'   - This is a QB64-first prototype, not pure Microsoft QuickBASIC.
'   - All graphics are generated with primitive drawing calls.
'   - No external image or sound files are required.
'   - The world is larger than the 320x200 screen and scrolls both ways.
' ================================================================

OPTION _EXPLICIT

CONST SCRW = 320
CONST SCRH = 200
' Practical values:
'   3 = 960x600
'   4 = 1280x800
'   5 = 1600x1000
'   6 = 1920x1200
'   8 = 2560x1600
CONST SCREEN_SCALE = 6
CONST WIN_GOAL = 1000000
CONST MAX_SCORES = 10
CONST SAVE_FILE = "miners_claim_qb64_v030_save.txt"
CONST LEGACY_SAVE_FILE = "miners_claim_save.txt"
CONST SCORE_FILE = "miners_claim_scores.txt"
CONST TNT_COUNTDOWN_FRAMES = 300
CONST TNT_RADIUS = 5
CONST WINW = SCRW * SCREEN_SCALE
CONST WINH = SCRH * SCREEN_SCALE

CONST HUDH = 24
CONST MSGH = 16
CONST VIEWX = 0
CONST VIEWY = HUDH
CONST VIEWW = SCRW
CONST VIEWH = SCRH - HUDH - MSGH

CONST TILE = 16
CONST MW = 128
CONST MH = 96
CONST SURFACE_Y = 2
CONST CLAIM_SHAFT_X = 72
CONST LEGACY_SHAFT_X = 28
CONST START_ROOM_LEFT = CLAIM_SHAFT_X - 3
CONST START_ROOM_RIGHT = CLAIM_SHAFT_X + 4

CONST ST_STORE = 0
CONST ST_MINE = 1
CONST ST_ASSAY = 2
CONST ST_GAMEOVER = 3
CONST ST_HIGHSCORES = 4
CONST ST_NAMEENTRY = 5
CONST ST_WINNER = 6
CONST ST_BANK = 7
CONST ST_SALOON = 8
CONST ST_ENCOUNTER = 9

CONST TILE_AIR = 0
CONST TILE_GRASS = 1
CONST TILE_DIRT1 = 2
CONST TILE_DIRT2 = 3
CONST TILE_DIRT3 = 4
CONST TILE_ROCK = 5
CONST TILE_GOLD = 6
CONST TILE_SILVER = 7
CONST TILE_GEM = 8
CONST TILE_WATER = 9
CONST TILE_GAS = 10
CONST TILE_SAND = 11
CONST TILE_SNAKE = 12
CONST TILE_LADDER = 13
CONST TILE_BEDROCK = 14

CONST KEY_UP = 18432
CONST KEY_DOWN = 20480
CONST KEY_LEFT = 19200
CONST KEY_RIGHT = 19712

TYPE MinerState
    x AS INTEGER
    y AS INTEGER
    lives AS INTEGER
    money AS LONG
    food AS INTEGER
    water AS INTEGER
    ladders AS INTEGER
    shovel AS INTEGER
    pickaxe AS INTEGER
    wheelbarrow AS INTEGER
    lantern AS INTEGER
    tnt AS INTEGER
    haul AS LONG
    steps AS LONG
    deepest AS INTEGER
END TYPE

DIM SHARED World(0 TO MW - 1, 0 TO MH - 1) AS INTEGER
DIM SHARED LooseLoot(0 TO MW - 1, 0 TO MH - 1) AS LONG
DIM SHARED Miner AS MinerState
DIM SHARED GameState AS INTEGER
DIM SHARED Msg AS STRING
DIM SHARED SellInput AS STRING
DIM SHARED NameInput AS STRING
DIM SHARED LastRunMessage AS STRING
DIM SHARED FinalScore AS LONG
DIM SHARED FinalDepth AS LONG
DIM SHARED HighName(1 TO MAX_SCORES) AS STRING
DIM SHARED HighScore(1 TO MAX_SCORES) AS LONG
DIM SHARED HighDepth(1 TO MAX_SCORES) AS LONG
DIM SHARED CamX AS INTEGER
DIM SHARED CamY AS INTEGER
DIM SHARED MoveDelay AS INTEGER
DIM SHARED ActionDelay AS INTEGER
DIM SHARED JumpGrace AS INTEGER
DIM SHARED PrevL AS INTEGER
DIM SHARED PrevJ AS INTEGER
DIM SHARED PrevM AS INTEGER
DIM SHARED PrevS AS INTEGER
DIM SHARED PrevQ AS INTEGER
DIM SHARED PrevV AS INTEGER
DIM SHARED PrevO AS INTEGER
DIM SHARED PrevTnt AS INTEGER
DIM SHARED PrevPick AS INTEGER
DIM SHARED TntActive AS INTEGER
DIM SHARED TntX AS INTEGER
DIM SHARED TntY AS INTEGER
DIM SHARED TntFuseFrames AS LONG
DIM SHARED Tick AS LONG
DIM SHARED ScreenHandle AS LONG
DIM SHARED GamePage AS LONG
' The bank and new street state intentionally live outside the original MinerState.
DIM SHARED BankBalance AS LONG
DIM SHARED TownLegacy AS INTEGER
DIM SHARED BankInput AS STRING
DIM SHARED LastCardPlayer AS INTEGER
DIM SHARED LastCardHouse AS INTEGER
DIM SHARED EncounterKind AS INTEGER ' 1 banker, 2 bandit
DIM SHARED EncounterCooldown AS INTEGER
DIM SHARED HazardKind AS INTEGER ' 0 none, 1 water, 2 gas
DIM SHARED HazardExposure AS INTEGER
DIM SHARED CartMode AS INTEGER ' 0 empty, 1 supply parcels, 2 ore
DIM SHARED PurchasesSinceStore AS INTEGER
DIM SHARED WasUnderground AS INTEGER
DIM SHARED Facing AS INTEGER
DIM SHARED PrevX AS INTEGER

ScreenHandle = _NEWIMAGE(WINW, WINH, 32)
GamePage = _NEWIMAGE(SCRW, SCRH, 32)
SCREEN ScreenHandle
_DEST GamePage
_TITLE "Miner's Claim - QB64 v0.3.0"
_DISPLAY
RANDOMIZE TIMER

LoadHighScores
InitGame
GameState = ST_HIGHSCORES
Msg = "High scores loaded. Press N for new game, L to load, Q to quit."

DO
    _LIMIT 30
    Tick = Tick + 1

    IF GameState = ST_STORE OR GameState = ST_MINE OR GameState = ST_ASSAY OR GameState = ST_BANK OR GameState = ST_SALOON THEN
        UpdateTNT
    END IF

    SELECT CASE GameState
        CASE ST_STORE
            HandleStoreInput
            DrawStore

        CASE ST_MINE
            HandleMineInput
            ApplyGravity
            CheckAdjacentHazards
            UpdateCart
            UpdateCamera
            DrawMine
            CheckGameOver
            CheckWin

        CASE ST_ASSAY
            HandleAssayInput
            DrawAssay
            CheckWin

        CASE ST_BANK
            HandleBankInput
            DrawBank
            CheckWin

        CASE ST_SALOON
            HandleSaloonInput
            DrawSaloon
            CheckWin

        CASE ST_ENCOUNTER
            HandleEncounterInput
            UpdateCamera
            DrawMine
            DrawEncounter

        CASE ST_HIGHSCORES
            HandleHighScoresInput
            DrawHighScores

        CASE ST_NAMEENTRY
            HandleNameEntryInput
            DrawNameEntry

        CASE ST_WINNER
            HandleWinnerInput
            DrawWinner

        CASE ST_GAMEOVER
            DrawGameOver
            HandleGameOverInput
    END SELECT

    PresentFrame
    _DISPLAY
LOOP

' ================================================================
' Scaled presentation
' ================================================================

SUB PresentFrame
    _DEST ScreenHandle
    CLS
    _PUTIMAGE (0, 0)-(WINW - 1, WINH - 1), GamePage, ScreenHandle
    _DEST GamePage
END SUB

' ================================================================
' Initialization
' ================================================================

SUB InitGame
    DIM x AS INTEGER
    DIM y AS INTEGER

    FOR x = 0 TO MW - 1
        FOR y = 0 TO MH - 1
            World(x, y) = BaseTile(y)
            LooseLoot(x, y) = 0
        NEXT y
    NEXT x

    AddOreAndHazards
    CarveStarterClaim
    AddStarterDeposits

    TownLegacy = 0
    BankBalance = 0
    BankInput = ""
    LastCardPlayer = 0
    LastCardHouse = 0
    EncounterKind = 0
    EncounterCooldown = 0
    HazardKind = 0
    HazardExposure = 0
    CartMode = 0
    PurchasesSinceStore = 0
    WasUnderground = 0
    Facing = -1
    Miner.x = 8
    Miner.y = SURFACE_Y - 1
    Miner.lives = 5
    Miner.money = 150
    Miner.food = 0
    Miner.water = 0
    Miner.ladders = 0
    Miner.shovel = 0
    Miner.pickaxe = 0
    Miner.wheelbarrow = 0
    Miner.lantern = 0
    Miner.tnt = 0
    Miner.haul = 0
    Miner.steps = 0
    Miner.deepest = 0

    CamX = 0
    CamY = 0
    MoveDelay = 0
    ActionDelay = 0
    JumpGrace = 0
    PrevL = 0
    PrevJ = 0
    PrevM = 0
    PrevS = 0
    PrevQ = 0
    PrevV = 0
    PrevO = 0
    PrevTnt = 0
    PrevPick = 0
    TntActive = 0
    TntX = 0
    TntY = 0
    TntFuseFrames = 0
    SellInput = ""
    NameInput = ""
    LastRunMessage = ""
    FinalScore = 0
    FinalDepth = 0
    Msg = "WEST: shops and bank. EAST: mine at x=72."
    GameState = ST_STORE
END SUB

FUNCTION BaseTile% (y AS INTEGER)
    IF y < SURFACE_Y THEN
        BaseTile% = TILE_AIR
    ELSEIF y = SURFACE_Y THEN
        BaseTile% = TILE_GRASS
    ELSEIF y < 18 THEN
        BaseTile% = TILE_DIRT1
    ELSEIF y < 38 THEN
        BaseTile% = TILE_DIRT2
    ELSEIF y < 58 THEN
        BaseTile% = TILE_DIRT3
    ELSEIF y < MH - 2 THEN
        BaseTile% = TILE_ROCK
    ELSE
        BaseTile% = TILE_BEDROCK
    END IF
END FUNCTION

SUB AddOreAndHazards
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM i AS INTEGER
    DIM cx AS INTEGER
    DIM cy AS INTEGER
    DIM r AS INTEGER
    DIM kind AS INTEGER

    ' Random single-tile deposits and hazards.
    FOR x = 1 TO MW - 2
        FOR y = SURFACE_Y + 2 TO MH - 3
            IF RND < .020 AND y > 4 THEN World(x, y) = TILE_GOLD
            IF RND < .014 AND y > 10 THEN World(x, y) = TILE_SILVER
            IF RND < .006 AND y > 18 THEN World(x, y) = TILE_GEM
            IF RND < .006 AND y > 14 THEN World(x, y) = TILE_SNAKE
            IF RND < .006 AND y > 20 THEN World(x, y) = TILE_GAS
            IF RND < .004 AND y > 12 THEN World(x, y) = TILE_WATER
            IF RND < .020 AND y > 34 AND y < 62 THEN World(x, y) = TILE_SAND
        NEXT y
    NEXT x

    ' Larger pockets.  These create the visual mine features:
    ' water pockets, gas pockets, sand bands, and richer ore clusters.
    FOR i = 1 TO 120
        cx = 2 + INT(RND * (MW - 4))
        cy = SURFACE_Y + 4 + INT(RND * (MH - SURFACE_Y - 8))
        r = 1 + INT(RND * 3)

        IF cy < 18 THEN
            IF RND < .55 THEN
                kind = TILE_GOLD
            ELSE
                kind = TILE_DIRT1
            END IF
        ELSEIF cy < 35 THEN
            IF RND < .25 THEN
                kind = TILE_WATER
            ELSEIF RND < .55 THEN
                kind = TILE_SILVER
            ELSE
                kind = TILE_DIRT2
            END IF
        ELSEIF cy < 58 THEN
            IF RND < .25 THEN
                kind = TILE_GAS
            ELSEIF RND < .55 THEN
                kind = TILE_SAND
            ELSEIF RND < .72 THEN
                kind = TILE_GEM
            ELSE
                kind = TILE_DIRT3
            END IF
        ELSE
            IF RND < .22 THEN
                kind = TILE_GEM
            ELSEIF RND < .45 THEN
                kind = TILE_GAS
            ELSE
                kind = TILE_ROCK
            END IF
        END IF

        StampPatch cx, cy, r, kind
    NEXT i
END SUB

SUB StampPatch (cx AS INTEGER, cy AS INTEGER, r AS INTEGER, kind AS INTEGER)
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM dx AS INTEGER
    DIM dy AS INTEGER
    DIM d AS INTEGER

    FOR y = cy - r TO cy + r
        FOR x = cx - r TO cx + r
            IF InBounds%(x, y) THEN
                dx = x - cx
                dy = y - cy
                d = dx * dx + dy * dy
                IF d <= r * r + INT(RND * 2) THEN
                    IF y > SURFACE_Y AND y < MH - 2 THEN
                        World(x, y) = kind
                    END IF
                END IF
            END IF
        NEXT x
    NEXT y
END SUB

SUB CarveStarterClaim
    DIM y AS INTEGER
    DIM x AS INTEGER

    ' The visible CLAIM sign/hoist is the true starter mine entrance.
    ' Earlier builds had the playable starter shaft near the Mercantile,
    ' which made the level layout misleading.
    FOR y = SURFACE_Y - 1 TO SURFACE_Y + 7
        IF InBounds%(CLAIM_SHAFT_X, y) THEN World(CLAIM_SHAFT_X, y) = TILE_LADDER
    NEXT y

    ' Small worked starter room at the bottom of the claim ladder.
    FOR y = SURFACE_Y + 5 TO SURFACE_Y + 7
        FOR x = START_ROOM_LEFT TO START_ROOM_RIGHT
            IF InBounds%(x, y) THEN World(x, y) = TILE_AIR
        NEXT x
    NEXT y

    ' Keep the surface route from Mercantile to Claim clear/readable.
    FOR x = 0 TO CLAIM_SHAFT_X + 8
        IF InBounds%(x, SURFACE_Y - 1) THEN World(x, SURFACE_Y - 1) = TILE_AIR
    NEXT x
END SUB


SUB AddStarterDeposits
    ' Guaranteed starter vein.
    '
    ' Critical design rule:
    '   The player must find saleable ore at the visible CLAIM entrance.
    '   The sign, shaft, starter room, and early ore must all agree.
    '
    ' Coordinate note:
    '   SURFACE_Y is the grass row.
    '   SURFACE_Y + 1 is the first underground row.
    '   SURFACE_Y + 2 is the second underground row.

    DIM x AS INTEGER
    DIM y AS INTEGER

    ' Make the whole claim tutorial area safe and readable.
    FOR y = SURFACE_Y + 1 TO SURFACE_Y + 10
        FOR x = CLAIM_SHAFT_X - 6 TO CLAIM_SHAFT_X + 10
            IF InBounds%(x, y) THEN
                IF World(x, y) = TILE_WATER OR World(x, y) = TILE_GAS OR World(x, y) = TILE_SNAKE OR World(x, y) = TILE_SAND THEN
                    World(x, y) = TILE_DIRT1
                END IF
            END IF
        NEXT x
    NEXT y

    ' Reassert claim ladder after safety cleanup.
    FOR y = SURFACE_Y - 1 TO SURFACE_Y + 7
        IF InBounds%(CLAIM_SHAFT_X, y) THEN World(CLAIM_SHAFT_X, y) = TILE_LADDER
    NEXT y

    ' FIRST UNDERGROUND ROW: real valuables directly beside the CLAIM ladder.
    ' Player stands at CLAIM_SHAFT_X and mines left/right.
    IF InBounds%(CLAIM_SHAFT_X - 1, SURFACE_Y + 1) THEN World(CLAIM_SHAFT_X - 1, SURFACE_Y + 1) = TILE_GOLD
    IF InBounds%(CLAIM_SHAFT_X + 1, SURFACE_Y + 1) THEN World(CLAIM_SHAFT_X + 1, SURFACE_Y + 1) = TILE_GOLD
    IF InBounds%(CLAIM_SHAFT_X - 2, SURFACE_Y + 1) THEN World(CLAIM_SHAFT_X - 2, SURFACE_Y + 1) = TILE_SILVER
    IF InBounds%(CLAIM_SHAFT_X + 2, SURFACE_Y + 1) THEN World(CLAIM_SHAFT_X + 2, SURFACE_Y + 1) = TILE_SILVER

    ' SECOND UNDERGROUND ROW: more real value, still adjacent to the CLAIM ladder.
    IF InBounds%(CLAIM_SHAFT_X - 1, SURFACE_Y + 2) THEN World(CLAIM_SHAFT_X - 1, SURFACE_Y + 2) = TILE_SILVER
    IF InBounds%(CLAIM_SHAFT_X + 1, SURFACE_Y + 2) THEN World(CLAIM_SHAFT_X + 1, SURFACE_Y + 2) = TILE_GEM
    IF InBounds%(CLAIM_SHAFT_X - 2, SURFACE_Y + 2) THEN World(CLAIM_SHAFT_X - 2, SURFACE_Y + 2) = TILE_GOLD
    IF InBounds%(CLAIM_SHAFT_X + 2, SURFACE_Y + 2) THEN World(CLAIM_SHAFT_X + 2, SURFACE_Y + 2) = TILE_GOLD

    ' Starter-room wall valuables for after the first descent.
    IF InBounds%(START_ROOM_RIGHT, SURFACE_Y + 5) THEN World(START_ROOM_RIGHT, SURFACE_Y + 5) = TILE_GOLD
    IF InBounds%(START_ROOM_RIGHT + 1, SURFACE_Y + 5) THEN World(START_ROOM_RIGHT + 1, SURFACE_Y + 5) = TILE_GOLD
    IF InBounds%(START_ROOM_RIGHT, SURFACE_Y + 6) THEN World(START_ROOM_RIGHT, SURFACE_Y + 6) = TILE_SILVER
    IF InBounds%(START_ROOM_RIGHT + 1, SURFACE_Y + 6) THEN World(START_ROOM_RIGHT + 1, SURFACE_Y + 6) = TILE_GEM
    IF InBounds%(START_ROOM_RIGHT - 1, SURFACE_Y + 7) THEN World(START_ROOM_RIGHT - 1, SURFACE_Y + 7) = TILE_GEM

    ' Second nearby pocket for the first expansion after selling.
    IF InBounds%(CLAIM_SHAFT_X + 8, SURFACE_Y + 6) THEN World(CLAIM_SHAFT_X + 8, SURFACE_Y + 6) = TILE_GOLD
    IF InBounds%(CLAIM_SHAFT_X + 9, SURFACE_Y + 7) THEN World(CLAIM_SHAFT_X + 9, SURFACE_Y + 7) = TILE_SILVER
    IF InBounds%(CLAIM_SHAFT_X + 10, SURFACE_Y + 8) THEN World(CLAIM_SHAFT_X + 10, SURFACE_Y + 8) = TILE_GOLD
    IF InBounds%(CLAIM_SHAFT_X + 12, SURFACE_Y + 9) THEN World(CLAIM_SHAFT_X + 12, SURFACE_Y + 9) = TILE_GEM
END SUB


' ================================================================
' Save games, high scores, and run endings
' ================================================================

SUB SaveGame
    DIM f AS INTEGER
    DIM x AS INTEGER
    DIM y AS INTEGER
    f = FREEFILE
    OPEN SAVE_FILE FOR OUTPUT AS #f
    PRINT #f, "MINERS_CLAIM_SAVE_V3"
    PRINT #f, Miner.x
    PRINT #f, Miner.y
    PRINT #f, Miner.lives
    PRINT #f, Miner.money
    PRINT #f, Miner.food
    PRINT #f, Miner.water
    PRINT #f, Miner.ladders
    PRINT #f, Miner.shovel
    PRINT #f, Miner.pickaxe
    PRINT #f, Miner.wheelbarrow
    PRINT #f, Miner.lantern
    PRINT #f, Miner.tnt
    PRINT #f, Miner.haul
    PRINT #f, Miner.steps
    PRINT #f, Miner.deepest
    PRINT #f, TntActive
    PRINT #f, TntX
    PRINT #f, TntY
    PRINT #f, TntFuseFrames
    PRINT #f, BankBalance
    PRINT #f, TownLegacy

    FOR y = 0 TO MH - 1
        FOR x = 0 TO MW - 1
            PRINT #f, World(x, y)
        NEXT x
    NEXT y

    FOR y = 0 TO MH - 1
        FOR x = 0 TO MW - 1
            PRINT #f, LooseLoot(x, y)
        NEXT x
    NEXT y

    CLOSE #f
    Msg = "Game saved to " + SAVE_FILE + "."
    SOUND 800, 1
    SOUND 1000, 1
END SUB

SUB LoadGame
    DIM f AS INTEGER
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM hdr AS STRING

    DIM loadName AS STRING
    loadName = SAVE_FILE
    IF _FILEEXISTS(loadName) = 0 THEN
        IF _FILEEXISTS(LEGACY_SAVE_FILE) THEN loadName = LEGACY_SAVE_FILE
    END IF
    IF _FILEEXISTS(loadName) = 0 THEN
        Msg = "No saved game file found."
        SOUND 120, 2
        EXIT SUB
    END IF

    f = FREEFILE
    OPEN loadName FOR INPUT AS #f

    LINE INPUT #f, hdr
    IF hdr <> "MINERS_CLAIM_SAVE_V1" AND hdr <> "MINERS_CLAIM_SAVE_V2" AND hdr <> "MINERS_CLAIM_SAVE_V3" THEN
        CLOSE #f
        Msg = "Save file is not compatible."
        SOUND 120, 2
        EXIT SUB
    END IF

    INPUT #f, Miner.x
    INPUT #f, Miner.y
    INPUT #f, Miner.lives
    INPUT #f, Miner.money
    INPUT #f, Miner.food
    INPUT #f, Miner.water
    INPUT #f, Miner.ladders
    INPUT #f, Miner.shovel
    INPUT #f, Miner.pickaxe
    INPUT #f, Miner.wheelbarrow
    INPUT #f, Miner.lantern
    INPUT #f, Miner.tnt
    INPUT #f, Miner.haul
    INPUT #f, Miner.steps
    INPUT #f, Miner.deepest

    IF hdr = "MINERS_CLAIM_SAVE_V2" OR hdr = "MINERS_CLAIM_SAVE_V3" THEN
        INPUT #f, TntActive
        INPUT #f, TntX
        INPUT #f, TntY
        INPUT #f, TntFuseFrames
        IF TntActive THEN
            IF TntFuseFrames < 0 THEN TntFuseFrames = 0
            IF TntFuseFrames > TNT_COUNTDOWN_FRAMES THEN TntFuseFrames = TNT_COUNTDOWN_FRAMES
        ELSE
            TntFuseFrames = 0
        END IF
    ELSE
        TntActive = 0
        TntX = 0
        TntY = 0
        TntFuseFrames = 0
    END IF

    IF hdr = "MINERS_CLAIM_SAVE_V3" THEN
        INPUT #f, BankBalance
        INPUT #f, TownLegacy
        IF BankBalance < 0 THEN BankBalance = 0
        IF TownLegacy <> 0 THEN TownLegacy = -1
    ELSE
        BankBalance = 0
        TownLegacy = -1
    END IF

    FOR y = 0 TO MH - 1
        FOR x = 0 TO MW - 1
            INPUT #f, World(x, y)
        NEXT x
    NEXT y

    IF hdr = "MINERS_CLAIM_SAVE_V2" OR hdr = "MINERS_CLAIM_SAVE_V3" THEN
        FOR y = 0 TO MH - 1
            FOR x = 0 TO MW - 1
                INPUT #f, LooseLoot(x, y)
            NEXT x
        NEXT y
    ELSE
        FOR y = 0 TO MH - 1
            FOR x = 0 TO MW - 1
                LooseLoot(x, y) = 0
            NEXT x
        NEXT y
    END IF

    CLOSE #f
    GameState = ST_MINE
    EncounterCooldown = 0
    EncounterKind = 0
    HazardKind = 0
    HazardExposure = 0
    CartMode = 0
    PurchasesSinceStore = 0
    WasUnderground = 0
    Facing = -1
    SuppressHeldActionKeys
    Msg = "Saved game loaded."
    SOUND 1000, 1
    SOUND 800, 1
END SUB

SUB LoadHighScores
    DIM f AS INTEGER
    DIM i AS INTEGER
    DIM hdr AS STRING
    DIM scoreLine AS STRING
    DIM depthLine AS STRING

    FOR i = 1 TO MAX_SCORES
        HighName(i) = "---"
        HighScore(i) = 0
        HighDepth(i) = 0
    NEXT i

    IF _FILEEXISTS(SCORE_FILE) = 0 THEN EXIT SUB

    f = FREEFILE
    OPEN SCORE_FILE FOR INPUT AS #f

    LINE INPUT #f, hdr
    IF hdr <> "MINERS_CLAIM_SCORES_V1" THEN
        CLOSE #f
        EXIT SUB
    END IF

    FOR i = 1 TO MAX_SCORES
        IF EOF(f) THEN EXIT FOR
        LINE INPUT #f, HighName(i)

        IF EOF(f) THEN EXIT FOR
        LINE INPUT #f, scoreLine
        HighScore(i) = VAL(scoreLine)

        IF EOF(f) THEN EXIT FOR
        LINE INPUT #f, depthLine
        HighDepth(i) = VAL(depthLine)
    NEXT i

    CLOSE #f
END SUB

SUB SaveHighScores
    DIM f AS INTEGER
    DIM i AS INTEGER

    f = FREEFILE
    OPEN SCORE_FILE FOR OUTPUT AS #f

    PRINT #f, "MINERS_CLAIM_SCORES_V1"
    FOR i = 1 TO MAX_SCORES
        PRINT #f, HighName(i)
        PRINT #f, HighScore(i)
        PRINT #f, HighDepth(i)
    NEXT i

    CLOSE #f
END SUB

SUB InsertHighScore (playerName AS STRING, score AS LONG, depth AS LONG)
    DIM i AS INTEGER
    DIM j AS INTEGER

    IF playerName = "" THEN playerName = "MINER"
    playerName = LEFT$(playerName, 12)

    FOR i = 1 TO MAX_SCORES
        IF score >= HighScore(i) THEN
            FOR j = MAX_SCORES TO i + 1 STEP -1
                HighName(j) = HighName(j - 1)
                HighScore(j) = HighScore(j - 1)
                HighDepth(j) = HighDepth(j - 1)
            NEXT j

            HighName(i) = playerName
            HighScore(i) = score
            HighDepth(i) = depth
            SaveHighScores
            EXIT SUB
        END IF
    NEXT i
END SUB

SUB BeginNameEntry (reason AS STRING)
    FinalScore = Miner.money + BankBalance + Miner.haul
    FinalDepth = BestDepthFeet&
    LastRunMessage = reason
    NameInput = ""
    GameState = ST_NAMEENTRY
END SUB

SUB CheckWin
    IF GameState <> ST_MINE AND GameState <> ST_ASSAY AND GameState <> ST_BANK AND GameState <> ST_SALOON THEN EXIT SUB

    IF Miner.money + BankBalance >= WIN_GOAL THEN
        FinalScore = Miner.money + BankBalance + Miner.haul
        FinalDepth = BestDepthFeet&
        LastRunMessage = "You reached $" + LTRIM$(STR$(WIN_GOAL)) + " and won the claim!"
        NameInput = ""
        GameState = ST_WINNER
        SOUND 900, 2
        SOUND 1200, 2
        SOUND 1500, 3
    END IF
END SUB

' ================================================================
' Input
' ================================================================
SUB ClearActionKeys
    PrevL = 0
    PrevJ = 0
    PrevM = 0
    PrevS = 0
    PrevQ = 0
    PrevV = 0
    PrevO = 0
    PrevTnt = 0
    PrevPick = 0
END SUB

SUB SuppressHeldActionKeys
    ' Mine actions now use INKEY$ only, so this just clears action state
    ' and applies a tiny delay after changing screens.
    ClearActionKeys
    ActionDelay = 6
END SUB


SUB HandleStoreInput
    DIM k AS STRING
    DIM oldMoney AS LONG
    oldMoney = Miner.money
    k = UCASE$(INKEY$)

    SELECT CASE k
        CASE "1"
            IF Miner.shovel = 0 THEN
                IF Spend%(10) THEN
                    Miner.shovel = 1
                    Msg = "Bought a shovel."
                    BeepBuy
                END IF
            ELSE
                Msg = "You already own a shovel."
            END IF

        CASE "2"
            IF Miner.pickaxe = 0 THEN
                IF Spend%(15) THEN
                    Miner.pickaxe = 1
                    Msg = "Bought a pickaxe."
                    BeepBuy
                END IF
            ELSE
                Msg = "You already own a pickaxe."
            END IF

        CASE "3"
            IF Miner.wheelbarrow = 0 THEN
                IF Spend%(30) THEN
                    Miner.wheelbarrow = 1
                    Msg = "Bought a wheelbarrow. Your haul capacity increased."
                    BeepBuy
                END IF
            ELSE
                Msg = "You already own a wheelbarrow."
            END IF

        CASE "4"
            IF Spend%(20) THEN
                Miner.ladders = Miner.ladders + 1
                Msg = "Bought one ladder. You now have " + LTRIM$(STR$(Miner.ladders)) + "."
                BeepBuy
            END IF

        CASE "5"
            IF Spend%(5) THEN
                Miner.food = Miner.food + 1
                Msg = "Bought one food ration."
                BeepBuy
            END IF

        CASE "6"
            IF Spend%(5) THEN
                Miner.water = Miner.water + 1
                Msg = "Bought one water canteen."
                BeepBuy
            END IF

        CASE "7"
            IF Miner.lantern = 0 THEN
                IF Spend%(10) THEN
                    Miner.lantern = 1
                    Msg = "Bought a lantern."
                    BeepBuy
                END IF
            ELSE
                Msg = "You already own a lantern."
            END IF

        CASE "8"
            IF Spend%(25) THEN
                Miner.tnt = Miner.tnt + 1
                Msg = "Bought one stick of TNT. Handle with care."
                BeepBuy
            END IF

        CASE "L"
            GameState = ST_MINE
            SuppressHeldActionKeys
            IF Miner.wheelbarrow AND PurchasesSinceStore > 0 THEN
                CartMode = 1
            ELSE
                CartMode = 0
            END IF
            PurchasesSinceStore = 0
            WasUnderground = 0
            Msg = "Travel EAST to the CLAIM. Return WEST with ore."

        CASE "V"
            SaveGame

        CASE "O"
            LoadGame

        CASE "Q"
            BeginNameEntry "You abandoned the claim."
    END SELECT

    IF Miner.money < oldMoney THEN PurchasesSinceStore = PurchasesSinceStore + 1
    CheckGameOver
END SUB

SUB HandleMineInput
    DIM dx AS INTEGER
    DIM dy AS INTEGER
    DIM k AS STRING

    ' Mine action keys are event keys only.  This routine intentionally
    ' avoids SELECT CASE for letter actions and avoids _KEYDOWN(ASC(...))
    ' for letters.  The TNT key is handled first as a simple IF test.
    k = INKEY$

    IF ActionDelay > 0 THEN ActionDelay = ActionDelay - 1

    IF k <> "" AND ActionDelay = 0 THEN
        IF k = "T" OR k = "t" THEN
            DropTNT
            ActionDelay = 6
        ELSEIF k = "P" OR k = "p" THEN
            PickupLooseLoot
            ActionDelay = 6
        ELSEIF k = "L" OR k = "l" THEN
            PlaceLadder
            ActionDelay = 6
        ELSEIF k = "J" OR k = "j" THEN
            JumpUp
            ActionDelay = 6
        ELSEIF k = "M" OR k = "m" THEN
            IF NearStore% THEN
                GameState = ST_STORE
                Msg = "Back at the Mercantile."
            ELSE
                Msg = "The Mercantile is near the left side of the surface camp."
            END IF
            ActionDelay = 6
        ELSEIF k = "S" OR k = "s" THEN
            EnterAssayOffice
            ActionDelay = 6
        ELSEIF k = "B" OR k = "b" THEN
            EnterBankOffice
            ActionDelay = 6
        ELSEIF k = "N" OR k = "n" THEN
            EnterSaloon
            ActionDelay = 6
        ELSEIF k = "V" OR k = "v" THEN
            SaveGame
            ActionDelay = 6
        ELSEIF k = "O" OR k = "o" THEN
            LoadGame
            ActionDelay = 6
        ELSEIF k = "Q" OR k = "q" THEN
            BeginNameEntry "You abandoned the claim."
            ActionDelay = 6
        END IF
    END IF

    IF MoveDelay > 0 THEN
        MoveDelay = MoveDelay - 1
        EXIT SUB
    END IF

    dx = 0
    dy = 0

    IF _KEYDOWN(KEY_LEFT) THEN dx = -1
    IF _KEYDOWN(KEY_RIGHT) THEN dx = 1
    IF _KEYDOWN(KEY_UP) THEN dy = -1
    IF _KEYDOWN(KEY_DOWN) THEN dy = 1

    ' Prefer horizontal movement if opposing keys or diagonal keys are down.
    IF dx <> 0 THEN dy = 0

    IF dx <> 0 OR dy <> 0 THEN
        IF dx <> 0 THEN Facing = dx
        TryMove dx, dy
        MoveDelay = 4
    END IF
END SUB

SUB HandleAssayInput
    DIM k AS STRING
    DIM amount AS LONG
    DIM allAmount AS LONG

    k = INKEY$
    IF k = "" THEN EXIT SUB

    SELECT CASE k
        CASE CHR$(13)
            IF SellInput = "" THEN
                Msg = "Assayer: Type an amount, press A for all, or L to leave."
            ELSE
                amount = VAL(SellInput)
                SellHaulAmount amount
            END IF

        CASE CHR$(8)
            IF LEN(SellInput) > 0 THEN SellInput = LEFT$(SellInput, LEN(SellInput) - 1)

        CASE "0" TO "9"
            IF LEN(SellInput) < 6 THEN
                SellInput = SellInput + k
                Msg = "Assayer: Amount $" + SellInput + ". Press Enter to sell."
            END IF

        CASE "A", "a"
            allAmount = Miner.haul
            SellHaulAmount allAmount

        CASE "C", "c"
            SellInput = ""
            Msg = "Assayer: Cleared sale amount."

        CASE "L", "l", "M", "m", CHR$(27)
            SellInput = ""
            GameState = ST_MINE
            SuppressHeldActionKeys
            Msg = "You step out of the Assay Office."
    END SELECT
END SUB

SUB HandleHighScoresInput
    DIM k AS STRING

    k = UCASE$(INKEY$)

    SELECT CASE k
        CASE "N", CHR$(13)
            InitGame

        CASE "L", "O"
            LoadGame

        CASE "Q"
            SYSTEM
    END SELECT
END SUB

SUB HandleNameEntryInput
    DIM k AS STRING
    DIM ch AS INTEGER

    k = INKEY$
    IF k = "" THEN EXIT SUB

    ch = ASC(k)

    SELECT CASE k
        CASE CHR$(13)
            IF NameInput = "" THEN NameInput = "MINER"
            InsertHighScore NameInput, FinalScore, FinalDepth
            LoadHighScores
            GameState = ST_HIGHSCORES
            Msg = "Score recorded. Press N for new game, L to load, Q to quit."

        CASE CHR$(8)
            IF LEN(NameInput) > 0 THEN NameInput = LEFT$(NameInput, LEN(NameInput) - 1)

        CASE CHR$(27)
            NameInput = "MINER"
            InsertHighScore NameInput, FinalScore, FinalDepth
            LoadHighScores
            GameState = ST_HIGHSCORES
            Msg = "Score recorded as MINER."

        CASE ELSE
            IF LEN(NameInput) < 12 THEN
                IF (ch >= 48 AND ch <= 57) OR (ch >= 65 AND ch <= 90) OR (ch >= 97 AND ch <= 122) OR ch = 32 THEN
                    NameInput = NameInput + k
                END IF
            END IF
    END SELECT
END SUB

SUB HandleWinnerInput
    DIM k AS STRING

    k = INKEY$
    IF k = "" THEN EXIT SUB

    IF k = CHR$(13) OR UCASE$(k) = "N" THEN
        GameState = ST_NAMEENTRY
        NameInput = ""
        Msg = "Enter your name for the high-score board."
    ELSEIF UCASE$(k) = "Q" THEN
        GameState = ST_NAMEENTRY
        NameInput = ""
        Msg = "Enter your name before quitting."
    END IF
END SUB

SUB HandleGameOverInput
    DIM k AS STRING
    k = UCASE$(INKEY$)

    SELECT CASE k
        CASE "R"
            InitGame
        CASE "N"
            BeginNameEntry Msg
        CASE "H"
            GameState = ST_HIGHSCORES
            Msg = "High scores."
        CASE "Q"
            SYSTEM
    END SELECT
END SUB

' ================================================================
' Economy and inventory
' ================================================================

FUNCTION Spend% (cost AS INTEGER)
    IF Miner.money >= cost THEN
        Miner.money = Miner.money - cost
        Spend% = -1
    ELSE
        Msg = "You do not have enough money."
        Spend% = 0
        SOUND 90, 2
    END IF
END FUNCTION

FUNCTION HaulCapacity& ()
    IF Miner.wheelbarrow THEN
        HaulCapacity& = 300
    ELSE
        HaulCapacity& = 75
    END IF
END FUNCTION

SUB EnterAssayOffice
    IF NearAssay% THEN
        GameState = ST_ASSAY
        CartMode = 0
        WasUnderground = 0
        SellInput = ""
        IF Miner.haul > 0 THEN
            Msg = "Assayer: How much of your haul do you want to sell?"
        ELSE
            Msg = "Assayer: Bring me gold, silver, or gems and I'll price it fair."
        END IF
    ELSE
        Msg = "Stand near the ASSAY office and press S to go inside."
        SOUND 120, 2
    END IF
END SUB

SUB SellHaulAmount (amount AS LONG)
    DIM saleAmount AS LONG

    ' QB/QB64 SUB parameters are normally passed by reference.
    ' Copy the argument immediately so selling all cannot accidentally
    ' alias Miner.haul while this routine changes Miner.haul.
    saleAmount = amount

    IF Miner.haul <= 0 THEN
        Msg = "Assayer: You have no ore or gems to sell."
        SOUND 120, 2
        EXIT SUB
    END IF

    IF saleAmount <= 0 THEN
        Msg = "Assayer: Enter a sale amount greater than zero."
        SOUND 120, 2
        EXIT SUB
    END IF

    IF saleAmount > Miner.haul THEN saleAmount = Miner.haul

    Miner.haul = Miner.haul - saleAmount
    Miner.money = Miner.money + saleAmount
    SellInput = ""

    Msg = "Assayer paid $" + LTRIM$(STR$(saleAmount)) + ". Money $" + LTRIM$(STR$(Miner.money)) + ", haul $" + LTRIM$(STR$(Miner.haul)) + "."
    BeepSell
END SUB

FUNCTION NearStore% ()
    DIM west AS INTEGER
    DIM east AS INTEGER
    west = 1: east = 11
    IF TownLegacy THEN west = 0: east = 12
    IF Miner.x >= west AND Miner.x <= east AND Miner.y <= SURFACE_Y + 4 THEN
        NearStore% = -1
    ELSE
        NearStore% = 0
    END IF
END FUNCTION

FUNCTION NearAssay% ()
    DIM west AS INTEGER
    DIM east AS INTEGER
    west = 27: east = 37
    IF TownLegacy THEN west = 10: east = 25
    IF Miner.x >= west AND Miner.x <= east AND Miner.y <= SURFACE_Y + 4 THEN
        NearAssay% = -1
    ELSE
        NearAssay% = 0
    END IF
END FUNCTION

FUNCTION NearBank% ()
    IF TownLegacy THEN NearBank% = 0: EXIT FUNCTION
    IF Miner.x >= 15 AND Miner.x <= 23 AND Miner.y <= SURFACE_Y + 4 THEN
        NearBank% = -1
    ELSE
        NearBank% = 0
    END IF
END FUNCTION

FUNCTION NearSaloon% ()
    IF TownLegacy THEN NearSaloon% = 0: EXIT FUNCTION
    IF Miner.x >= 41 AND Miner.x <= 53 AND Miner.y <= SURFACE_Y + 4 THEN
        NearSaloon% = -1
    ELSE
        NearSaloon% = 0
    END IF
END FUNCTION



' ================================================================
' Frontier additions ported from the Python v1.0.0 game.
' ================================================================

SUB EnterBankOffice
    IF NearBank% = 0 THEN
        Msg = "Stand near BANK and press B."
        EXIT SUB
    END IF
    GameState = ST_BANK
    BankInput = ""
    Msg = "Bank: type amount then D deposit or W withdraw."
    SuppressHeldActionKeys
END SUB

SUB HandleBankInput
    DIM k AS STRING
    DIM amount AS LONG
    k = UCASE$(INKEY$)
    IF k = "" THEN EXIT SUB
    SELECT CASE k
        CASE "0" TO "9"
            IF LEN(BankInput) < 8 THEN BankInput = BankInput + k
        CASE CHR$(8)
            IF LEN(BankInput) > 0 THEN BankInput = LEFT$(BankInput, LEN(BankInput) - 1)
        CASE "C"
            BankInput = ""
        CASE "D"
            amount = VAL(BankInput)
            IF amount <= 0 THEN
                Msg = "Enter a positive amount."
            ELSEIF amount > Miner.money THEN
                Msg = "Not enough cash to deposit."
            ELSE
                Miner.money = Miner.money - amount
                BankBalance = BankBalance + amount
                Msg = "Deposited $" + LTRIM$(STR$(amount)) + "."
            END IF
            BankInput = ""
        CASE "W"
            amount = VAL(BankInput)
            IF amount <= 0 THEN
                Msg = "Enter a positive amount."
            ELSEIF amount > BankBalance THEN
                Msg = "Insufficient bank funds."
            ELSE
                BankBalance = BankBalance - amount
                Miner.money = Miner.money + amount
                Msg = "Withdrew $" + LTRIM$(STR$(amount)) + "."
            END IF
            BankInput = ""
        CASE "L", CHR$(27)
            GameState = ST_MINE
            SuppressHeldActionKeys
    END SELECT
END SUB

SUB DrawBank
    CLS
    LINE (6, 8)-(313, 168), _RGB32(46, 57, 71), BF
    LINE (6, 8)-(313, 168), _RGB32(218, 177, 92), B
    COLOR _RGB32(255, 217, 124), _RGB32(46, 57, 71)
    _PRINTSTRING (88, 18), "FRONTIER BANK"
    COLOR _RGB32(240, 232, 205), _RGB32(46, 57, 71)
    _PRINTSTRING (28, 44), "Protect your earnings in town."
    _PRINTSTRING (28, 66), "Cash: $" + LTRIM$(STR$(Miner.money))
    _PRINTSTRING (28, 83), "Bank: $" + LTRIM$(STR$(BankBalance))
    _PRINTSTRING (28, 108), "Amount: $" + BankInput + "_"
    _PRINTSTRING (28, 136), "D Deposit  W Withdraw  C Clear"
    _PRINTSTRING (28, 152), "L Leave  V/O from mine to save"
    DrawMessageBar
END SUB

SUB EnterSaloon
    IF NearSaloon% = 0 THEN
        Msg = "Stand near SALOON and press N."
        EXIT SUB
    END IF
    GameState = ST_SALOON
    Msg = "D: drink $5; P: high card $10; L: leave."
    SuppressHeldActionKeys
END SUB

SUB HandleSaloonInput
    DIM k AS STRING
    DIM winnings AS LONG
    k = UCASE$(INKEY$)
    SELECT CASE k
        CASE "D"
            IF Miner.money < 5 THEN
                Msg = "Not enough cash for a drink."
            ELSE
                Miner.money = Miner.money - 5
                Miner.water = Miner.water + 1
                Msg = "Bought a drink for $5. Water +1."
            END IF
        CASE "P"
            IF Miner.money < 10 THEN
                Msg = "Need $10 to play high card."
            ELSE
                LastCardPlayer = INT(RND * 13) + 1
                LastCardHouse = INT(RND * 13) + 1
                winnings = 0
                IF LastCardPlayer > LastCardHouse THEN winnings = 10
                IF LastCardPlayer < LastCardHouse THEN winnings = -10
                Miner.money = Miner.money + winnings
                IF winnings > 0 THEN
                    Msg = "You won $10!"
                ELSEIF winnings < 0 THEN
                    Msg = "House wins. You lost $10."
                ELSE
                    Msg = "A tie. No money changed hands."
                END IF
            END IF
        CASE "L", CHR$(27)
            GameState = ST_MINE
            SuppressHeldActionKeys
    END SELECT
END SUB

SUB DrawSaloon
    CLS
    LINE (7, 8)-(313, 168), _RGB32(86, 44, 34), BF
    LINE (7, 8)-(313, 168), _RGB32(215, 161, 83), B
    COLOR _RGB32(245, 214, 128), _RGB32(86, 44, 34)
    _PRINTSTRING (82, 18), "FRONTIER SALOON"
    COLOR _RGB32(242, 232, 205), _RGB32(86, 44, 34)
    _PRINTSTRING (22, 43), "D Drink $5  (+1 water)"
    _PRINTSTRING (22, 59), "P High card, $10 a hand"
    _PRINTSTRING (22, 76), "Cash: $" + LTRIM$(STR$(Miner.money))
    LINE (55, 91)-(130, 134), _RGB32(245, 233, 200), BF
    LINE (169, 91)-(244, 134), _RGB32(245, 233, 200), BF
    COLOR _RGB32(61, 40, 30), _RGB32(245, 233, 200)
    _PRINTSTRING (62, 103), "YOU " + LTRIM$(STR$(LastCardPlayer))
    _PRINTSTRING (176, 103), "HOUSE " + LTRIM$(STR$(LastCardHouse))
    COLOR _RGB32(245, 214, 128), _RGB32(86, 44, 34)
    _PRINTSTRING (75, 150), "L Leave the Saloon"
    DrawMessageBar
END SUB

SUB CheckStreetEncounter
    DIM frac AS SINGLE
    DIM risk AS SINGLE
    DIM stolen AS LONG
    DIM stealOre AS INTEGER
    ' Per *horizontal surface step*; risk increases toward the eastern mine.
    IF TownLegacy THEN EXIT SUB
    IF Miner.y > SURFACE_Y THEN EXIT SUB
    IF Miner.x < 0 OR Miner.x > CLAIM_SHAFT_X THEN EXIT SUB
    IF EncounterCooldown > 0 THEN
        EncounterCooldown = EncounterCooldown - 1
        EXIT SUB
    END IF
    frac = Miner.x / CLAIM_SHAFT_X
    risk = .00005 + .00045 * frac * frac
    IF Miner.haul > 0 OR Miner.money > 300 THEN
        IF RND < risk THEN
            stealOre = 0
            IF Miner.haul > 0 THEN stealOre = -1
            IF Miner.haul > 0 AND Miner.money > 300 THEN
                IF RND < .5 THEN stealOre = 0
            END IF
            IF stealOre THEN
                stolen = Miner.haul
                Miner.haul = 0
                CartMode = 0
                Msg = "BANDIT! Stole all your ore: $" + LTRIM$(STR$(stolen))
            ELSE
                stolen = Miner.money
                Miner.money = 0
                Msg = "BANDIT! Stole pocket cash: $" + LTRIM$(STR$(stolen))
            END IF
            EncounterKind = 2
            EncounterCooldown = 24
            GameState = ST_ENCOUNTER
            EXIT SUB
        END IF
    END IF
    IF Miner.money >= 300 THEN
        IF RND < .012 THEN
            EncounterKind = 1
            EncounterCooldown = 24
            GameState = ST_ENCOUNTER
            Msg = "BANKER: Carrying $300+? Make a deposit!"
        END IF
    END IF
END SUB

SUB HandleEncounterInput
    DIM k AS STRING
    k = INKEY$
    IF k = CHR$(13) OR k = " " OR k = CHR$(27) THEN
        GameState = ST_MINE
        EncounterKind = 0
        SuppressHeldActionKeys
    END IF
END SUB

SUB DrawEncounter
    LINE (15, 40)-(305, 158), _RGB32(16, 14, 17), BF
    LINE (15, 40)-(305, 158), _RGB32(214, 158, 82), B
    COLOR _RGB32(242, 207, 122), _RGB32(16, 14, 17)
    IF EncounterKind = 1 THEN
        _PRINTSTRING (83, 53), "FRIENDLY BANKER"
        _PRINTSTRING (34, 89), "Deposit cash at the BANK."
        _PRINTSTRING (34, 106), "Your bank balance is safe."
    ELSE
        _PRINTSTRING (83, 53), "HIGHWAY BANDIT!"
        _PRINTSTRING (34, 89), LEFT$(Msg, 30)
        _PRINTSTRING (34, 106), "Bank deposits remain safe."
    END IF
    _PRINTSTRING (46, 140), "ENTER / SPACE TO CONTINUE"
END SUB

SUB CheckAdjacentHazards
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM t AS INTEGER
    DIM kind AS INTEGER
    IF GameState <> ST_MINE THEN EXIT SUB
    IF Miner.y <= SURFACE_Y THEN
        HazardKind = 0: HazardExposure = 0
        EXIT SUB
    END IF
    x = Miner.x: y = Miner.y
    t = World(x, y)
    IF t = TILE_WATER OR t = TILE_GAS THEN
        IF t = TILE_WATER THEN
            LoseLife "Drowned in water."
        ELSE
            LoseLife "Overcome by gas."
        END IF
        EXIT SUB
    END IF
    kind = 0
    IF x > 0 THEN
        IF World(x - 1, y) = TILE_WATER THEN kind = 1
        IF World(x - 1, y) = TILE_GAS THEN kind = 2
    END IF
    IF x < MW - 1 THEN
        IF World(x + 1, y) = TILE_WATER AND kind < 2 THEN kind = 1
        IF World(x + 1, y) = TILE_GAS THEN kind = 2
    END IF
    IF y > 0 THEN
        IF World(x, y - 1) = TILE_WATER AND kind < 2 THEN kind = 1
        IF World(x, y - 1) = TILE_GAS THEN kind = 2
    END IF
    IF y < MH - 1 THEN
        IF World(x, y + 1) = TILE_WATER AND kind < 2 THEN kind = 1
        IF World(x, y + 1) = TILE_GAS THEN kind = 2
    END IF
    IF kind = 0 THEN
        HazardKind = 0: HazardExposure = 0
        EXIT SUB
    END IF
    IF kind <> HazardKind THEN
        HazardKind = kind: HazardExposure = 0
        IF kind = 2 THEN
            Msg = "GAS LEAK! Move away!"
        ELSE
            Msg = "WATER SEEPAGE! Move away!"
        END IF
    END IF
    HazardExposure = HazardExposure + 1
    IF kind = 2 AND HazardExposure >= 20 THEN LoseLife "Overcome by gas leak."
    IF kind = 1 AND HazardExposure >= 35 THEN LoseLife "Flooded by water pocket."
END SUB

SUB UpdateCart
    IF Miner.wheelbarrow = 0 THEN
        CartMode = 0: WasUnderground = 0
    ELSEIF Miner.y > SURFACE_Y THEN
        CartMode = 0: WasUnderground = -1
    ELSEIF WasUnderground THEN
        CartMode = 0
        IF Miner.haul > 0 THEN CartMode = 2
        WasUnderground = 0
    ELSEIF CartMode = 2 AND Miner.haul <= 0 THEN
        CartMode = 0
    END IF
END SUB

SUB DrawCart
    DIM sx AS INTEGER
    DIM sy AS INTEGER
    DIM cx AS INTEGER
    DIM wobble AS INTEGER
    IF Miner.wheelbarrow = 0 OR Miner.y > SURFACE_Y THEN EXIT SUB
    sx = VIEWX + Miner.x * TILE - CamX
    sy = VIEWY + Miner.y * TILE - CamY
    cx = sx + 22
    IF Facing < 0 THEN cx = sx - 7
    wobble = (Miner.steps MOD 2)
    CIRCLE (cx + 3, sy + 14), 3, _RGB32(40, 42, 51)
    CIRCLE (cx + 3, sy + 14), 1, _RGB32(210, 208, 192)
    LINE (cx - 6, sy + 6)-(cx + 10, sy + 12), _RGB32(120, 126, 128), BF
    LINE (cx - 6, sy + 6)-(cx + 10, sy + 12), _RGB32(241, 211, 143), B
    IF CartMode = 1 THEN
        LINE (cx - 4, sy + 2 - wobble)-(cx + 2, sy + 7), _RGB32(158, 97, 49), BF
        LINE (cx + 3, sy + 3 - wobble)-(cx + 8, sy + 7), _RGB32(83, 133, 161), BF
    ELSEIF CartMode = 2 THEN
        CIRCLE (cx - 2, sy + 4 - wobble), 2, _RGB32(244, 202, 68)
        CIRCLE (cx + 3, sy + 3 - wobble), 2, _RGB32(223, 212, 158)
        CIRCLE (cx + 7, sy + 5 - wobble), 2, _RGB32(243, 190, 59)
    END IF
    LINE (cx, sy + 8)-(sx + 8, sy + 9), _RGB32(175, 115, 69)
END SUB

SUB DrawTownPedestrians
    DIM i AS INTEGER
    DIM px AS INTEGER
    DIM py AS INTEGER
    DIM stepNo AS INTEGER
    DIM worldCol AS INTEGER
    IF TownLegacy THEN EXIT SUB
    py = VIEWY + TILE - CamY
    IF py < VIEWY - TILE OR py > SCRH THEN EXIT SUB
    FOR i = 0 TO 3
        stepNo = (Tick \ (7 + i * 2) + i * 17) MOD 60
        worldCol = 4 + stepNo
        IF i MOD 2 THEN worldCol = 63 - stepNo
        px = worldCol * TILE - CamX
        IF px > -TILE AND px < SCRW THEN
            LINE (px + 4, py + 8)-(px + 11, py + 14), _RGB32(90 + i * 27, 80 + i * 17, 145), BF
            CIRCLE (px + 7, py + 5), 4, _RGB32(214, 164, 115)
            LINE (px + 4, py + 2)-(px + 11, py + 3), _RGB32(70, 45, 30), BF
            PSET (px + 9, py + 5), _RGB32(32, 24, 17)
        END IF
    NEXT i
END SUB

' ================================================================
' TNT and loose pickup loot
' ================================================================

FUNCTION DistSq% (x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER)
    DIM dx AS INTEGER
    DIM dy AS INTEGER

    dx = x1 - x2
    dy = y1 - y2
    DistSq% = dx * dx + dy * dy
END FUNCTION

FUNCTION TntFramesLeft& ()
    IF TntActive = 0 THEN
        TntFramesLeft& = 0
    ELSEIF TntFuseFrames < 0 THEN
        TntFramesLeft& = 0
    ELSE
        TntFramesLeft& = TntFuseFrames
    END IF
END FUNCTION

FUNCTION TntSecondsLeft% ()
    DIM frames AS LONG

    frames = TntFramesLeft&
    TntSecondsLeft% = (frames + 29) \ 30
    IF TntSecondsLeft% < 0 THEN TntSecondsLeft% = 0
END FUNCTION

FUNCTION BlastProtected% (x AS INTEGER, y AS INTEGER)
    IF InBounds%(x, y) = 0 THEN
        BlastProtected% = -1
        EXIT FUNCTION
    END IF

    ' Keep the town/surface travel layer intact.
    IF y <= SURFACE_Y THEN
        BlastProtected% = -1
        EXIT FUNCTION
    END IF

    ' Bedrock is permanent.
    IF World(x, y) = TILE_BEDROCK THEN
        BlastProtected% = -1
        EXIT FUNCTION
    END IF

    BlastProtected% = 0
END FUNCTION

SUB DropTNT
    IF Miner.tnt <= 0 THEN
        Msg = "You have no TNT sticks."
        EXIT SUB
    END IF

    IF TntActive <> 0 THEN
        Msg = "A TNT stick is already burning!"
        EXIT SUB
    END IF

    IF Miner.y <= SURFACE_Y THEN
        Msg = "Use TNT underground, not on the town road."
        EXIT SUB
    END IF

    Miner.tnt = Miner.tnt - 1
    TntActive = -1
    TntX = Miner.x
    TntY = Miner.y
    TntFuseFrames = TNT_COUNTDOWN_FRAMES

    Msg = "TNT dropped! Ten seconds! Run!"
END SUB

SUB UpdateTNT
    ' Ultra-simple fuse update.
    ' No MOD, no countdown string update, no function call from inside
    ' the timer loop.  This isolates the crash that happened about two
    ' seconds after dropping TNT.
    IF TntActive = 0 THEN EXIT SUB

    TntFuseFrames = TntFuseFrames - 1

    IF TntFuseFrames <= 0 THEN
        ExplodeTNT
    END IF
END SUB

SUB ExplodeTNT
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM dx AS INTEGER
    DIM dy AS INTEGER
    DIM dist AS INTEGER
    DIM value AS LONG
    DIM blastedValue AS LONG
    DIM destroyed AS INTEGER
    DIM radiusSq AS INTEGER

    radiusSq = TNT_RADIUS * TNT_RADIUS
    blastedValue = 0
    destroyed = 0

    dx = Miner.x - TntX
    dy = Miner.y - TntY
    dist = dx * dx + dy * dy

    ' Player death check happens before the charge is cleared.
    IF dist <= radiusSq THEN
        TntActive = 0
        TntFuseFrames = 0
        Msg = "The TNT blast caught you!"
        LoseLife "Caught in a TNT blast."
        EXIT SUB
    END IF

    FOR y = TntY - TNT_RADIUS TO TntY + TNT_RADIUS
        FOR x = TntX - TNT_RADIUS TO TntX + TNT_RADIUS
            IF InBounds%(x, y) THEN
                dx = x - TntX
                dy = y - TntY
                dist = dx * dx + dy * dy
                IF dist <= radiusSq THEN
                    IF BlastProtected%(x, y) = 0 THEN
                        value = DepositValue&(World(x, y))
                        IF value > 0 THEN
                            LooseLoot(x, y) = LooseLoot(x, y) + value
                            blastedValue = blastedValue + value
                        END IF

                        IF World(x, y) <> TILE_AIR THEN destroyed = destroyed + 1
                        World(x, y) = TILE_AIR
                    END IF
                END IF
            END IF
        NEXT x
    NEXT y

    TntActive = 0
    TntFuseFrames = 0
    Msg = "BOOM! Cleared " + LTRIM$(STR$(destroyed)) + " tiles. Loose ore $" + LTRIM$(STR$(blastedValue)) + ". Press P to pick up."
END SUB

SUB PickupLooseLoot
    DIM x AS INTEGER
    DIM y AS INTEGER
    DIM value AS LONG
    DIM picked AS LONG
    DIM roomLeft AS LONG

    picked = 0

    FOR y = Miner.y - 1 TO Miner.y + 1
        FOR x = Miner.x - 1 TO Miner.x + 1
            IF InBounds%(x, y) THEN
                value = LooseLoot(x, y)
                IF value > 0 THEN
                    roomLeft = HaulCapacity& - Miner.haul
                    IF roomLeft <= 0 THEN
                        Msg = "Your haul is full. Return to ASSAY and sell."
                        SOUND 120, 2
                        EXIT SUB
                    END IF

                    IF value > roomLeft THEN
                        Miner.haul = Miner.haul + roomLeft
                        LooseLoot(x, y) = value - roomLeft
                        picked = picked + roomLeft
                    ELSE
                        Miner.haul = Miner.haul + value
                        LooseLoot(x, y) = 0
                        picked = picked + value
                    END IF
                END IF
            END IF
        NEXT x
    NEXT y

    IF picked > 0 THEN
        Msg = "Picked up loose ore worth $" + LTRIM$(STR$(picked)) + "."
        BeepOre
    ELSE
        Msg = "No loose ore or gems nearby."
        SOUND 120, 2
    END IF
END SUB

' ================================================================
' Movement, mining, hazards
' ================================================================
FUNCTION NeedsLantern% (y AS INTEGER)
    IF y > SURFACE_Y + 2 THEN
        NeedsLantern% = -1
    ELSE
        NeedsLantern% = 0
    END IF
END FUNCTION

FUNCTION CanEnterDepth% (y AS INTEGER)
    IF NeedsLantern%(y) AND Miner.lantern = 0 THEN
        CanEnterDepth% = 0
    ELSE
        CanEnterDepth% = -1
    END IF
END FUNCTION


SUB TryMove (dx AS INTEGER, dy AS INTEGER)
    DIM nx AS INTEGER
    DIM ny AS INTEGER
    DIM t AS INTEGER

    nx = Miner.x + dx
    ny = Miner.y + dy

    IF InBounds%(nx, ny) = 0 THEN EXIT SUB

    IF CanEnterDepth%(ny) = 0 THEN
        Msg = "Too dark below two levels. Buy a lantern at the Mercantile."
        SOUND 120, 2
        EXIT SUB
    END IF

    t = World(nx, ny)

    IF IsPassable%(nx, ny) THEN
        IF dy = -1 THEN
            IF CanClimbUp%(nx, ny) = 0 THEN
                Msg = "You need a ladder to climb up from here."
                SOUND 120, 2
                EXIT SUB
            END IF
        END IF

        MoveMiner nx, ny
    ELSE
        DigTile nx, ny, dx, dy
    END IF
END SUB

FUNCTION CanClimbUp% (nx AS INTEGER, ny AS INTEGER)
    IF Miner.y <= SURFACE_Y THEN
        CanClimbUp% = -1
    ELSEIF World(Miner.x, Miner.y) = TILE_LADDER THEN
        CanClimbUp% = -1
    ELSEIF World(nx, ny) = TILE_LADDER THEN
        CanClimbUp% = -1
    ELSE
        CanClimbUp% = 0
    END IF
END FUNCTION

SUB MoveMiner (nx AS INTEGER, ny AS INTEGER)
    PrevX = Miner.x
    Miner.x = nx
    Miner.y = ny
    Miner.steps = Miner.steps + 1

    IF Miner.y > Miner.deepest THEN Miner.deepest = Miner.y

    ConsumeProvisions
    IF GameState = ST_MINE AND Miner.y <= SURFACE_Y AND Miner.x <> PrevX THEN CheckStreetEncounter
END SUB

SUB DigTile (tx AS INTEGER, ty AS INTEGER, dx AS INTEGER, dy AS INTEGER)
    DIM t AS INTEGER
    DIM value AS LONG

    IF InBounds%(tx, ty) = 0 THEN EXIT SUB

    t = World(tx, ty)

    SELECT CASE t
        CASE TILE_GRASS, TILE_DIRT1, TILE_DIRT2, TILE_DIRT3
            IF Miner.shovel = 0 THEN
                Msg = "You need a shovel to dig soil."
                SOUND 110, 2
                EXIT SUB
            END IF

            World(tx, ty) = TILE_AIR
            BeepDig
            MoveMiner tx, ty

        CASE TILE_SAND
            IF Miner.shovel = 0 THEN
                Msg = "You need a shovel to move sand."
                SOUND 110, 2
                EXIT SUB
            END IF

            IF RND < .25 THEN
                Msg = "Loose sand collapsed around you!"
                LoseLife "Buried by loose sand."
            ELSE
                World(tx, ty) = TILE_AIR
                Msg = "You dug through loose sand."
                BeepDig
                MoveMiner tx, ty
            END IF

        CASE TILE_ROCK
            IF Miner.pickaxe = 0 THEN
                Msg = "You need a pickaxe for rock."
                SOUND 110, 2
                EXIT SUB
            END IF

            World(tx, ty) = TILE_AIR
            BeepPick
            MoveMiner tx, ty

        CASE TILE_GOLD, TILE_SILVER, TILE_GEM
            IF Miner.pickaxe = 0 THEN
                Msg = "You need a pickaxe to free the deposit."
                SOUND 110, 2
                EXIT SUB
            END IF

            value = DepositValue&(t)
            IF Miner.haul + value > HaulCapacity& THEN
                Msg = "Your haul is full. Return to ASSAY and sell."
                SOUND 120, 2
                EXIT SUB
            END IF

            Miner.haul = Miner.haul + value
            World(tx, ty) = TILE_AIR
            Msg = "HAUL +" + LTRIM$(STR$(value)) + ": collected " + DepositName$(t) + "."
            BeepOre
            MoveMiner tx, ty

        CASE TILE_WATER
            LoseLife "A water pocket burst open. You drowned."

        CASE TILE_GAS
            LoseLife "A gas pocket exploded."

        CASE TILE_SNAKE
            World(tx, ty) = TILE_AIR
            LoseLife "You broke into a rattlesnake den."

        CASE TILE_BEDROCK
            Msg = "Bedrock. You cannot dig farther here."
            SOUND 80, 2

        CASE TILE_LADDER
            MoveMiner tx, ty
    END SELECT
END SUB

FUNCTION DepositValue& (t AS INTEGER)
    SELECT CASE t
        CASE TILE_GOLD
            DepositValue& = 20
        CASE TILE_SILVER
            DepositValue& = 12
        CASE TILE_GEM
            DepositValue& = 45
        CASE ELSE
            DepositValue& = 0
    END SELECT
END FUNCTION

FUNCTION DepositName$ (t AS INTEGER)
    SELECT CASE t
        CASE TILE_GOLD
            DepositName$ = "gold"
        CASE TILE_SILVER
            DepositName$ = "silver"
        CASE TILE_GEM
            DepositName$ = "gems"
        CASE ELSE
            DepositName$ = "ore"
    END SELECT
END FUNCTION

SUB ConsumeProvisions
    IF Miner.y <= SURFACE_Y THEN EXIT SUB

    IF Miner.steps MOD 60 = 0 THEN
        IF Miner.water > 0 THEN
            Miner.water = Miner.water - 1
        ELSE
            LoseLife "You ran out of water underground."
            EXIT SUB
        END IF
    END IF

    IF Miner.steps MOD 100 = 0 THEN
        IF Miner.food > 0 THEN
            Miner.food = Miner.food - 1
        ELSE
            LoseLife "You ran out of food underground."
            EXIT SUB
        END IF
    END IF
END SUB

SUB JumpUp
    DIM nx AS INTEGER
    DIM ny AS INTEGER
    DIM t AS INTEGER

    nx = Miner.x
    ny = Miner.y - 1

    IF InBounds%(nx, ny) = 0 THEN
        Msg = "You cannot jump out of the map."
        SOUND 120, 2
        EXIT SUB
    END IF

    IF CanEnterDepth%(ny) = 0 THEN
        Msg = "Too dark below two levels. Buy a lantern at the Mercantile."
        SOUND 120, 2
        EXIT SUB
    END IF

    IF IsSupported%(Miner.x, Miner.y) = 0 THEN
        Msg = "You need footing below you to jump."
        SOUND 120, 2
        EXIT SUB
    END IF

    t = World(nx, ny)

    ' Jumping is movement only.  It does not dig through soil, rock,
    ' ore, hazards, or bedrock.
    IF IsPassable%(nx, ny) THEN
        MoveMiner nx, ny
        JumpGrace = 18
        Msg = "Jumped up. Move sideways to land on a ledge."
        SOUND 420, 1
    ELSE
        Msg = "You cannot jump through solid ground."
        SOUND 120, 2
    END IF
END SUB

SUB ApplyGravity
    DIM ny AS INTEGER

    IF GameState <> ST_MINE THEN EXIT SUB

    ' A short grace period lets a jump actually function as a hop.
    ' Without this, gravity would immediately pull the miner back down
    ' before the player could move sideways onto a ledge.
    IF JumpGrace > 0 THEN
        JumpGrace = JumpGrace - 1
        EXIT SUB
    END IF

    ' Surface rows, ladders, and solid footing prevent falling.
    IF IsSupported%(Miner.x, Miner.y) THEN EXIT SUB

    ny = Miner.y + 1
    IF InBounds%(Miner.x, ny) = 0 THEN EXIT SUB

    IF CanEnterDepth%(ny) = 0 THEN
        Msg = "Too dark below two levels. Buy a lantern at the Mercantile."
        EXIT SUB
    END IF

    IF World(Miner.x, ny) = TILE_WATER THEN
        LoseLife "You fell into a water pocket."
        EXIT SUB
    ELSEIF World(Miner.x, ny) = TILE_GAS THEN
        LoseLife "You fell into a gas pocket."
        EXIT SUB
    END IF
    IF IsPassable%(Miner.x, ny) THEN
        Miner.y = ny
        Miner.steps = Miner.steps + 1
        IF Miner.y > Miner.deepest THEN Miner.deepest = Miner.y
        Msg = "You fall!"
        SOUND 95, 1
    END IF
END SUB

FUNCTION IsPassable% (x AS INTEGER, y AS INTEGER)
    DIM t AS INTEGER

    IF InBounds%(x, y) = 0 THEN
        IsPassable% = 0
        EXIT FUNCTION
    END IF

    t = World(x, y)

    IF t = TILE_AIR OR t = TILE_LADDER THEN
        IsPassable% = -1
    ELSE
        IsPassable% = 0
    END IF
END FUNCTION

FUNCTION IsSurfaceTravelRow% (y AS INTEGER)
    ' The town/claim travel path must remain walkable even if the player
    ' mines shallow material beneath it.  Without this rule, shallow mining
    ' can destroy the route back to the Mercantile or Assay Office.
    '
    ' Important: only the actual walking/ground rows are stable.
    ' Sky rows above the surface must NOT count as supported, or the
    ' player can jump into the air and float.
    '
    ' SURFACE_Y - 1 is the visible walking row.
    ' SURFACE_Y is the ground/grass row.
    IF y = SURFACE_Y - 1 OR y = SURFACE_Y THEN
        IsSurfaceTravelRow% = -1
    ELSE
        IsSurfaceTravelRow% = 0
    END IF
END FUNCTION

FUNCTION IsSupported% (x AS INTEGER, y AS INTEGER)
    DIM below AS INTEGER

    IF InBounds%(x, y) = 0 THEN
        IsSupported% = -1
        EXIT FUNCTION
    END IF

    ' The surface/town path is treated as stable roadway/packed earth.
    ' This prevents shallow mining from making it impossible to walk
    ' back to the Mercantile or Assay Office.
    IF IsSurfaceTravelRow%(y) THEN
        IsSupported% = -1
        EXIT FUNCTION
    END IF

    ' A ladder supports the miner and prevents falling.
    IF World(x, y) = TILE_LADDER THEN
        IsSupported% = -1
        EXIT FUNCTION
    END IF

    IF y >= MH - 1 THEN
        IsSupported% = -1
        EXIT FUNCTION
    END IF

    below = World(x, y + 1)

    ' Empty air below means no footing.  A ladder below counts as footing
    ' in this tile-based prototype.
    IF below = TILE_AIR OR below = TILE_WATER OR below = TILE_GAS THEN
        IsSupported% = 0
    ELSE
        IsSupported% = -1
    END IF
END FUNCTION

SUB PlaceLadder
    IF World(Miner.x, Miner.y) = TILE_LADDER THEN
        Msg = "There is already a ladder here."
        EXIT SUB
    END IF

    IF Miner.ladders <= 0 THEN
        Msg = "You have no ladders. Buy more at the Mercantile."
        SOUND 120, 2
        EXIT SUB
    END IF

    IF World(Miner.x, Miner.y) <> TILE_AIR THEN
        Msg = "Ladders can only be placed in open tunnel space."
        EXIT SUB
    END IF

    World(Miner.x, Miner.y) = TILE_LADDER
    Miner.ladders = Miner.ladders - 1
    IF Miner.ladders < 0 THEN Miner.ladders = 0
    Msg = "Placed a ladder. " + LTRIM$(STR$(Miner.ladders)) + " left."
    SOUND 500, 2
END SUB

SUB LoseLife (reason AS STRING)
    Miner.lives = Miner.lives - 1
    Miner.haul = 0
    CartMode = 0
    WasUnderground = 0
    HazardKind = 0
    HazardExposure = 0
    EncounterKind = 0
    EncounterCooldown = 0
    SOUND 70, 8

    IF Miner.lives <= 0 THEN
        BeginNameEntry reason + " No lives remain."
    ELSE
        Miner.x = 8
        Miner.y = SURFACE_Y - 1
        Msg = reason + " You lost a life and dropped your haul."
    END IF
END SUB

SUB CheckGameOver
    IF Miner.lives <= 0 THEN
        GameState = ST_GAMEOVER
        EXIT SUB
    END IF

    IF Miner.money <= 0 AND BankBalance <= 0 AND Miner.haul <= 0 AND Miner.food <= 0 AND Miner.water <= 0 AND Miner.shovel = 0 AND Miner.pickaxe = 0 THEN
        BeginNameEntry "You are broke, empty-handed, and own no useful tools. The claim is lost."
    END IF
END SUB

FUNCTION InBounds% (x AS INTEGER, y AS INTEGER)
    IF x >= 0 AND x < MW AND y >= 0 AND y < MH THEN
        InBounds% = -1
    ELSE
        InBounds% = 0
    END IF
END FUNCTION

' ================================================================
' Camera and rendering
' ================================================================

SUB UpdateCamera
    CamX = Miner.x * TILE + TILE \ 2 - VIEWW \ 2
    CamY = Miner.y * TILE + TILE \ 2 - VIEWH \ 2

    IF CamX < 0 THEN CamX = 0
    IF CamY < 0 THEN CamY = 0
    IF CamX > MW * TILE - VIEWW THEN CamX = MW * TILE - VIEWW
    IF CamY > MH * TILE - VIEWH THEN CamY = MH * TILE - VIEWH
END SUB

SUB DrawMine
    CLS
    DrawHUD
    DrawWorld
    DrawSurfaceObjects
    DrawMiner
    DrawCart
    DrawMessageBar
END SUB

SUB DrawTNTCounter
    DIM secs AS INTEGER

    IF TntActive = 0 THEN EXIT SUB

    secs = TntSecondsLeft%

    LINE (236, 24)-(319, 42), _RGB32(60, 0, 0), BF
    LINE (236, 24)-(319, 42), _RGB32(255, 120, 60), B
    COLOR _RGB32(255, 220, 120), _RGB32(60, 0, 0)
    _PRINTSTRING (242, 30), "TNT " + LTRIM$(STR$(secs)) + " SEC"
END SUB

SUB DrawTNTMarker
    DIM sx AS INTEGER
    DIM sy AS INTEGER

    IF TntActive = 0 THEN EXIT SUB
    IF InBounds%(TntX, TntY) = 0 THEN EXIT SUB

    sx = VIEWX + TntX * TILE - CamX
    sy = VIEWY + TntY * TILE - CamY

    IF sx < -TILE OR sx > SCRW OR sy < VIEWY - TILE OR sy > SCRH THEN EXIT SUB

    LINE (sx + 4, sy + 9)-(sx + 11, sy + 13), _RGB32(180, 30, 20), BF
    LINE (sx + 4, sy + 9)-(sx + 11, sy + 13), _RGB32(50, 0, 0), B
    LINE (sx + 8, sy + 8)-(sx + 8, sy + 5), _RGB32(220, 220, 160)
    CIRCLE (sx + 8, sy + 4), 2, _RGB32(255, 180, 40)
END SUB

SUB DrawLooseLoot (sx AS INTEGER, sy AS INTEGER, value AS LONG)
    LINE (sx + 3, sy + 11)-(sx + 13, sy + 14), _RGB32(95, 65, 30), BF
    PSET (sx + 5, sy + 10), _RGB32(255, 220, 40)
    PSET (sx + 7, sy + 9), _RGB32(210, 210, 230)
    PSET (sx + 10, sy + 10), _RGB32(210, 70, 255)
    COLOR _RGB32(255, 255, 120), _RGB32(2, 2, 2)
    _PRINTSTRING (sx + 4, sy + 2), "$"
END SUB

SUB DrawHUD
    LINE (0, 0)-(SCRW - 1, HUDH - 1), _RGB32(0, 0, 0), BF
    LINE (0, HUDH - 1)-(SCRW - 1, HUDH - 1), _RGB32(40, 80, 210)

    COLOR _RGB32(255, 220, 0), _RGB32(0, 0, 0)
    _PRINTSTRING (2, 2), "MONEY $" + LTRIM$(STR$(Miner.money))
    _PRINTSTRING (92, 2), "HAUL $" + LTRIM$(STR$(Miner.haul)) + "/" + LTRIM$(STR$(HaulCapacity&))
    _PRINTSTRING (205, 2), "LIVES " + Stars$(Miner.lives)


    COLOR _RGB32(180, 255, 180), _RGB32(0, 0, 0)
    _PRINTSTRING (2, 13), "FOOD " + LTRIM$(STR$(Miner.food))
    _PRINTSTRING (68, 13), "WATER " + LTRIM$(STR$(Miner.water))
    _PRINTSTRING (148, 13), "LADDERS " + LTRIM$(STR$(Miner.ladders))
    IF Miner.lantern THEN
        _PRINTSTRING (235, 13), "LAMP Y"
    ELSE
        _PRINTSTRING (235, 13), "LAMP N"
    END IF
    _PRINTSTRING (286, 13), "T" + LTRIM$(STR$(Miner.tnt))
END SUB

FUNCTION Stars$ (n AS INTEGER)
    DIM s AS STRING
    DIM i AS INTEGER

    s = ""
    FOR i = 1 TO n
        s = s + "*"
    NEXT i

    Stars$ = s
END FUNCTION

FUNCTION DepthFeet& ()
    IF Miner.y <= SURFACE_Y THEN
        DepthFeet& = 0
    ELSE
        DepthFeet& = (Miner.y - SURFACE_Y) * 10
    END IF
END FUNCTION

FUNCTION BestDepthFeet& ()
    IF Miner.deepest <= SURFACE_Y THEN
        BestDepthFeet& = 0
    ELSE
        BestDepthFeet& = (Miner.deepest - SURFACE_Y) * 10
    END IF
END FUNCTION

SUB DrawWorld
    DIM startX AS INTEGER
    DIM endX AS INTEGER
    DIM startY AS INTEGER
    DIM endY AS INTEGER
    DIM tx AS INTEGER
    DIM ty AS INTEGER
    DIM sx AS INTEGER
    DIM sy AS INTEGER

    startX = CamX \ TILE
    endX = (CamX + VIEWW) \ TILE + 1
    startY = CamY \ TILE
    endY = (CamY + VIEWH) \ TILE + 1

    IF startX < 0 THEN startX = 0
    IF startY < 0 THEN startY = 0
    IF endX > MW - 1 THEN endX = MW - 1
    IF endY > MH - 1 THEN endY = MH - 1

    FOR ty = startY TO endY
        FOR tx = startX TO endX
            sx = VIEWX + tx * TILE - CamX
            sy = VIEWY + ty * TILE - CamY
            DrawTile sx, sy, tx, ty, World(tx, ty)
            IF LooseLoot(tx, ty) > 0 THEN DrawLooseLoot sx, sy, LooseLoot(tx, ty)
        NEXT tx
    NEXT ty
END SUB

SUB DrawTile (sx AS INTEGER, sy AS INTEGER, tx AS INTEGER, ty AS INTEGER, t AS INTEGER)
    SELECT CASE t
        CASE TILE_AIR
            IF ty < SURFACE_Y THEN
                LINE (sx, sy)-(sx + TILE - 1, sy + TILE - 1), _RGB32(40, 95, 220), BF
                DrawSkyBits sx, sy, tx, ty
            ELSE
                LINE (sx, sy)-(sx + TILE - 1, sy + TILE - 1), _RGB32(2, 2, 2), BF
                DrawDarkBits sx, sy, tx, ty
            END IF

        CASE TILE_GRASS
            LINE (sx, sy)-(sx + 15, sy + 15), _RGB32(116, 70, 27), BF
            LINE (sx, sy)-(sx + 15, sy + 3), _RGB32(35, 170, 35), BF
            DrawSpeckles sx, sy, tx, ty, _RGB32(55, 35, 18), _RGB32(105, 70, 38)

        CASE TILE_DIRT1
            DrawSoil sx, sy, tx, ty, _RGB32(116, 70, 27), _RGB32(55, 35, 18)

        CASE TILE_DIRT2
            DrawSoil sx, sy, tx, ty, _RGB32(90, 56, 30), _RGB32(40, 27, 16)

        CASE TILE_DIRT3
            DrawSoil sx, sy, tx, ty, _RGB32(75, 48, 33), _RGB32(32, 23, 18)

        CASE TILE_ROCK
            LINE (sx, sy)-(sx + 15, sy + 15), _RGB32(70, 70, 70), BF
            DrawSpeckles sx, sy, tx, ty, _RGB32(35, 35, 35), _RGB32(130, 130, 130)

        CASE TILE_BEDROCK
            LINE (sx, sy)-(sx + 15, sy + 15), _RGB32(35, 35, 45), BF
            LINE (sx, sy)-(sx + 15, sy), _RGB32(100, 100, 120)
            DrawSpeckles sx, sy, tx, ty, _RGB32(20, 20, 25), _RGB32(90, 90, 105)

        CASE TILE_GOLD
            DrawSoil sx, sy, tx, ty, _RGB32(105, 65, 25), _RGB32(45, 30, 16)
            DrawGoldIcon sx, sy

        CASE TILE_SILVER
            DrawSoil sx, sy, tx, ty, _RGB32(82, 60, 38), _RGB32(38, 28, 18)
            DrawSilverIcon sx, sy

        CASE TILE_GEM
            DrawSoil sx, sy, tx, ty, _RGB32(72, 50, 38), _RGB32(35, 25, 18)
            DrawGemIcon sx, sy, _RGB32(210, 70, 255)

        CASE TILE_WATER
            LINE (sx, sy)-(sx + 15, sy + 15), _RGB32(8, 40, 110), BF
            DrawWaterIcon sx, sy

        CASE TILE_GAS
            LINE (sx, sy)-(sx + 15, sy + 15), _RGB32(10, 22, 10), BF
            DrawGasIcon sx, sy

        CASE TILE_SAND
            LINE (sx, sy)-(sx + 15, sy + 15), _RGB32(190, 155, 70), BF
            DrawSpeckles sx, sy, tx, ty, _RGB32(110, 80, 30), _RGB32(240, 210, 110)

        CASE TILE_SNAKE
            DrawSoil sx, sy, tx, ty, _RGB32(72, 50, 30), _RGB32(30, 22, 16)
            DrawSnakeIcon sx, sy

        CASE TILE_LADDER
            LINE (sx, sy)-(sx + 15, sy + 15), _RGB32(2, 2, 2), BF
            DrawLadderIcon sx, sy
    END SELECT
END SUB

SUB DrawSoil (sx AS INTEGER, sy AS INTEGER, tx AS INTEGER, ty AS INTEGER, baseColor AS _UNSIGNED LONG, darkColor AS _UNSIGNED LONG)
    LINE (sx, sy)-(sx + 15, sy + 15), baseColor, BF
    DrawSpeckles sx, sy, tx, ty, darkColor, _RGB32(105, 70, 38)
END SUB

SUB DrawSpeckles (sx AS INTEGER, sy AS INTEGER, tx AS INTEGER, ty AS INTEGER, c1 AS _UNSIGNED LONG, c2 AS _UNSIGNED LONG)
    DIM i AS INTEGER
    DIM px AS INTEGER
    DIM py AS INTEGER

    FOR i = 0 TO 9
        px = (tx * 7 + ty * 3 + i * 5) MOD 16
        py = (tx * 11 + ty * 13 + i * 7) MOD 16
        IF i MOD 2 = 0 THEN
            PSET (sx + px, sy + py), c1
        ELSE
            PSET (sx + px, sy + py), c2
        END IF
    NEXT i
END SUB

SUB DrawDarkBits (sx AS INTEGER, sy AS INTEGER, tx AS INTEGER, ty AS INTEGER)
    IF ((tx * 5 + ty * 3) MOD 11) = 0 THEN
        PSET (sx + 6, sy + 8), _RGB32(35, 25, 15)
    END IF
END SUB

SUB DrawSkyBits (sx AS INTEGER, sy AS INTEGER, tx AS INTEGER, ty AS INTEGER)
    IF ((tx + ty * 3) MOD 17) = 0 THEN
        LINE (sx + 4, sy + 7)-(sx + 12, sy + 7), _RGB32(220, 235, 255)
        PSET (sx + 7, sy + 6), _RGB32(220, 235, 255)
    END IF
END SUB

SUB DrawGoldIcon (sx AS INTEGER, sy AS INTEGER)
    ' True collectible gold: deliberately chunky and bright.
    LINE (sx + 3, sy + 5)-(sx + 12, sy + 11), _RGB32(70, 45, 0), BF
    CIRCLE (sx + 6, sy + 8), 3, _RGB32(255, 220, 0)
    CIRCLE (sx + 10, sy + 8), 3, _RGB32(255, 220, 0)
    PSET (sx + 7, sy + 6), _RGB32(255, 255, 180)
    PSET (sx + 11, sy + 7), _RGB32(255, 255, 180)
    COLOR _RGB32(0, 0, 0), _RGB32(255, 220, 0)
    _PRINTSTRING (sx + 6, sy + 5), "G"
END SUB

SUB DrawSilverIcon (sx AS INTEGER, sy AS INTEGER)
    ' True collectible silver: bright gray chunks, not dirt speckles.
    LINE (sx + 3, sy + 5)-(sx + 12, sy + 11), _RGB32(55, 55, 60), BF
    CIRCLE (sx + 6, sy + 8), 3, _RGB32(215, 215, 220)
    CIRCLE (sx + 10, sy + 9), 3, _RGB32(170, 170, 185)
    PSET (sx + 7, sy + 6), _RGB32(255, 255, 255)
    COLOR _RGB32(0, 0, 0), _RGB32(215, 215, 220)
    _PRINTSTRING (sx + 6, sy + 5), "S"
END SUB

SUB DrawGemIcon (sx AS INTEGER, sy AS INTEGER, c AS _UNSIGNED LONG)
    LINE (sx + 8, sy + 3)-(sx + 13, sy + 8), c
    LINE (sx + 13, sy + 8)-(sx + 8, sy + 13), c
    LINE (sx + 8, sy + 13)-(sx + 3, sy + 8), c
    LINE (sx + 3, sy + 8)-(sx + 8, sy + 3), c
    PAINT (sx + 8, sy + 8), c, c
    LINE (sx + 5, sy + 7)-(sx + 11, sy + 7), _RGB32(255, 210, 255)
    COLOR _RGB32(255, 255, 255), c
    _PRINTSTRING (sx + 6, sy + 5), "$"
END SUB

SUB DrawWaterIcon (sx AS INTEGER, sy AS INTEGER)
    DIM yoff AS INTEGER
    yoff = (Tick \ 5) MOD 2
    LINE (sx + 1, sy + 7 + yoff)-(sx + 4, sy + 7 + yoff), _RGB32(65, 165, 255)
    LINE (sx + 5, sy + 9 - yoff)-(sx + 8, sy + 9 - yoff), _RGB32(65, 165, 255)
    LINE (sx + 9, sy + 7 + yoff)-(sx + 14, sy + 7 + yoff), _RGB32(65, 165, 255)
    LINE (sx + 0, sy + 12)-(sx + 15, sy + 15), _RGB32(10, 90, 200), BF
END SUB

SUB DrawGasIcon (sx AS INTEGER, sy AS INTEGER)
    DIM yoff AS INTEGER
    yoff = (Tick \ 6) MOD 2
    LINE (sx + 2, sy + 6 + yoff)-(sx + 5, sy + 8 - yoff), _RGB32(80, 240, 60)
    LINE (sx + 5, sy + 8 - yoff)-(sx + 8, sy + 6 + yoff), _RGB32(80, 240, 60)
    LINE (sx + 8, sy + 6 + yoff)-(sx + 12, sy + 8 - yoff), _RGB32(80, 240, 60)
    CIRCLE (sx + 8, sy + 10), 3, _RGB32(20, 120, 20)
END SUB

SUB DrawSnakeIcon (sx AS INTEGER, sy AS INTEGER)
    LINE (sx + 4, sy + 5)-(sx + 9, sy + 5), _RGB32(80, 220, 60)
    LINE (sx + 9, sy + 5)-(sx + 11, sy + 8), _RGB32(80, 220, 60)
    LINE (sx + 11, sy + 8)-(sx + 6, sy + 11), _RGB32(80, 220, 60)
    PSET (sx + 12, sy + 8), _RGB32(255, 60, 60)
END SUB

SUB DrawLadderIcon (sx AS INTEGER, sy AS INTEGER)
    LINE (sx + 4, sy)-(sx + 4, sy + 15), _RGB32(150, 85, 30)
    LINE (sx + 11, sy)-(sx + 11, sy + 15), _RGB32(150, 85, 30)
    LINE (sx + 4, sy + 3)-(sx + 11, sy + 3), _RGB32(210, 140, 60)
    LINE (sx + 4, sy + 8)-(sx + 11, sy + 8), _RGB32(210, 140, 60)
    LINE (sx + 4, sy + 13)-(sx + 11, sy + 13), _RGB32(210, 140, 60)
END SUB

SUB DrawSurfaceObjects
    DIM sx AS INTEGER
    DIM sy AS INTEGER
    IF TownLegacy THEN
        DrawFrontierBuilding 1, 6, "MERC", _RGB32(114, 73, 42)
        DrawFrontierBuilding 13, 6, "ASSAY", _RGB32(113, 114, 125)
        sx = (LEGACY_SHAFT_X - 2) * TILE - CamX
    ELSE
        DrawFrontierBuilding 1, 11, "MERC", _RGB32(127, 80, 48)
        DrawFrontierBuilding 15, 9, "BANK", _RGB32(133, 128, 105)
        DrawFrontierBuilding 27, 11, "ASSAY", _RGB32(108, 118, 128)
        DrawFrontierBuilding 41, 13, "SALOON", _RGB32(142, 78, 61)
        sx = (CLAIM_SHAFT_X - 2) * TILE - CamX
        DrawTownPedestrians
    END IF
    sy = VIEWY - CamY
    IF sx > -60 AND sx < SCRW AND sy > VIEWY - 45 AND sy < SCRH THEN
        LINE (sx, sy + 10)-(sx + 51, sy + 29), _RGB32(100, 56, 25), BF
        LINE (sx, sy + 10)-(sx + 51, sy + 29), _RGB32(227, 178, 91), B
        COLOR _RGB32(255, 250, 208), _RGB32(100, 56, 25)
        _PRINTSTRING (sx + 4, sy + 11), "MINE"
        LINE (sx + 58, sy + 4)-(sx + 72, sy + 34), _RGB32(90, 50, 20), B
        CIRCLE (sx + 65, sy + 12), 5, _RGB32(180, 130, 60)
    END IF
END SUB

SUB DrawFrontierBuilding (col AS INTEGER, widthTiles AS INTEGER, label AS STRING, shade AS _UNSIGNED LONG)
    DIM sx AS INTEGER
    DIM sy AS INTEGER
    DIM ww AS INTEGER
    DIM cx AS INTEGER
    sx = col * TILE - CamX
    sy = VIEWY - CamY
    ww = widthTiles * TILE
    IF sx < -ww OR sx > SCRW THEN EXIT SUB
    IF sy < VIEWY - 48 OR sy > SCRH THEN EXIT SUB
    cx = sx + ww \ 2
    LINE (sx + 2, sy + 7)-(sx + ww - 2, sy + 33), shade, BF
    LINE (sx + 2, sy + 7)-(sx + ww - 2, sy + 33), _RGB32(28, 24, 21), B
    LINE (sx, sy + 3)-(sx + ww, sy + 9), _RGB32(81, 55, 43), BF
    LINE (sx + 14, sy + 22)-(sx + 29, sy + 31), _RGB32(37, 64, 83), BF
    LINE (sx + ww - 29, sy + 22)-(sx + ww - 14, sy + 31), _RGB32(37, 64, 83), BF
    LINE (cx - 6, sy + 20)-(cx + 7, sy + 33), _RGB32(55, 36, 25), BF
    LINE (cx - 38, sy + 9)-(cx + 38, sy + 21), _RGB32(44, 34, 31), BF
    COLOR _RGB32(251, 223, 148), _RGB32(44, 34, 31)
    _PRINTSTRING (cx - LEN(label) * 4, sy + 9), label
END SUB

SUB DrawMiner
    DIM sx AS INTEGER
    DIM sy AS INTEGER

    sx = VIEWX + Miner.x * TILE - CamX
    sy = VIEWY + Miner.y * TILE - CamY

    ' Hat
    LINE (sx + 3, sy + 3)-(sx + 12, sy + 4), _RGB32(80, 45, 20), BF
    LINE (sx + 5, sy + 0)-(sx + 10, sy + 3), _RGB32(110, 65, 25), BF

    ' Face
    LINE (sx + 5, sy + 5)-(sx + 10, sy + 9), _RGB32(230, 170, 100), BF
    PSET (sx + 7, sy + 7), _RGB32(0, 0, 0)

    ' Body
    LINE (sx + 5, sy + 10)-(sx + 10, sy + 14), _RGB32(35, 65, 130), BF
    LINE (sx + 4, sy + 15)-(sx + 6, sy + 15), _RGB32(65, 40, 20)
    LINE (sx + 10, sy + 15)-(sx + 12, sy + 15), _RGB32(65, 40, 20)

    ' Pick / shovel hint if equipped
    IF Miner.pickaxe THEN
        LINE (sx + 11, sy + 8)-(sx + 15, sy + 5), _RGB32(210, 210, 210)
    ELSEIF Miner.shovel THEN
        LINE (sx + 11, sy + 9)-(sx + 15, sy + 13), _RGB32(180, 180, 180)
    END IF
END SUB

SUB DrawMessageBar
    LINE (0, SCRH - MSGH)-(SCRW - 1, SCRH - 1), _RGB32(0, 0, 0), BF
    LINE (0, SCRH - MSGH)-(SCRW - 1, SCRH - MSGH), _RGB32(40, 80, 210)
    COLOR _RGB32(255, 255, 160), _RGB32(0, 0, 0)
    _PRINTSTRING (2, SCRH - 13), LEFT$(Msg, 39)
    IF GameState = ST_MINE OR GameState = ST_ENCOUNTER THEN
        COLOR _RGB32(250, 207, 121), _RGB32(0, 0, 0)
        IF HazardKind = 2 THEN
            _PRINTSTRING (4, SCRH - MSGH - 9), "GAS LEAK - MOVE AWAY!"
        ELSEIF HazardKind = 1 THEN
            _PRINTSTRING (4, SCRH - MSGH - 9), "WATER SEEPAGE - MOVE AWAY!"
        ELSEIF Miner.y <= SURFACE_Y THEN
            IF TownLegacy THEN
                _PRINTSTRING (4, SCRH - MSGH - 9), "M STORE  S ASSAY  EAST MINE"
            ELSE
                _PRINTSTRING (4, SCRH - MSGH - 9), "WEST M STORE B BANK S ASSAY N SALOON"
            END IF
        ELSE
            _PRINTSTRING (4, SCRH - MSGH - 9), "J JUMP L LADDER T TNT P ORE"
        END IF
    END IF
END SUB

' ================================================================
' Store and game over screens
' ================================================================

SUB DrawStore
    CLS

    LINE (0, 0)-(SCRW - 1, SCRH - 1), _RGB32(18, 10, 5), BF
    LINE (4, 4)-(SCRW - 5, SCRH - 5), _RGB32(150, 85, 30), B

    COLOR _RGB32(255, 220, 0), _RGB32(18, 10, 5)
    _PRINTSTRING (78, 10), "THE MERCANTILE"

    COLOR _RGB32(220, 220, 220), _RGB32(18, 10, 5)
    _PRINTSTRING (42, 28), "Outfitters to Miners - Est. 1849"
    COLOR _RGB32(255, 255, 160), _RGB32(18, 10, 5)
    _PRINTSTRING (22, 38), "Tip: go EAST to mine. G/S/$ near ladder."

    COLOR _RGB32(120, 255, 120), _RGB32(18, 10, 5)
    _PRINTSTRING (16, 48), "MONEY: $" + LTRIM$(STR$(Miner.money))

    COLOR _RGB32(255, 255, 255), _RGB32(18, 10, 5)
    _PRINTSTRING (16, 66), "1 Shovel        $10  owned:" + YesNo$(Miner.shovel)
    _PRINTSTRING (16, 78), "2 Pickaxe       $15  owned:" + YesNo$(Miner.pickaxe)
    _PRINTSTRING (16, 90), "3 Wheelbarrow   $30  owned:" + YesNo$(Miner.wheelbarrow)
    _PRINTSTRING (16, 102), "4 Ladder        $20  qty:" + LTRIM$(STR$(Miner.ladders))
    _PRINTSTRING (16, 114), "5 Food ration    $5  qty:" + LTRIM$(STR$(Miner.food))
    _PRINTSTRING (16, 126), "6 Water canteen  $5  qty:" + LTRIM$(STR$(Miner.water))
    _PRINTSTRING (16, 138), "7 Lantern       $10  needed below level 2:" + YesNo$(Miner.lantern)
    _PRINTSTRING (16, 150), "8 TNT stick     $25  qty:" + LTRIM$(STR$(Miner.tnt))

    COLOR _RGB32(255, 220, 0), _RGB32(18, 10, 5)
    _PRINTSTRING (16, 168), "L Leave  V Save  O Load  Q Quit"

    COLOR _RGB32(255, 255, 160), _RGB32(18, 10, 5)
    IF LEN(Msg) > 38 THEN
        _PRINTSTRING (8, 184), LEFT$(Msg, 38)
    ELSE
        _PRINTSTRING (8, 184), Msg
    END IF

    DrawStoreCounterArt
END SUB

SUB DrawStoreCounterArt
    ' Small decorative shopkeeper/counter graphic.
    LINE (224, 58)-(300, 144), _RGB32(70, 36, 16), BF
    LINE (224, 58)-(300, 144), _RGB32(180, 100, 35), B
    LINE (214, 136)-(310, 158), _RGB32(110, 60, 25), BF
    LINE (214, 136)-(310, 158), _RGB32(20, 10, 5), B

    ' Shopkeeper
    LINE (254, 88)-(270, 106), _RGB32(230, 170, 100), BF
    LINE (248, 82)-(276, 87), _RGB32(25, 20, 15), BF
    LINE (253, 74)-(270, 82), _RGB32(20, 20, 20), BF
    LINE (248, 107)-(276, 135), _RGB32(35, 35, 35), BF
    PSET (260, 96), _RGB32(0, 0, 0)
    PSET (266, 96), _RGB32(0, 0, 0)

    ' Supplies
    DrawLadderIcon 232, 108
    DrawGoldIcon 286, 114
    DrawWaterIcon 286, 128
END SUB

FUNCTION YesNo$ (v AS INTEGER)
    IF v THEN
        YesNo$ = "Y"
    ELSE
        YesNo$ = "N"
    END IF
END FUNCTION

SUB DrawAssay
    CLS

    ' Interior wall and floor.
    LINE (0, 0)-(SCRW - 1, SCRH - 1), _RGB32(38, 24, 14), BF
    LINE (0, 130)-(SCRW - 1, SCRH - 1), _RGB32(72, 45, 24), BF

    ' Back wall boards.
    DIM y AS INTEGER
    FOR y = 16 TO 124 STEP 14
        LINE (0, y)-(SCRW - 1, y), _RGB32(70, 42, 20)
    NEXT y

    ' Title sign.
    LINE (58, 8)-(262, 30), _RGB32(95, 55, 22), BF
    LINE (58, 8)-(262, 30), _RGB32(210, 145, 60), B
    COLOR _RGB32(255, 230, 120), _RGB32(95, 55, 22)
    _PRINTSTRING (93, 15), "ASSAY OFFICE"

    ' Counter.
    LINE (22, 112)-(298, 164), _RGB32(105, 62, 28), BF
    LINE (22, 112)-(298, 164), _RGB32(25, 12, 4), B
    LINE (22, 112)-(298, 122), _RGB32(145, 88, 40), BF

    ' Assayer.
    LINE (198, 62)-(226, 95), _RGB32(230, 170, 110), BF
    LINE (192, 54)-(232, 62), _RGB32(35, 30, 25), BF
    LINE (199, 43)-(225, 54), _RGB32(25, 25, 25), BF
    LINE (194, 96)-(232, 124), _RGB32(45, 45, 52), BF
    PSET (207, 77), _RGB32(0, 0, 0)
    PSET (218, 77), _RGB32(0, 0, 0)
    LINE (207, 88)-(220, 88), _RGB32(80, 30, 20)

    ' Balance scale.
    LINE (90, 70)-(90, 112), _RGB32(210, 180, 95)
    LINE (58, 78)-(122, 78), _RGB32(210, 180, 95)
    LINE (72, 78)-(63, 95), _RGB32(210, 180, 95)
    LINE (72, 78)-(81, 95), _RGB32(210, 180, 95)
    LINE (108, 78)-(99, 95), _RGB32(210, 180, 95)
    LINE (108, 78)-(117, 95), _RGB32(210, 180, 95)
    LINE (58, 95)-(86, 100), _RGB32(170, 150, 80), B
    LINE (94, 95)-(122, 100), _RGB32(170, 150, 80), B
    CIRCLE (90, 66), 5, _RGB32(230, 200, 110)

    ' Ore sacks / sample jars.
    LINE (36, 130)-(68, 154), _RGB32(120, 82, 42), BF
    LINE (76, 132)-(108, 154), _RGB32(110, 72, 36), BF
    DrawGoldIcon 42, 132
    DrawSilverIcon 82, 133
    DrawGemIcon 124, 134, _RGB32(210, 70, 255)

    ' Ledger.
    LINE (238, 130)-(282, 152), _RGB32(230, 220, 170), BF
    LINE (238, 130)-(282, 152), _RGB32(60, 35, 15), B
    LINE (244, 137)-(276, 137), _RGB32(80, 60, 35)
    LINE (244, 144)-(276, 144), _RGB32(80, 60, 35)

    ' Transaction panel.
    LINE (10, 168)-(310, 195), _RGB32(10, 10, 10), BF
    LINE (10, 168)-(310, 195), _RGB32(90, 90, 130), B

    COLOR _RGB32(120, 255, 120), _RGB32(10, 10, 10)
    _PRINTSTRING (18, 172), "Money $" + LTRIM$(STR$(Miner.money)) + "   Haul $" + LTRIM$(STR$(Miner.haul))

    COLOR _RGB32(255, 255, 180), _RGB32(10, 10, 10)
    IF SellInput = "" THEN
        _PRINTSTRING (18, 184), "Sell amount: _"
    ELSE
        _PRINTSTRING (18, 184), "Sell amount: $" + SellInput
    END IF

    COLOR _RGB32(220, 220, 220), _RGB32(38, 24, 14)
    _PRINTSTRING (16, 38), "Type amount, ENTER sells"
    _PRINTSTRING (16, 50), "A sells all haul, C clears"
    _PRINTSTRING (16, 62), "L leaves office"

    COLOR _RGB32(255, 255, 160), _RGB32(38, 24, 14)
    IF LEN(Msg) > 39 THEN
        _PRINTSTRING (4, 198 - 10), LEFT$(Msg, 39)
    ELSE
        _PRINTSTRING (4, 198 - 10), Msg
    END IF
END SUB

SUB DrawHighScores
    DIM i AS INTEGER
    DIM rowY AS INTEGER

    CLS

    LINE (0, 0)-(SCRW - 1, SCRH - 1), _RGB32(8, 12, 28), BF
    LINE (12, 8)-(308, 190), _RGB32(38, 24, 14), BF
    LINE (12, 8)-(308, 190), _RGB32(220, 160, 70), B

    COLOR _RGB32(255, 220, 80), _RGB32(38, 24, 14)
    _PRINTSTRING (86, 18), "MINER'S CLAIM"
    COLOR _RGB32(255, 255, 180), _RGB32(38, 24, 14)
    _PRINTSTRING (88, 32), "HIGH SCORES"

    COLOR _RGB32(180, 220, 255), _RGB32(38, 24, 14)
    _PRINTSTRING (30, 50), "RANK NAME         MONEY       DEPTH"

    FOR i = 1 TO MAX_SCORES
        rowY = 62 + (i - 1) * 10

        IF HighScore(i) > 0 THEN
            COLOR _RGB32(235, 235, 235), _RGB32(38, 24, 14)
        ELSE
            COLOR _RGB32(120, 120, 120), _RGB32(38, 24, 14)
        END IF

        _PRINTSTRING (34, rowY), RIGHT$(" " + LTRIM$(STR$(i)), 2)
        _PRINTSTRING (62, rowY), LEFT$(HighName(i) + "            ", 12)
        _PRINTSTRING (162, rowY), "$" + LTRIM$(STR$(HighScore(i)))
        _PRINTSTRING (246, rowY), LTRIM$(STR$(HighDepth(i))) + "FT"
    NEXT i

    COLOR _RGB32(120, 255, 120), _RGB32(38, 24, 14)
    _PRINTSTRING (40, 172), "N New Game   L Load Game   Q Quit"

    COLOR _RGB32(255, 255, 160), _RGB32(38, 24, 14)
    IF LEN(Msg) > 39 THEN
        _PRINTSTRING (6, 192), LEFT$(Msg, 39)
    ELSE
        _PRINTSTRING (6, 192), Msg
    END IF
END SUB

SUB DrawNameEntry
    CLS

    LINE (0, 0)-(SCRW - 1, SCRH - 1), _RGB32(10, 10, 18), BF
    LINE (24, 24)-(296, 176), _RGB32(55, 32, 15), BF
    LINE (24, 24)-(296, 176), _RGB32(220, 160, 70), B

    COLOR _RGB32(255, 220, 80), _RGB32(55, 32, 15)
    _PRINTSTRING (86, 40), "RECORD YOUR CLAIM"

    COLOR _RGB32(255, 255, 190), _RGB32(55, 32, 15)
    IF LEN(LastRunMessage) > 34 THEN
        _PRINTSTRING (34, 62), LEFT$(LastRunMessage, 34)
    ELSE
        _PRINTSTRING (34, 62), LastRunMessage
    END IF

    COLOR _RGB32(180, 255, 180), _RGB32(55, 32, 15)
    _PRINTSTRING (64, 88), "Final money: $" + LTRIM$(STR$(FinalScore))
    _PRINTSTRING (64, 102), "Best depth:  " + LTRIM$(STR$(FinalDepth)) + "FT"

    COLOR _RGB32(220, 220, 255), _RGB32(55, 32, 15)
    _PRINTSTRING (64, 128), "Name: " + NameInput + "_"

    COLOR _RGB32(180, 180, 180), _RGB32(55, 32, 15)
    _PRINTSTRING (52, 152), "Enter saves score. Esc uses MINER."
END SUB

SUB DrawWinner
    CLS

    LINE (0, 0)-(SCRW - 1, SCRH - 1), _RGB32(18, 8, 0), BF
    CIRCLE (160, 82), 74, _RGB32(160, 100, 0)
    CIRCLE (160, 82), 54, _RGB32(220, 160, 20)
    CIRCLE (160, 82), 34, _RGB32(255, 220, 60)

    LINE (34, 28)-(286, 150), _RGB32(80, 45, 10), BF
    LINE (34, 28)-(286, 150), _RGB32(255, 230, 120), B

    COLOR _RGB32(255, 240, 120), _RGB32(80, 45, 10)
    _PRINTSTRING (86, 44), "YOU WON THE CLAIM!"

    COLOR _RGB32(255, 255, 220), _RGB32(80, 45, 10)
    _PRINTSTRING (58, 70), "You reached $" + LTRIM$(STR$(WIN_GOAL))
    _PRINTSTRING (58, 84), "and became a mining baron."

    COLOR _RGB32(180, 255, 180), _RGB32(80, 45, 10)
    _PRINTSTRING (58, 108), "Money: $" + LTRIM$(STR$(Miner.money))
    _PRINTSTRING (58, 122), "Haul:  $" + LTRIM$(STR$(Miner.haul))

    COLOR _RGB32(255, 255, 255), _RGB32(18, 8, 0)
    _PRINTSTRING (64, 174), "Press ENTER to record your name"
END SUB

SUB DrawGameOver
    CLS

    LINE (20, 30)-(300, 160), _RGB32(55, 30, 15), BF
    LINE (20, 30)-(300, 160), _RGB32(180, 100, 40), B

    COLOR _RGB32(255, 80, 80), _RGB32(55, 30, 15)
    _PRINTSTRING (106, 48), "GAME OVER"

    COLOR _RGB32(255, 255, 200), _RGB32(55, 30, 15)
    IF LEN(Msg) > 34 THEN
        _PRINTSTRING (28, 76), LEFT$(Msg, 34)
    ELSE
        _PRINTSTRING (28, 76), Msg
    END IF

    COLOR _RGB32(220, 220, 220), _RGB32(55, 30, 15)
    _PRINTSTRING (64, 104), "Money: $" + LTRIM$(STR$(Miner.money))
    _PRINTSTRING (64, 118), "Deepest: " + LTRIM$(STR$(BestDepthFeet&)) + " ft"

    COLOR _RGB32(120, 255, 120), _RGB32(55, 30, 15)
    _PRINTSTRING (38, 142), "N Name   H Scores   R Restart   Q Quit"
END SUB

' ================================================================
' Sound cues
' ================================================================

SUB BeepBuy
    SOUND 600, 1
    SOUND 800, 1
END SUB

SUB BeepSell
    SOUND 700, 1
    SOUND 900, 1
    SOUND 1100, 1
END SUB

SUB BeepDig
    SOUND 170, 1
END SUB

SUB BeepPick
    SOUND 130, 1
    SOUND 180, 1
END SUB

SUB BeepOre
    SOUND 900, 1
    SOUND 1200, 1
END SUB
