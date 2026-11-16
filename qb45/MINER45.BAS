' MINER'S CLAIM - MICROSOFT QUICKBASIC 4.5 DOS EDITION
' Version 0.1.0 candidate - source port, NOT QB64 or QBasic 1.x
' Copyright (c) 2026 Randall L. Morgan; see project LICENSE.
' Requires QuickBASIC 4.5, 256-color VGA SCREEN 13, DOS.
' Only documented QB 4.5 statements are used.  No QB64 intrinsics.
'
DEFINT A-Z

DECLARE SUB NewGame ()
DECLARE SUB GenerateMine ()
DECLARE SUB PutTile (x%, y%, value%)
DECLARE FUNCTION TileAt% (x%, y%)
DECLARE SUB PutLoot (x%, y%, value%)
DECLARE FUNCTION LootAt% (x%, y%)
DECLARE FUNCTION HexByte$ (value%)
DECLARE FUNCTION FromHex% (c$)
DECLARE SUB ShowFrame ()
DECLARE SUB ShowMine ()
DECLARE SUB DrawCell (x%, y%, value%)
DECLARE SUB DrawBuildings ()
DECLARE SUB DrawMenu ()
DECLARE SUB DrawTextLine (row%, fg%, caption$)
DECLARE SUB InputKey (key$)
DECLARE SUB MineKey (key$)
DECLARE SUB MoveTo (dx%, dy%)
DECLARE SUB StepTo (x%, y%)
DECLARE SUB LoseLife (reason$)
DECLARE SUB CheckProvisions ()
DECLARE SUB CheckExposure ()
DECLARE SUB CheckFall ()
DECLARE SUB CheckRoad ()
DECLARE SUB BuyKey (key$)
DECLARE SUB SellOre (value&)
DECLARE SUB BankKey (key$)
DECLARE SUB SaloonKey (key$)
DECLARE SUB TriggerTNT ()
DECLARE SUB BlastTNT ()
DECLARE SUB PickLoot ()
DECLARE SUB SaveMine ()
DECLARE SUB LoadMine ()
DECLARE FUNCTION CanEnter% (y%)
DECLARE FUNCTION HaulLimit& ()
DECLARE FUNCTION OreValue& (value%)
DECLARE SUB CheckWin ()

CONST MW = 128
CONST MH = 96
CONST SHAFT = 72
CONST SURFACE = 2
CONST TARGET = 1000000
CONST EMPTY = 0
CONST GRASS = 1
CONST DIRT = 2
CONST CLAY = 3
CONST SHALE = 4
CONST ROCK = 5
CONST GOLD = 6
CONST SILVER = 7
CONST GEM = 8
CONST WATER = 9
CONST GAS = 10
CONST SAND = 11
CONST SNAKE = 12
CONST LADDER = 13
CONST BEDROCK = 14
CONST STSTORE = 0
CONST STMINE = 1
CONST STASSAY = 2
CONST STBANK = 3
CONST STSALOON = 4
CONST STENCOUNTER = 5
CONST STTITLE = 6
CONST STEND = 7
CONST SAVEFILE$ = "MC45SAVE.DAT"

' Two 128x96 single-byte maps in far-string storage: about 24 KiB.
' Numerical 128x96 INTEGER arrays would waste about 48 KiB in DGROUP.
DIM SHARED W$(0 TO MH - 1)
DIM SHARED L$(0 TO MH - 1)
DIM SHARED State, Mx, My, CameraX, CameraY, Lives
DIM SHARED Food, WaterCnt, Ladders, Shovel, Pickaxe
DIM SHARED Cart, Lantern, TNT, Haul AS LONG
DIM SHARED Cash AS LONG, Bank AS LONG, Steps AS LONG
DIM SHARED Deepest, LastDir, CartMode, HasBeenDown
DIM SHARED BankEntry$, SaleEntry$, Message$, Alert$
DIM SHARED PauseSteps, EncounterType, CardMe, CardHouse
DIM SHARED BlastOn, BlastX, BlastY, BlastAt!
DIM SHARED HazardType, HazardStart!, LastFall!
DIM SHARED NeedsDraw, StopGame
DIM SHARED Filename$

RANDOMIZE TIMER
SCREEN 13
KEY OFF
COLOR 15
Filename$ = SAVEFILE$
NewGame
State = STTITLE
NeedsDraw = -1
DO WHILE StopGame = 0
    IF State = STMINE THEN
        CheckExposure
        CheckFall
        IF BlastOn <> 0 THEN
            IF TIMER < BlastAt! THEN BlastAt! = TIMER
            IF TIMER - BlastAt! >= 10! THEN BlastTNT
        END IF
    END IF
    IF NeedsDraw THEN
        ShowFrame
        NeedsDraw = 0
    END IF
    key$ = INKEY$
    IF key$ <> "" THEN InputKey key$
LOOP
SCREEN 0
WIDTH 80
END

SUB NewGame
    GenerateMine
    Mx = 8: My = 1
    Cash = 150: Bank = 0: Lives = 5
    Shovel = 0: Pickaxe = 0: Lantern = 0: Cart = 0
    Food = 0: WaterCnt = 0: Ladders = 0: TNT = 0
    Haul = 0: Steps = 0: Deepest = 1
    CameraX = 0: CameraY = 0: LastDir = 1
    HasBeenDown = 0: CartMode = 0
    HazardType = 0: HazardStart! = 0!
    LastFall! = TIMER
    BlastOn = 0: PauseSteps = 0: EncounterType = 0
    BankEntry$ = "": SaleEntry$ = ""
    Message$ = "WELCOME! WEST SHOPS, EAST MINE."
    State = STSTORE: NeedsDraw = -1
END SUB

SUB GenerateMine
    ' One-byte tiles; the second byte map holds blast-loot value.
    FOR yy = 0 TO MH - 1
        W$(yy) = STRING$(MW, CHR$(EMPTY))
        L$(yy) = STRING$(MW, CHR$(0))
        FOR xx = 0 TO MW - 1
            IF yy = SURFACE THEN tile = GRASS ELSE tile = EMPTY
            IF yy > SURFACE THEN tile = DIRT
            IF yy >= 18 THEN tile = CLAY
            IF yy >= 38 THEN tile = SHALE
            IF yy >= 58 THEN tile = ROCK
            IF yy >= MH - 2 THEN tile = BEDROCK
            PutTile xx, yy, tile
        NEXT xx
    NEXT yy
    FOR yy = 4 TO MH - 3
        FOR xx = 1 TO MW - 2
            chance! = RND
            IF chance! < .021 THEN PutTile xx, yy, GOLD
            IF yy >= 12 AND chance! >= .021 AND chance! < .035 THEN PutTile xx, yy, SILVER
            IF yy >= 20 AND chance! >= .035 AND chance! < .042 THEN PutTile xx, yy, GEM
            IF yy >= 12 AND chance! >= .042 AND chance! < .048 THEN PutTile xx, yy, WATER
            IF yy >= 20 AND chance! >= .048 AND chance! < .054 THEN PutTile xx, yy, GAS
            IF yy >= 15 AND chance! >= .054 AND chance! < .061 THEN PutTile xx, yy, SNAKE
            IF yy >= 34 AND chance! >= .061 AND chance! < .074 THEN PutTile xx, yy, SAND
        NEXT xx
    NEXT yy
    ' Fixed protected first trip and shaft.
    FOR yy = 1 TO 9
        PutTile SHAFT, yy, LADDER
    NEXT yy
    FOR yy = 7 TO 9
        FOR xx = SHAFT - 3 TO SHAFT + 4
            PutTile xx, yy, EMPTY
        NEXT xx
    NEXT yy
    PutTile SHAFT - 1, 3, GOLD
    PutTile SHAFT + 1, 3, SILVER
    PutTile SHAFT - 1, 4, GOLD
    PutTile SHAFT + 1, 4, GEM
    PutTile SHAFT - 2, 8, GOLD
    PutTile SHAFT + 2, 8, SILVER
END SUB

FUNCTION TileAt% (x, y)
    IF x < 0 OR x >= MW OR y < 0 OR y >= MH THEN
        TileAt% = BEDROCK
    ELSE
        TileAt% = ASC(MID$(W$(y), x + 1, 1))
    END IF
END FUNCTION

SUB PutTile (x, y, value)
    IF x >= 0 AND x < MW AND y >= 0 AND y < MH THEN
        MID$(W$(y), x + 1, 1) = CHR$(value)
    END IF
END SUB

FUNCTION LootAt% (x, y)
    IF x < 0 OR x >= MW OR y < 0 OR y >= MH THEN
        LootAt% = 0
    ELSE
        LootAt% = ASC(MID$(L$(y), x + 1, 1))
    END IF
END FUNCTION

SUB PutLoot (x, y, value)
    IF x < 0 OR x >= MW OR y < 0 OR y >= MH THEN EXIT SUB
    IF value < 0 THEN value = 0
    IF value > 255 THEN value = 255
    MID$(L$(y), x + 1, 1) = CHR$(value)
END SUB

FUNCTION OreValue& (value)
    OreValue& = 0
    IF value = GOLD THEN OreValue& = 20
    IF value = SILVER THEN OreValue& = 12
    IF value = GEM THEN OreValue& = 45
END FUNCTION

FUNCTION HaulLimit&
    HaulLimit& = 75
    IF Cart <> 0 THEN HaulLimit& = 300
END FUNCTION

FUNCTION CanEnter% (y)
    CanEnter% = -1
    IF y > 4 AND Lantern = 0 THEN
        Message$ = "TOO DARK! BUY A LANTERN."
        CanEnter% = 0
    END IF
END FUNCTION

SUB InputKey (key$)
    IF State = STTITLE THEN
        k$ = UCASE$(key$)
        IF k$ = "N" OR k$ = CHR$(13) THEN NewGame
        IF k$ = "O" OR k$ = "L" THEN LoadMine
        IF k$ = "Q" THEN StopGame = -1
        NeedsDraw = -1
        EXIT SUB
    END IF
    IF State = STEND THEN
        k$ = UCASE$(key$)
        IF k$ = "N" OR k$ = "R" THEN NewGame
        IF k$ = "Q" OR k$ = CHR$(27) THEN StopGame = -1
        NeedsDraw = -1
        EXIT SUB
    END IF
    IF State = STENCOUNTER THEN
        IF key$ = CHR$(13) OR key$ = " " OR key$ = CHR$(27) THEN
            State = STMINE: Message$ = "BACK ON THE ROAD."
            NeedsDraw = -1
        END IF
        EXIT SUB
    END IF
    k$ = UCASE$(key$)
    SELECT CASE State
        CASE STSTORE
            IF k$ >= "1" AND k$ <= "8" AND LEN(k$) = 1 THEN BuyKey k$
            IF k$ = "L" THEN State = STMINE: Message$ = "EAST TO MINE. WEST TO SHOPS."
            IF k$ = "V" THEN SaveMine
            IF k$ = "O" THEN LoadMine
            IF k$ = "Q" THEN State = STEND: Message$ = "CLAIM ABANDONED."
        CASE STASSAY
            IF k$ >= "0" AND k$ <= "9" AND LEN(k$) = 1 THEN
                IF LEN(SaleEntry$) < 7 THEN SaleEntry$ = SaleEntry$ + k$
            END IF
            IF k$ = CHR$(8) AND LEN(SaleEntry$) > 0 THEN SaleEntry$ = LEFT$(SaleEntry$, LEN(SaleEntry$) - 1)
            IF k$ = "C" THEN SaleEntry$ = ""
            IF k$ = "A" THEN SellOre Haul
            IF k$ = CHR$(13) AND LEN(SaleEntry$) > 0 THEN SellOre CLNG(VAL(SaleEntry$))
            IF k$ = "L" OR k$ = CHR$(27) THEN State = STMINE
        CASE STBANK
            BankKey k$
        CASE STSALOON
            SaloonKey k$
        CASE STMINE
            MineKey key$
    END SELECT
    CheckWin
    NeedsDraw = -1
END SUB

SUB MineKey (key$)
    IF LEN(key$) = 2 THEN
        IF ASC(LEFT$(key$, 1)) = 0 THEN
            dx = 0: dy = 0
            scan = ASC(RIGHT$(key$, 1))
            IF scan = 75 THEN dx = -1
            IF scan = 77 THEN dx = 1
            IF scan = 72 THEN dy = -1
            IF scan = 80 THEN dy = 1
            IF dx <> 0 OR dy <> 0 THEN MoveTo dx, dy
        END IF
        EXIT SUB
    END IF
    k$ = UCASE$(key$)
    SELECT CASE k$
        CASE "J"
            IF My > 0 THEN
                IF TileAt%(Mx, My - 1) = EMPTY THEN
                    IF TileAt%(Mx, My + 1) <> EMPTY THEN StepTo Mx, My - 1
                END IF
            END IF
        CASE "L"
            IF Ladders > 0 AND TileAt%(Mx, My) = EMPTY THEN
                PutTile Mx, My, LADDER
                Ladders = Ladders - 1
                Message$ = "LADDER INSTALLED."
            END IF
        CASE "M"
            IF Mx >= 1 AND Mx <= 11 AND My <= 2 THEN
                State = STSTORE
            ELSE
                Message$ = "MERCANTILE FAR WEST."
            END IF
        CASE "S"
            IF Mx >= 27 AND Mx <= 37 AND My <= 2 THEN
                State = STASSAY: SaleEntry$ = "": CartMode = 0
            ELSE
                Message$ = "ASSAY OFFICE WEST OF MINE."
            END IF
        CASE "B"
            IF Mx >= 15 AND Mx <= 23 AND My <= 2 THEN
                State = STBANK: BankEntry$ = ""
            ELSE
                Message$ = "BANK ON WEST MAIN STREET."
            END IF
        CASE "N"
            IF Mx >= 41 AND Mx <= 53 AND My <= 2 THEN
                State = STSALOON
            ELSE
                Message$ = "SALOON BETWEEN TOWN AND MINE."
            END IF
        CASE "T"
            TriggerTNT
        CASE "P"
            PickLoot
        CASE "V"
            SaveMine
        CASE "O"
            LoadMine
        CASE "Q"
            State = STEND: Message$ = "CLAIM ABANDONED."
    END SELECT
END SUB

SUB MoveTo (dx, dy)
    IF dx <> 0 THEN LastDir = dx
    nx = Mx + dx: ny = My + dy
    IF nx < 0 OR nx >= MW OR ny < 0 OR ny >= MH THEN EXIT SUB
    IF CanEnter%(ny) = 0 THEN EXIT SUB
    value = TileAt%(nx, ny)
    IF value = EMPTY OR value = LADDER THEN
        IF dy < 0 AND My > 2 THEN
            IF TileAt%(Mx, My) <> LADDER AND value <> LADDER THEN
                Message$ = "NEED A LADDER TO CLIMB."
                EXIT SUB
            END IF
        END IF
        StepTo nx, ny
        EXIT SUB
    END IF
    SELECT CASE value
        CASE DIRT, CLAY, SHALE, GRASS, SAND
            IF Shovel = 0 THEN Message$ = "BUY A SHOVEL.": EXIT SUB
            IF value = SAND AND RND < .25 THEN
                LoseLife "SAND COLLAPSE!": EXIT SUB
            END IF
            PutTile nx, ny, EMPTY
            StepTo nx, ny
        CASE ROCK
            IF Pickaxe = 0 THEN Message$ = "BUY A PICKAXE.": EXIT SUB
            PutTile nx, ny, EMPTY
            StepTo nx, ny
        CASE GOLD, SILVER, GEM
            IF Pickaxe = 0 THEN Message$ = "BUY A PICKAXE FOR ORE.": EXIT SUB
            amount& = OreValue&(value)
            IF Haul + amount& > HaulLimit& THEN
                Message$ = "FULL HAUL. RETURN TO ASSAY.": EXIT SUB
            END IF
            Haul = Haul + amount&
            PutTile nx, ny, EMPTY
            Message$ = "ORE COLLECTED: $" + LTRIM$(STR$(amount&))
            StepTo nx, ny
        CASE WATER, GAS, SNAKE
            IF value = SNAKE THEN PutTile nx, ny, EMPTY
            LoseLife "MINING HAZARD! LOST A LIFE."
        CASE BEDROCK
            Message$ = "BEDROCK CANNOT BE DUG."
    END SELECT
END SUB

SUB StepTo (x, y)
    oldx = Mx
    Mx = x: My = y
    Steps = Steps + 1
    IF My > Deepest THEN Deepest = My
    IF My > SURFACE THEN
        HasBeenDown = -1: CartMode = 0
        CheckProvisions
    ELSE
        IF HasBeenDown <> 0 AND Haul > 0 AND Cart <> 0 THEN CartMode = 2
    END IF
    IF State = STMINE AND My <= SURFACE AND Mx <> oldx THEN CheckRoad
END SUB

SUB CheckProvisions
    IF My <= SURFACE THEN EXIT SUB
    IF Steps MOD 60 = 0 THEN
        IF WaterCnt > 0 THEN WaterCnt = WaterCnt - 1 ELSE LoseLife "RAN OUT OF WATER!"
    END IF
    IF State <> STMINE THEN EXIT SUB
    IF Steps MOD 100 = 0 THEN
        IF Food > 0 THEN Food = Food - 1 ELSE LoseLife "RAN OUT OF FOOD!"
    END IF
END SUB

SUB LoseLife (reason$)
    Lives = Lives - 1
    Haul = 0: CartMode = 0
    HazardType = 0: BlastOn = 0
    Message$ = reason$
    Mx = 8: My = 1
    IF Lives <= 0 THEN State = STEND
    NeedsDraw = -1
END SUB

SUB CheckFall
    IF State <> STMINE OR My <= SURFACE THEN EXIT SUB
    IF TIMER < LastFall! THEN LastFall! = TIMER
    IF TIMER - LastFall! < .22! THEN EXIT SUB
    LastFall! = TIMER
    below = TileAt%(Mx, My + 1)
    IF TileAt%(Mx, My) = LADDER THEN EXIT SUB
    IF below = EMPTY THEN
        IF CanEnter%(My + 1) THEN
            My = My + 1
            Steps = Steps + 1
            HasBeenDown = -1
            CartMode = 0
            IF My > Deepest THEN Deepest = My
            Message$ = "YOU FALL."
            NeedsDraw = -1
        END IF
    ELSEIF below = WATER OR below = GAS THEN
        LoseLife "FELL INTO WATER OR GAS!"
    END IF
END SUB

SUB CheckExposure
    IF State <> STMINE OR My <= SURFACE THEN
        HazardType = 0
        EXIT SUB
    END IF
    hazard = 0
    FOR d = 1 TO 4
        xx = Mx: yy = My
        SELECT CASE d
            CASE 1: xx = xx - 1
            CASE 2: xx = xx + 1
            CASE 3: yy = yy - 1
            CASE 4: yy = yy + 1
        END SELECT
        value = TileAt%(xx, yy)
        IF value = WATER AND hazard < 1 THEN hazard = 1
        IF value = GAS THEN hazard = 2
    NEXT d
    IF hazard = 0 THEN HazardType = 0: EXIT SUB
    IF HazardType <> hazard THEN
        HazardType = hazard
        HazardStart! = TIMER
        IF hazard = 2 THEN Alert$ = "GAS LEAK! MOVE!" ELSE Alert$ = "WATER SEEP! MOVE!"
        NeedsDraw = -1
    END IF
    IF TIMER < HazardStart! THEN HazardStart! = TIMER
    elapsed! = TIMER - HazardStart!
    IF hazard = 2 AND elapsed! >= .67! THEN LoseLife "OVERCOME BY GAS!"
    IF hazard = 1 AND elapsed! >= 1.17! THEN LoseLife "OVERCOME BY WATER!"
END SUB

SUB CheckRoad
    IF Mx < 0 OR Mx > SHAFT THEN EXIT SUB
    IF PauseSteps > 0 THEN PauseSteps = PauseSteps - 1: EXIT SUB
    frac! = Mx / SHAFT
    risk! = .00005! + .00045! * frac! * frac!
    IF Haul > 0 OR Cash > 300 THEN
        IF RND < risk! THEN
            takeOre = 0
            IF Haul > 0 THEN takeOre = -1
            IF Haul > 0 AND Cash > 300 THEN
                IF RND < .5! THEN takeOre = 0
            END IF
            IF takeOre THEN
                Message$ = "BANDIT STOLE ORE $" + LTRIM$(STR$(Haul))
                Haul = 0: CartMode = 0
            ELSE
                Message$ = "BANDIT STOLE CASH $" + LTRIM$(STR$(Cash))
                Cash = 0
            END IF
            EncounterType = 2: PauseSteps = 24
            State = STENCOUNTER: EXIT SUB
        END IF
    END IF
    IF Cash >= 300 THEN
        IF RND < .012! THEN
            EncounterType = 1: PauseSteps = 24
            State = STENCOUNTER
            Message$ = "BANKER: DEPOSIT CASH TO STAY SAFE."
        END IF
    END IF
END SUB

SUB BuyKey (key$)
    price = 0: item$ = ""
    SELECT CASE key$
        CASE "1": price = 10: item$ = "SHOVEL"
            IF Shovel THEN price = 0
        CASE "2": price = 15: item$ = "PICKAXE"
            IF Pickaxe THEN price = 0
        CASE "3": price = 30: item$ = "WHEELBARROW"
            IF Cart THEN price = 0
        CASE "4": price = 20: item$ = "LADDER"
        CASE "5": price = 5: item$ = "FOOD"
        CASE "6": price = 5: item$ = "WATER"
        CASE "7": price = 10: item$ = "LANTERN"
            IF Lantern THEN price = 0
        CASE "8": price = 25: item$ = "TNT"
    END SELECT
    IF price = 0 THEN Message$ = "ALREADY OWNED.": EXIT SUB
    IF Cash < price THEN Message$ = "INSUFFICIENT CASH.": EXIT SUB
    Cash = Cash - price
    SELECT CASE key$
        CASE "1": Shovel = -1
        CASE "2": Pickaxe = -1
        CASE "3": Cart = -1
        CASE "4": Ladders = Ladders + 1
        CASE "5": Food = Food + 1
        CASE "6": WaterCnt = WaterCnt + 1
        CASE "7": Lantern = -1
        CASE "8": TNT = TNT + 1
    END SELECT
    IF Cart THEN CartMode = 1
    Message$ = "BOUGHT " + item$
END SUB

SUB SellOre (value&)
    IF value& <= 0 THEN Message$ = "ENTER A POSITIVE AMOUNT.": EXIT SUB
    IF value& > Haul THEN value& = Haul
    IF value& <= 0 THEN Message$ = "NO ORE TO SELL.": EXIT SUB
    Cash = Cash + value&
    Haul = Haul - value&
    SaleEntry$ = ""
    CartMode = 0
    Message$ = "SOLD ORE FOR $" + LTRIM$(STR$(value&))
END SUB

SUB BankKey (key$)
    IF key$ >= "0" AND key$ <= "9" AND LEN(key$) = 1 THEN
        IF LEN(BankEntry$) < 7 THEN BankEntry$ = BankEntry$ + key$
        EXIT SUB
    END IF
    IF key$ = CHR$(8) AND LEN(BankEntry$) > 0 THEN
        BankEntry$ = LEFT$(BankEntry$, LEN(BankEntry$) - 1): EXIT SUB
    END IF
    IF key$ = "C" THEN BankEntry$ = "": EXIT SUB
    IF key$ = "L" OR key$ = CHR$(27) THEN State = STMINE: EXIT SUB
    IF key$ <> "D" AND key$ <> "W" THEN EXIT SUB
    amount& = CLNG(VAL(BankEntry$))
    BankEntry$ = ""
    IF amount& <= 0 THEN Message$ = "ENTER A POSITIVE AMOUNT.": EXIT SUB
    IF key$ = "D" THEN
        IF amount& > Cash THEN Message$ = "NOT ENOUGH CASH.": EXIT SUB
        Cash = Cash - amount&: Bank = Bank + amount&
        Message$ = "DEPOSITED $" + LTRIM$(STR$(amount&))
    ELSE
        IF amount& > Bank THEN Message$ = "NOT ENOUGH IN BANK.": EXIT SUB
        Bank = Bank - amount&: Cash = Cash + amount&
        Message$ = "WITHDREW $" + LTRIM$(STR$(amount&))
    END IF
END SUB

SUB SaloonKey (key$)
    SELECT CASE key$
        CASE "L", CHR$(27): State = STMINE
        CASE "D"
            IF Cash < 5 THEN
                Message$ = "DRINK COSTS $5."
            ELSE
                Cash = Cash - 5: WaterCnt = WaterCnt + 1
                Message$ = "DRINK $5: WATER +1"
            END IF
        CASE "P"
            IF Cash < 10 THEN
                Message$ = "NEED $10 FOR HIGH CARD."
            ELSE
                CardMe = 1 + INT(RND * 13)
                CardHouse = 1 + INT(RND * 13)
                IF CardMe > CardHouse THEN
                    Cash = Cash + 10: Message$ = "YOU WON $10!"
                ELSEIF CardMe < CardHouse THEN
                    Cash = Cash - 10: Message$ = "YOU LOST $10."
                ELSE
                    Message$ = "TIE: NO MONEY CHANGED."
                END IF
            END IF
    END SELECT
END SUB

SUB CheckWin
    IF State = STEND THEN EXIT SUB
    IF Cash + Bank >= TARGET THEN
        State = STEND
        Message$ = "YOU WON THE CLAIM: $1 MILLION!"
    END IF
END SUB

SUB TriggerTNT
    IF TNT <= 0 OR My <= SURFACE OR BlastOn THEN
        Message$ = "TNT NOT AVAILABLE HERE.": EXIT SUB
    END IF
    TNT = TNT - 1
    BlastX = Mx: BlastY = My
    BlastAt! = TIMER: BlastOn = -1
    Message$ = "TNT FUSE! MOVE 5 TILES AWAY."
END SUB

SUB BlastTNT
    BlastOn = 0
    dx = Mx - BlastX: dy = My - BlastY
    IF dx * dx + dy * dy <= 25 THEN
        LoseLife "CAUGHT IN TNT BLAST!"
        EXIT SUB
    END IF
    FOR yy = BlastY - 5 TO BlastY + 5
        FOR xx = BlastX - 5 TO BlastX + 5
            dx = xx - BlastX: dy = yy - BlastY
            IF dx * dx + dy * dy <= 25 THEN
                IF xx >= 0 AND xx < MW AND yy > SURFACE AND yy < MH - 2 THEN
                    value = TileAt%(xx, yy)
                    reward& = OreValue&(value)
                    IF reward& > 0 THEN PutLoot xx, yy, LootAt%(xx, yy) + reward&
                    PutTile xx, yy, EMPTY
                END IF
            END IF
        NEXT xx
    NEXT yy
    Message$ = "BOOM! PRESS P TO COLLECT ORE."
    NeedsDraw = -1
END SUB

SUB PickLoot
    total& = 0
    FOR yy = My - 1 TO My + 1
        FOR xx = Mx - 1 TO Mx + 1
            value = LootAt%(xx, yy)
            room& = HaulLimit& - Haul
            IF room& > 0 AND value > 0 THEN
                take& = value
                IF take& > room& THEN take& = room&
                Haul = Haul + take&
                total& = total& + take&
                PutLoot xx, yy, value - take&
            END IF
        NEXT xx
    NEXT yy
    Message$ = "COLLECTED $" + LTRIM$(STR$(total&))
END SUB

FUNCTION HexByte$ (value)
    digits$ = "0123456789ABCDEF"
    HexByte$ = MID$(digits$, value \ 16 + 1, 1) + MID$(digits$, (value MOD 16) + 1, 1)
END FUNCTION

FUNCTION FromHex% (c$)
    FromHex% = INSTR("0123456789ABCDEF", UCASE$(c$)) - 1
END FUNCTION

SUB SaveMine
    ON ERROR GOTO SaveError
    OPEN Filename$ FOR OUTPUT AS #1
    PRINT #1, "MC45V1"
    WRITE #1, Mx, My, Lives, Cash, Bank, Food, WaterCnt
    WRITE #1, Ladders, Shovel, Pickaxe, Cart, Lantern, TNT
    WRITE #1, Haul, Steps, Deepest
    FOR yy = 0 TO MH - 1
        hex$ = ""
        FOR xx = 0 TO MW - 1
            value = TileAt%(xx, yy)
            hex$ = hex$ + MID$("0123456789ABCDEF", value + 1, 1)
        NEXT xx
        PRINT #1, hex$
    NEXT yy
    FOR yy = 0 TO MH - 1
        hex$ = ""
        FOR xx = 0 TO MW - 1
            hex$ = hex$ + HexByte$(LootAt%(xx, yy))
        NEXT xx
        PRINT #1, hex$
    NEXT yy
    CLOSE #1
    ON ERROR GOTO 0
    Message$ = "SAVED TO MC45SAVE.DAT."
    EXIT SUB
SaveError:
    RESUME SaveFailed
SaveFailed:
    ON ERROR GOTO 0
    CLOSE
    Message$ = "DISK WRITE ERROR: SAVE FAILED."
END SUB

SUB LoadMine
    ' This DOS-native format deliberately does not overwrite QB64 V1/V2/V3.
    ' Validate the header and row lengths before accepting map contents.
    ON ERROR GOTO LoadError
    OPEN Filename$ FOR INPUT AS #1
    LINE INPUT #1, magic$
    IF magic$ <> "MC45V1" THEN
        CLOSE #1
        Message$ = "WRONG SAVE FORMAT.": EXIT SUB
    END IF
    INPUT #1, Mx, My, Lives, Cash, Bank, Food, WaterCnt
    INPUT #1, Ladders, Shovel, Pickaxe, Cart, Lantern, TNT
    INPUT #1, Haul, Steps, Deepest
    FOR yy = 0 TO MH - 1
        LINE INPUT #1, hex$
        IF LEN(hex$) <> MW THEN CLOSE #1: Message$ = "BAD MAP RECORD.": EXIT SUB
        FOR xx = 0 TO MW - 1
            value = FromHex%(MID$(hex$, xx + 1, 1))
            IF value < 0 OR value > BEDROCK THEN
                CLOSE #1: Message$ = "BAD MAP TILE.": EXIT SUB
            END IF
            PutTile xx, yy, value
        NEXT xx
    NEXT yy
    FOR yy = 0 TO MH - 1
        LINE INPUT #1, hex$
        IF LEN(hex$) <> MW * 2 THEN CLOSE #1: Message$ = "BAD LOOT ROW.": EXIT SUB
        FOR xx = 0 TO MW - 1
            hi = FromHex%(MID$(hex$, xx * 2 + 1, 1))
            lo = FromHex%(MID$(hex$, xx * 2 + 2, 1))
            IF hi < 0 OR lo < 0 THEN CLOSE #1: Message$ = "BAD LOOT VALUE.": EXIT SUB
            PutLoot xx, yy, hi * 16 + lo
        NEXT xx
    NEXT yy
    CLOSE #1
    IF Mx < 0 OR Mx >= MW OR My < 0 OR My >= MH THEN
        NewGame
        Message$ = "BAD SAVE COORDINATES.": EXIT SUB
    END IF
    IF Bank < 0 OR Cash < 0 OR Lives < 1 THEN
        NewGame
        Message$ = "BAD SAVE BALANCES.": EXIT SUB
    END IF
    State = STMINE
    BlastOn = 0: HazardType = 0: PauseSteps = 0
    Message$ = "SAVE LOADED."
    NeedsDraw = -1
    ON ERROR GOTO 0
    EXIT SUB
LoadError:
    RESUME LoadFailed
LoadFailed:
    ON ERROR GOTO 0
    CLOSE
    Message$ = "SAVE FILE MISSING OR DAMAGED."
    NeedsDraw = -1
END SUB

SUB DrawTextLine (row, colour, caption$)
    COLOR colour
    LOCATE row, 1
    LINE (0, (row - 1) * 8)-(319, row * 8 - 1), 0, BF
    PRINT LEFT$(caption$ + SPACE$(39), 39);
END SUB

SUB ShowFrame
    SELECT CASE State
        CASE STMINE, STENCOUNTER
            ShowMine
            IF State = STENCOUNTER THEN
                LINE (35, 65)-(286, 142), 0, BF
                LINE (35, 65)-(286, 142), 14, B
                COLOR 14: LOCATE 10, 8
                IF EncounterType = 1 THEN
                    PRINT "FRIENDLY BANKER";
                ELSE
                    PRINT "HIGHWAY BANDIT!";
                END IF
                COLOR 15: LOCATE 12, 6: PRINT LEFT$(Message$, 29);
                LOCATE 15, 7: PRINT "ENTER / SPACE CONTINUE";
            END IF
        CASE ELSE
            DrawMenu
    END SELECT
END SUB

SUB ShowMine
    CLS
    CameraX = Mx - 20: CameraY = My - 10
    IF CameraX < 0 THEN CameraX = 0
    IF CameraX > MW - 40 THEN CameraX = MW - 40
    IF CameraY < 0 THEN CameraY = 0
    IF CameraY > MH - 21 THEN CameraY = MH - 21
    FOR sy = 0 TO 20
        wy = sy + CameraY
        FOR sx = 0 TO 39
            wx = sx + CameraX
            tile = TileAt%(wx, wy)
            DrawCell sx, sy + 2, tile
            IF LootAt%(wx, wy) > 0 THEN
                LINE (sx * 8 + 2, (sy + 2) * 8 + 2)-(sx * 8 + 5, (sy + 2) * 8 + 5), 14, BF
            END IF
        NEXT sx
    NEXT sy
    DrawBuildings
    px = (Mx - CameraX) * 8: py = (My - CameraY + 2) * 8
    LINE (px + 2, py + 1)-(px + 5, py + 3), 14, BF
    LINE (px + 2, py + 4)-(px + 5, py + 7), 9, BF
    IF Cart <> 0 AND My <= SURFACE THEN
        ' Fixed-size cart graphic; supply parcels outbound, ore inbound.
        cx = px - 12
        IF LastDir < 0 THEN cx = px + 8
        LINE (cx, py + 3)-(cx + 10, py + 5), 6, BF
        CIRCLE (cx + 2, py + 7), 1, 7
        CIRCLE (cx + 8, py + 7), 1, 7
        IF CartMode = 1 THEN LINE (cx + 3, py + 1)-(cx + 6, py + 3), 14, BF
        IF CartMode = 2 THEN LINE (cx + 3, py + 1)-(cx + 6, py + 3), 10, BF
    END IF
    DrawTextLine 1, 14, "C$" + LTRIM$(STR$(Cash)) + " B$" + LTRIM$(STR$(Bank)) + " H$" + LTRIM$(STR$(Haul)) + "/" + LTRIM$(STR$(HaulLimit&))
    DrawTextLine 2, 11, "LIVES" + STR$(Lives) + " F" + STR$(Food) + " W" + STR$(WaterCnt) + " LAD" + STR$(Ladders) + " TNT" + STR$(TNT)
    IF My <= SURFACE THEN
        label$ = "WEST M SHOP B BANK S ASSAY N SALOON"
    ELSE
        label$ = "ARROWS DIG  L LAD J JUMP T TNT P PICK"
    END IF
    IF HazardType <> 0 THEN label$ = Alert$
    DrawTextLine 24, 10, label$
    DrawTextLine 25, 14, Message$
END SUB

SUB DrawCell (x, y, value)
    px = x * 8: py = y * 8
    SELECT CASE value
        CASE EMPTY: colour = 1
        CASE GRASS: colour = 2
        CASE DIRT: colour = 6
        CASE CLAY: colour = 4
        CASE SHALE: colour = 8
        CASE ROCK: colour = 7
        CASE GOLD: colour = 6
        CASE SILVER: colour = 7
        CASE GEM: colour = 5
        CASE WATER: colour = 9
        CASE GAS: colour = 2
        CASE SAND: colour = 14
        CASE SNAKE: colour = 4
        CASE LADDER: colour = 0
        CASE ELSE: colour = 8
    END SELECT
    LINE (px, py)-(px + 7, py + 7), colour, BF
    SELECT CASE value
        CASE GOLD
            LINE (px + 2, py + 2)-(px + 5, py + 5), 14, BF
        CASE SILVER
            LINE (px + 2, py + 2)-(px + 5, py + 5), 15, BF
        CASE GEM
            LINE (px + 3, py + 1)-(px + 4, py + 6), 13, BF
        CASE WATER
            LINE (px + 1, py + 4)-(px + 6, py + 4), 11
        CASE GAS
            CIRCLE (px + 4, py + 4), 2, 10
        CASE SNAKE
            LINE (px + 1, py + 6)-(px + 6, py + 2), 10
        CASE LADDER
            LINE (px + 1, py)-(px + 1, py + 7), 6
            LINE (px + 6, py)-(px + 6, py + 7), 6
            LINE (px + 1, py + 3)-(px + 6, py + 3), 14
    END SELECT
END SUB

SUB DrawBuildings
    IF CameraY <> 0 THEN EXIT SUB
    FOR n = 1 TO 4
        SELECT CASE n
            CASE 1: leftx = 1: widthx = 11: title$ = "MERC"
            CASE 2: leftx = 15: widthx = 9: title$ = "BANK"
            CASE 3: leftx = 27: widthx = 11: title$ = "ASSAY"
            CASE 4: leftx = 41: widthx = 13: title$ = "SALOON"
        END SELECT
        x1 = (leftx - CameraX) * 8
        x2 = x1 + widthx * 8 - 1
        IF x2 >= 0 AND x1 <= 319 THEN
            y1 = 16 - CameraY * 8
            LINE (x1, y1)-(x2, y1 + 15), 6, BF
            LINE (x1, y1)-(x2, y1 + 15), 14, B
            tx = leftx + 1 - CameraX
            IF tx >= 0 AND tx + LEN(title$) <= 40 THEN
                COLOR 15: LOCATE 3 - CameraY, tx + 1
                PRINT title$;
            END IF
        END IF
    NEXT n
END SUB

SUB DrawMenu
    CLS
    COLOR 14: LOCATE 2, 11: PRINT "MINER'S CLAIM QB 4.5";
    SELECT CASE State
        CASE STTITLE
            COLOR 11: LOCATE 6, 12: PRINT "DOS / VGA EDITION";
            LOCATE 11, 8: PRINT "N NEW GAME   O LOAD SAVE";
            LOCATE 14, 8: PRINT "Q QUIT";
        CASE STSTORE
            COLOR 11: LOCATE 4, 13: PRINT "MERCANTILE";
            LOCATE 7, 4: PRINT "1 SHOVEL $10    2 PICKAXE $15";
            LOCATE 9, 4: PRINT "3 WHEELBARROW $30  4 LADDER $20";
            LOCATE 11, 4: PRINT "5 FOOD $5       6 WATER $5";
            LOCATE 13, 4: PRINT "7 LANTERN $10   8 TNT $25";
            LOCATE 16, 4: PRINT "CASH $"; Cash;
            LOCATE 19, 4: PRINT "L LEAVE, V SAVE, O LOAD, Q QUIT";
        CASE STASSAY
            COLOR 11: LOCATE 5, 13: PRINT "ASSAY OFFICE";
            LOCATE 9, 4: PRINT "POCKET CASH $"; Cash;
            LOCATE 11, 4: PRINT "UNSOLD HAUL $"; Haul;
            LOCATE 14, 4: PRINT "SALE AMOUNT $"; SaleEntry$; "_";
            LOCATE 18, 4: PRINT "ENTER SELL, A ALL, C CLEAR";
            LOCATE 20, 4: PRINT "L LEAVE";
        CASE STBANK
            COLOR 11: LOCATE 5, 13: PRINT "FRONTIER BANK";
            LOCATE 9, 4: PRINT "POCKET CASH $"; Cash;
            LOCATE 11, 4: PRINT "BANK BALANCE $"; Bank;
            LOCATE 14, 4: PRINT "TRANSFER $"; BankEntry$; "_";
            LOCATE 18, 4: PRINT "D DEPOSIT, W WITHDRAW, C CLEAR";
            LOCATE 20, 4: PRINT "L LEAVE";
        CASE STSALOON
            COLOR 11: LOCATE 5, 13: PRINT "FRONTIER SALOON";
            LOCATE 9, 4: PRINT "POCKET CASH $"; Cash;
            LOCATE 12, 4: PRINT "D BUY DRINK $5 (+1 WATER)";
            LOCATE 14, 4: PRINT "P HIGH CARD $10";
            LOCATE 16, 4: PRINT "YOUR CARD"; CardMe; " HOUSE"; CardHouse;
            LOCATE 19, 4: PRINT "L LEAVE";
        CASE STEND
            COLOR 12: LOCATE 7, 10: PRINT "END OF YOUR CLAIM";
            LOCATE 10, 4: PRINT "CASH $"; Cash; " BANK $"; Bank;
            LOCATE 13, 4: PRINT "DEEPEST"; (Deepest - 2) * 10; " FEET";
            LOCATE 17, 4: PRINT "N NEW GAME, Q QUIT";
    END SELECT
    DrawTextLine 25, 14, Message$
END SUB