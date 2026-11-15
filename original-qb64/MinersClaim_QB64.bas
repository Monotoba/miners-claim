'
' ================================================================
' Miner's Claim - QB64 Prototype
' 320x200 scrolling mining game prototype
'
' Controls
'   Store:
'     1-8  Buy supplies
'     L    Leave the Mercantile
'     Q    Quit
'
'   Mine:
'     Arrow keys  Move / dig into adjacent tile
'     L           Place ladder on current open tile
'     M           Enter Mercantile when near the store
'     S           Sell current haul when near the store
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

CONST ST_STORE = 0
CONST ST_MINE = 1
CONST ST_GAMEOVER = 2

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
DIM SHARED Miner AS MinerState
DIM SHARED GameState AS INTEGER
DIM SHARED Msg AS STRING
DIM SHARED CamX AS INTEGER
DIM SHARED CamY AS INTEGER
DIM SHARED MoveDelay AS INTEGER
DIM SHARED Tick AS LONG
DIM SHARED ScreenHandle AS LONG

ScreenHandle = _NEWIMAGE(SCRW, SCRH, 32)
SCREEN ScreenHandle
_TITLE "Miner's Claim - QB64 Prototype"
_AUTODISPLAY OFF
RANDOMIZE TIMER

InitGame

DO
    _LIMIT 30
    Tick = Tick + 1

    SELECT CASE GameState
        CASE ST_STORE
            HandleStoreInput
            DrawStore

        CASE ST_MINE
            HandleMineInput
            UpdateCamera
            DrawMine
            CheckGameOver

        CASE ST_GAMEOVER
            DrawGameOver
            HandleGameOverInput
    END SELECT

    _DISPLAY
LOOP

' ================================================================
' Initialization
' ================================================================

SUB InitGame
    DIM x AS INTEGER
    DIM y AS INTEGER

    FOR x = 0 TO MW - 1
        FOR y = 0 TO MH - 1
            World(x, y) = BaseTile(y)
        NEXT y
    NEXT x

    AddOreAndHazards
    CarveStarterClaim

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
    Msg = "Welcome to the Mercantile. Outfit yourself before heading to your claim."
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

    ' A starting ladder from the surface into a small worked opening.
    FOR y = SURFACE_Y - 1 TO SURFACE_Y + 7
        IF InBounds%(10, y) THEN World(10, y) = TILE_LADDER
    NEXT y

    FOR y = SURFACE_Y + 5 TO SURFACE_Y + 7
        FOR x = 7 TO 14
            IF InBounds%(x, y) THEN World(x, y) = TILE_AIR
        NEXT x
    NEXT y

    ' Keep the immediate surface near the store clear.
    FOR x = 0 TO 20
        IF InBounds%(x, SURFACE_Y - 1) THEN World(x, SURFACE_Y - 1) = TILE_AIR
    NEXT x
END SUB

' ================================================================
' Input
' ================================================================

SUB HandleStoreInput
    DIM k AS STRING
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
                Msg = "Bought one ladder."
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
            Msg = "You step out of the Mercantile and head for your claim."

        CASE "Q"
            GameState = ST_GAMEOVER
            Msg = "You abandoned the claim."
    END SELECT

    CheckGameOver
END SUB

SUB HandleMineInput
    DIM k AS STRING
    DIM dx AS INTEGER
    DIM dy AS INTEGER

    k = UCASE$(INKEY$)

    SELECT CASE k
        CASE "L"
            PlaceLadder

        CASE "M"
            IF NearStore% THEN
                GameState = ST_STORE
                Msg = "Back at the Mercantile."
            ELSE
                Msg = "The Mercantile is back near the surface camp."
            END IF

        CASE "S"
            SellHaul

        CASE "Q"
            GameState = ST_GAMEOVER
            Msg = "You abandoned the claim."
    END SELECT

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
        TryMove dx, dy
        MoveDelay = 4
    END IF
END SUB

SUB HandleGameOverInput
    DIM k AS STRING
    k = UCASE$(INKEY$)

    SELECT CASE k
        CASE "R"
            InitGame
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

SUB SellHaul
    IF NearStore% = 0 THEN
        Msg = "You need to return to the Mercantile to sell your haul."
        EXIT SUB
    END IF

    IF Miner.haul <= 0 THEN
        Msg = "You have no ore or gems to sell."
        EXIT SUB
    END IF

    Miner.money = Miner.money + Miner.haul
    Msg = "Sold your haul for $" + LTRIM$(STR$(Miner.haul)) + "."
    Miner.haul = 0
    BeepSell
END SUB

FUNCTION NearStore% ()
    IF Miner.y <= SURFACE_Y AND Miner.x >= 0 AND Miner.x <= 18 THEN
        NearStore% = -1
    ELSE
        NearStore% = 0
    END IF
END FUNCTION

' ================================================================
' Movement, mining, hazards
' ================================================================

SUB TryMove (dx AS INTEGER, dy AS INTEGER)
    DIM nx AS INTEGER
    DIM ny AS INTEGER
    DIM t AS INTEGER

    nx = Miner.x + dx
    ny = Miner.y + dy

    IF InBounds%(nx, ny) = 0 THEN EXIT SUB

    t = World(nx, ny)

    IF t = TILE_AIR OR t = TILE_LADDER THEN
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
    Miner.x = nx
    Miner.y = ny
    Miner.steps = Miner.steps + 1

    IF Miner.y > Miner.deepest THEN Miner.deepest = Miner.y

    ConsumeProvisions
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
                Msg = "Your haul is full. Return to the Mercantile and sell."
                SOUND 120, 2
                EXIT SUB
            END IF

            Miner.haul = Miner.haul + value
            World(tx, ty) = TILE_AIR
            Msg = "Collected $" + LTRIM$(STR$(value)) + " worth of " + DepositName$(t) + "."
            BeepOre
            MoveMiner tx, ty

        CASE TILE_WATER
            World(tx, ty) = TILE_AIR
            LoseLife "A water pocket burst open. You drowned."

        CASE TILE_GAS
            World(tx, ty) = TILE_AIR
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

    IF Miner.steps MOD 12 = 0 THEN
        IF Miner.water > 0 THEN
            Miner.water = Miner.water - 1
        ELSE
            LoseLife "You ran out of water underground."
            EXIT SUB
        END IF
    END IF

    IF Miner.steps MOD 20 = 0 THEN
        IF Miner.food > 0 THEN
            Miner.food = Miner.food - 1
        ELSE
            LoseLife "You ran out of food underground."
            EXIT SUB
        END IF
    END IF
END SUB

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
    Msg = "Placed a ladder."
    SOUND 500, 2
END SUB

SUB LoseLife (reason AS STRING)
    Miner.lives = Miner.lives - 1
    Miner.haul = 0
    SOUND 70, 8

    IF Miner.lives <= 0 THEN
        GameState = ST_GAMEOVER
        Msg = reason + " No lives remain."
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

    IF Miner.money <= 0 AND Miner.haul <= 0 AND Miner.food <= 0 AND Miner.water <= 0 AND Miner.shovel = 0 AND Miner.pickaxe = 0 THEN
        GameState = ST_GAMEOVER
        Msg = "You are broke, empty-handed, and own no useful tools. The claim is lost."
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
    DrawMessageBar
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
    _PRINTSTRING (245, 13), "DEPTH " + LTRIM$(STR$(DepthFeet&)) + "FT"
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
            DrawSpeckles sx, sy, tx, ty, _RGB32(55, 35, 18), _RGB32(180, 120, 60)

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

SUB DrawSoil (sx AS INTEGER, sy AS INTEGER, tx AS INTEGER, ty AS INTEGER, base AS _UNSIGNED LONG, dark AS _UNSIGNED LONG)
    LINE (sx, sy)-(sx + 15, sy + 15), base, BF
    DrawSpeckles sx, sy, tx, ty, dark, _RGB32(145, 95, 45)
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
    CIRCLE (sx + 5, sy + 7), 2, _RGB32(255, 220, 0)
    CIRCLE (sx + 10, sy + 9), 2, _RGB32(255, 220, 0)
    PSET (sx + 8, sy + 5), _RGB32(255, 245, 120)
END SUB

SUB DrawSilverIcon (sx AS INTEGER, sy AS INTEGER)
    CIRCLE (sx + 5, sy + 7), 2, _RGB32(210, 210, 210)
    CIRCLE (sx + 10, sy + 10), 2, _RGB32(170, 170, 180)
    PSET (sx + 8, sy + 5), _RGB32(255, 255, 255)
END SUB

SUB DrawGemIcon (sx AS INTEGER, sy AS INTEGER, c AS _UNSIGNED LONG)
    LINE (sx + 8, sy + 3)-(sx + 13, sy + 8), c
    LINE (sx + 13, sy + 8)-(sx + 8, sy + 13), c
    LINE (sx + 8, sy + 13)-(sx + 3, sy + 8), c
    LINE (sx + 3, sy + 8)-(sx + 8, sy + 3), c
    PAINT (sx + 8, sy + 8), c, c
    LINE (sx + 5, sy + 7)-(sx + 11, sy + 7), _RGB32(255, 210, 255)
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

    ' Mercantile building near x=1..8, y=0..2.
    sx = 1 * TILE - CamX
    sy = VIEWY + 0 * TILE - CamY
    IF sx > -100 AND sx < SCRW AND sy > VIEWY - 40 AND sy < SCRH THEN
        LINE (sx, sy + 3)-(sx + 95, sy + 34), _RGB32(105, 55, 22), BF
        LINE (sx, sy + 3)-(sx + 95, sy + 34), _RGB32(20, 10, 5), B
        LINE (sx - 3, sy + 1)-(sx + 99, sy + 7), _RGB32(135, 70, 28), BF
        LINE (sx + 4, sy + 11)-(sx + 34, sy + 22), _RGB32(20, 10, 5), B
        LINE (sx + 47, sy + 12)-(sx + 61, sy + 34), _RGB32(45, 24, 12), BF
        COLOR _RGB32(255, 210, 80), _RGB32(105, 55, 22)
        _PRINTSTRING (sx + 6, sy + 8), "MERC"
    END IF

    ' Mine claim sign / hoist.
    sx = 26 * TILE - CamX
    sy = VIEWY + 0 * TILE - CamY
    IF sx > -60 AND sx < SCRW THEN
        LINE (sx, sy + 12)-(sx + 50, sy + 29), _RGB32(100, 56, 25), BF
        LINE (sx, sy + 12)-(sx + 50, sy + 29), _RGB32(20, 10, 5), B
        COLOR _RGB32(255, 255, 255), _RGB32(100, 56, 25)
        _PRINTSTRING (sx + 3, sy + 15), "CLAIM"
        LINE (sx + 58, sy + 4)-(sx + 72, sy + 34), _RGB32(90, 50, 20), B
        CIRCLE (sx + 65, sy + 12), 5, _RGB32(180, 130, 60)
    END IF
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

    IF LEN(Msg) > 39 THEN
        _PRINTSTRING (2, SCRH - 13), LEFT$(Msg, 39)
    ELSE
        _PRINTSTRING (2, SCRH - 13), Msg
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

    COLOR _RGB32(120, 255, 120), _RGB32(18, 10, 5)
    _PRINTSTRING (16, 48), "MONEY: $" + LTRIM$(STR$(Miner.money))

    COLOR _RGB32(255, 255, 255), _RGB32(18, 10, 5)
    _PRINTSTRING (16, 66), "1 Shovel        $10  owned:" + YesNo$(Miner.shovel)
    _PRINTSTRING (16, 78), "2 Pickaxe       $15  owned:" + YesNo$(Miner.pickaxe)
    _PRINTSTRING (16, 90), "3 Wheelbarrow   $30  owned:" + YesNo$(Miner.wheelbarrow)
    _PRINTSTRING (16, 102), "4 Ladder        $20  qty:" + LTRIM$(STR$(Miner.ladders))
    _PRINTSTRING (16, 114), "5 Food ration    $5  qty:" + LTRIM$(STR$(Miner.food))
    _PRINTSTRING (16, 126), "6 Water canteen  $5  qty:" + LTRIM$(STR$(Miner.water))
    _PRINTSTRING (16, 138), "7 Lantern       $10  owned:" + YesNo$(Miner.lantern)
    _PRINTSTRING (16, 150), "8 TNT stick     $25  qty:" + LTRIM$(STR$(Miner.tnt))

    COLOR _RGB32(255, 220, 0), _RGB32(18, 10, 5)
    _PRINTSTRING (16, 168), "L Leave store    Q Quit"

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
    _PRINTSTRING (58, 142), "R Restart      Q Quit"
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
