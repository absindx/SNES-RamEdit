;--------------------------------------------------
; Ram edit
;--------------------------------------------------

;--------------------------------------------------
; General setting
;--------------------------------------------------

!RomSize	= 512*1024
!RomType	= 1					; 0=LoROM / 1=HiROM
;!DEBUG		= 1					; Release build with comment out

;--------------------------------------------------
; ROM setting
;--------------------------------------------------

	arch	65816

	math	round on
	math	pri on

	print	"ROM Size: ", dec(!RomSize/1024), "KiB"
if !RomType == 0
	print	"ROM Type: LoROM"
	lorom
	!LoROM	= 1
	!HiROM	= 0

	!EofAddress	= !RomSize*2+$808000
	org	$808000
else
	print	"ROM Type: HiROM"
	hirom
	!LoROM	= 0
	!HiROM	= 1

	!EofAddress	= !RomSize+$C00000
	org	$C00000
endif

	check bankcross off
	padbyte	$00
	pad	!EofAddress
	check bankcross on

;--------------------------------------------------
; Library
;--------------------------------------------------

incsrc	"Include/Library_Macro.asm"
incsrc	"Include/Library_Debug.asm"
incsrc	"Include/IOName_Standard.asm"

incsrc	"RamMap.asm"

;--------------------------------------------------
; ROM header
;--------------------------------------------------

	org	$00FFB0
AdditionalCartridgeInformation:
	db	"HK"					; $00FFB0 : Maker code
	db	"03RE"					; $00FFB2 : Game code
	db	0,0,0,0,0,0				; $00FFB6 : Reserved
	db	$00					; $00FFBC : Expansion flash size
	db	$00					; $00FFBD : Expansion Ram size
	db	$00					; $00FFBE : Special version
	db	$00					; $00FFBF : Chipset subtype

	org	$00FFC0
	padbyte	$20
CartridgeInformation:
	db	"Ram edit"				; $00FFC0 : Game title
	pad	$00FFD5
	db	$20|!RomType				; $00FFD5 : Map mode (Slow 2.68 MHz)
	db	$00					; $00FFD6 : Cartridge type (ROM)
	db	log2(!RomSize/1024)			; $00FFD7 : Rom size (4M Bit)
	db	$00					; $00FFD8 : Ram size (None)
	db	$00					; $00FFD9 : Destination code (Japan)
	db	$33					; $00FFDA : Fixed value
	db	$01					; $00FFDB : Mask rom version
	dw	$FFFF					; $00FFDC : Complement check
	dw	$0000					; $00FFDE : Check sum

	org	$00FFE0
Vectors:
	dw	UnusedHandler				; $00FFE0 : Native (Reserved)
	dw	UnusedHandler				; $00FFE2 : Native (Reserved)
	dw	NativeCOP				; $00FFE4 : Native COP - halt detect
	dw	NativeBRK				; $00FFE6 : Native BRK - halt detect
	dw	UnusedHandler				; $00FFE8 : Native ABORT
	dw	NativeNMI				; $00FFEA : Native NMI
	dw	UnusedHandler				; $00FFEC : Native (Reserved)
	dw	UnusedHandler				; $00FFEE : Native IRQ
	dw	UnusedHandler				; $00FFF0 : Emulation (Reserved)
	dw	UnusedHandler				; $00FFF2 : Emulation (Reserved)
	dw	UnusedHandler				; $00FFF4 : Emulation COP
	dw	UnusedHandler				; $00FFF6 : Emulation (Reserved)
	dw	UnusedHandler				; $00FFF8 : Emulation ABORT
	dw	UnusedHandler				; $00FFFA : Emulation NMI
	dw	EmulationRESET				; $00FFFC : Emulation RESET
	dw	UnusedHandler				; $00FFFE : Emulation IRQ / BRK

;--------------------------------------------------
; Interrupt handler
;--------------------------------------------------

	org	$00FFAF
UnusedHandler:
		RTI

	org	$00FF80
NativeNMI:
		; NOTE: Do not use PHB : PEA $0000 to save stack usage
		SEP	#$30
		PHA
		LDA.l	!CPU_RDNMI			;   clear NMI flag
		LDA.l	!AliveCounter			;\
		INC					; | INC.l !AliveCounter
		STA.l	!AliveCounter			;/
		BEQ	Halt
		PLA
		RTI
Halt:
NativeBRK:
NativeCOP:
		JML	RunCode_Halted

	warnpc	UnusedHandler

;--------------------------------------------------
; ROM signature
;--------------------------------------------------

if !LoROM
	org	$008000
else
	org	$C00000
endif

	;	 0123456789ABCDEF
	db	"Ram edit ver1.11"
if !LoROM
	db	"LoROM           "
else
	db	"HiROM           "
endif

if !HiROM
	org	$008000	; HiROM
endif

;--------------------------------------------------
; Program
;--------------------------------------------------

	fillbyte	$00
	padbyte		$00

EmulationRESET:
		SEI					;   for emulator vector detection
		REP	#$CB				;   nv??dIzc
		XCE
		SEP	#$34				;   nvMXdIzC
		; .shortm, .shortx

		STZ	!CPU_NMITIMEN			;   disable NMI
		STZ	!CPU_MDMAEN			;   disable DMA
		STZ	!CPU_HDMAEN			;   disable HDMA

		REP	#$11				;\
		; .shortm, .longx			; | set registers
		LDX.w	#!Stack_Bottom			; |   SP = #$437B
		TXS					;/
		JML	.SetPBR				;\
.SetPBR							; |   PB = (PC Bank)
		PHK					; |   DB = (PC Bank)
		PLB					; |   D  = $4300 (DMA I/O)
		PEA	!RAM_DMACH0			; |
		PLD					;/
		SEP	#$30
		; .shortm, .shortx

		; Set I/O registers
		JSR	InitializeCpu
		JSR	InitializePpu

		; Clear VRAM
		JSR	ClearVram

		LDA.b	#%00000001			;\  Disable NMI, Joypad auto-read
		STA	!CPU_NMITIMEN			;/

		JMP	Initialize
		;JMP	FrameMain

InitializeCpu:
		; SNES Development Manual book1 - Chapter 26 Register Clear (Initial Settings)
		; .shortm, .shortx

		LDX.b	#$0D
-		LDA	.InitializeValue, X
		STA	!CPU_NMITIMEN, X
		DEX
		BPL	-

		RTS

.InitializeValue
	;	$00, $01, $02, $03, $04, $05, $06
	db	$00, $FF, $00, $00, $00, $00, $00	; $4200
	;	$07, $08, $09, $0A, $0B, $0C, $0D
	db	$00, $00, $00, $00, $00, $00, $00	; $4207

InitializePpu:
		; SNES Development Manual book1 - Chapter 26 Register Clear (Initial Settings)
		; .shortm, .shortx

		LDX.b	#$33				;\
-		STZ	!PPU_INIDISP, X			; | clear to zero
		DEX					; |
		BNE	-				;/  no $2100 required

		LDX.b	#$07				;\
-		STZ	!PPU_BG1HOFS, X			; | set the second byte of the double write register
		STZ	!PPU_BG1HOFS, X			; |
		LDA	.InitializeValue, X		; |
		STZ	!PPU_M7A, X			; |
		STA	!PPU_M7A, X			; |
		DEX					; |
		BPL	-				;/

		; reconfigure non-zero registers
		LDA.b	#$8F				;   forced blank
		STA	!PPU_INIDISP
		LDA.b	#$80				;   increment after access $2119 or $213A
		STA	!PPU_VMAINC
		LDA.b	#$30				;   disable color math
		STA	!PPU_CGSWSEL
		LDA.b	#$E0				;   write RGB
		STA	!PPU_COLDATA

		RTS

.InitializeValue
	; reset $2121 to reuse the loop (8 bytes)
	;	$1B, $1C, $1D, $1E, $1F, $20, $21, $22
	db	$01, $00, $00, $01, $00, $00, $00, $00	; $211B

ClearVram:
		; Transfer zero to VRAM $0000 - $FFFF

		PHP
		REP	#$20
		SEP	#$10
		; .longm, .shortx
		STZ	!PPU_VMADDL
		LDA.w	#(%00001001)|(!PPU_VMDATAL<<8)	;\  DMA parameter = Bus: A to B / Address: Fixed / Transfer: 2 bytes, 2 addresses
							; | B-Bus address = !PPU_VMDATAL
		STA	!DMA_DMAP0			;/    with !WRAM_WMADDH
		LDA.w	#ZeroByte			;\
		STA	!DMA_A1T0L			; | A-Bus address = ZeroByte
		LDX.b	#(ZeroByte>>16)			; |
		STX	!DMA_A1B0			;/
		LDA.w	#$0000				;\  DMA size = $10000
		STA	!DMA_DAS0L			;/
		LDX.b	#$01				;\  Execute DMA #0
		STX	!CPU_MDMAEN			;/
		PLP
		RTS

;--------------------------------------------------
; Common data

ZeroByte:
	db	$00, $00, $00, $00
ShiftTable:
	db	$00, $01, $02, $04, $08, $10, $20, $40, $80
HighNibbleIncrement:
	db	$00, $10, $20, $30, $40, $50, $60, $70
	db	$80, $90, $A0, $B0, $C0, $D0, $E0, $F0

;IncrementTable:
incsrc	"Include/IncrementTable.asm"

HighNibbleAscii:
	db	"0000000000000000"
	db	"1111111111111111"
	db	"2222222222222222"
	db	"3333333333333333"
	db	"4444444444444444"
	db	"5555555555555555"
	db	"6666666666666666"
	db	"7777777777777777"
	db	"8888888888888888"
	db	"9999999999999999"
	db	"AAAAAAAAAAAAAAAA"
	db	"BBBBBBBBBBBBBBBB"
	db	"CCCCCCCCCCCCCCCC"
	db	"DDDDDDDDDDDDDDDD"
	db	"EEEEEEEEEEEEEEEE"
	db	"FFFFFFFFFFFFFFFF"

AsciiHex:
LowNibbleAscii:
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"
	db	"0123456789ABCDEF"

;--------------------------------------------------
; Routines

	dpbase	!RAM_DMACH0

Initialize:
		REP	#$20
		SEP	#$10
		; .longm, shortx

		; Screen configuration settings

		LDX.b	#%00000001
		STX	!PPU_BGMODE

		LDX.b	#%00000010			;   Add subscreen
		STX	!PPU_CGSWSEL
		LDX.b	#%00100000
		STX	!PPU_CGADSUB

		LDX.b	#%00000011
		STX	!PPU_TM
		STX	!PPU_TMW
		LDX.b	#%00000000
		STX	!PPU_TS
		STX	!PPU_TSW

		LDX.b	#%00000100			;   Overscan
		STX	!PPU_SETINI

		LDX.b	#(!VRAM_CommonGraphics>>9&$F0)|(!VRAM_CommonGraphics>>13&$0F)
		STX	!PPU_BG12NBA
		LDX.b	#$00
		STX	!PPU_BG34NBA

		LDX.b	#(!VRAM_Layer1Tilemap>>9&$FC)|(%00)
		STX	!PPU_BG1SC
		LDX.b	#(!VRAM_Layer2Tilemap>>9&$FC)|(%00)
		STX	!PPU_BG2SC

if !Release
		LDX.b	#$20				;\
		STX	!PPU_COLDATA			; | set fiexed color $0000 (0, 0, 0)
		LDX.b	#$40				; |
		STX	!PPU_COLDATA			; |
		LDX.b	#$80				; |
		STX	!PPU_COLDATA			;/
else
		LDX.b	#$28				;\
		STX	!PPU_COLDATA			; | set fiexed color $0048 (8, 2, 0)
		LDX.b	#$42				; |
		STX	!PPU_COLDATA			; |
		LDX.b	#$80				; |
		STX	!PPU_COLDATA			;/
endif

		; Initial memories
		LDX.b	#!ScreenID_Edit			;\  !ScreenMode = Edit
		STX.b	!ScreenMode			;/
		STZ.b	!EditBaseAddress		;\
		LDX.b	#$7E				; | !EditBaseAddress = #$7E0000
		STX.b	!EditBaseAddress+2		;/
		STZ.b	!EditCursorOffset		;   !EditCursorOffset, !EditCopyValue
		STZ.b	!MenuCursorIndex		;   !MenuCursorIndex, unused
		STZ.b	!PadPrev			;
		STZ.b	!PadPress			;
		STZ.b	!PadRepeatTimer			;   !PadRepeatTimer, !AliveCounter
		STZ.b	!JumpCursorAddress+0		;
		STZ.b	!JumpCursorAddress+2		;   !JumpCursorAddress(bank), unused
		JSR	UpdateEditCursorAddress

		; Transfer static screen
		JSR	TransferPalette
		JSR	TransferGraphics
		SEP	#$30
		; .shortm, shortx

		JSR	TransferInitialTilemaps
		JSR	GotoScreen_Edit

		;RTS					;   fall through

FrameMain:
		SEP	#$30
		; .shortm, shortx

		LDA.b	#$8F				;   forced blank
		STA	!PPU_INIDISP

		STZ	!PPU_BG1HOFS			;\
		STZ	!PPU_BG1HOFS			; | Layer1 offset = (0, 0)
		STZ	!PPU_BG1VOFS			; |
		STZ	!PPU_BG1VOFS			;/
		LDA.b	#$04				;\
		STA	!PPU_BG1HOFS			; | Layer2 offset = (4, 0)
		STZ	!PPU_BG1HOFS			; |
		STZ	!PPU_BG1VOFS			; |
		STZ	!PPU_BG1VOFS			;/

		; Jump to screen routines
		LDA	!ScreenMode
		ASL
		TAX
		JSR	(ScreenRoutineTable, X)
		; Exit screen routine

NextFrame:	LDA.b	#$0F				;   show screen
		STA	!PPU_INIDISP

		; Wait next frame
		SEI
		LDA.b	#%10000001			;\  Enable NMI, Joypad auto-read
		STA	!CPU_NMITIMEN			;/
		WAI
		LDA.b	#%00000001			;\  Disable NMI, Joypad auto-read
		STA	!CPU_NMITIMEN			;/
		STZ	!AliveCounter
		JMP	FrameMain

ScreenRoutineTable:
	dw	ScreenRoutine_Edit			; !ScreenID_Edit
	dw	ScreenRoutine_Jump			; !ScreenID_Jump
	dw	ScreenRoutine_Menu			; !ScreenID_Menu
	dw	ScreenRoutine_MenuMessage		; !ScreenID_MenuMessage
	dw	ScreenRoutine_RunCode			; !ScreenID_RunCode

;--------------------------------------------------

UpdateJoypad:
		; .shortm, shortx
		LDA.b	#%00000001			;\
-		BIT	!CPU_HVBJOY			; | wait automatic controller reading
		BNE	-				;/

		REP	#$20
		; .longm, shortx
		LDA	!CPU_STDCNTRL1L			;\
		EOR.b	!PadPrev			; | detect keydown
		AND	!CPU_STDCNTRL1L			; |
		STA.b	!PadPress			;/
		LDX	!PadRepeatTimer			;\
		LDA	!CPU_STDCNTRL1L			; | update key repeat counter
		CMP.b	!PadPrev			; |
		BEQ	.KeepRepeat			; |
		LDX	#$FF				; |
.KeepRepeat	INX					;/
		CPX	#!KeyRepeat_Wait		;\
		BCC	.SkipKeyRepeat			; | overwrite keydown
		LDX	#!KeyRepeat_Reload		; |
		STA.b	!PadPress			;/
.SkipKeyRepeat	STA.b	!PadPrev			;\  confirm keydown
		STX	!PadRepeatTimer			;/

		; .longm, shortx
		SEP	#$30
		RTS

; BYsS UDLR   AXlr 0000
!Button_B		= %10000000
!Button_Y		= %01000000
!Button_Select		= %00100000
!Button_Start		= %00010000
!Button_DUp		= %00001000
!Button_DDown		= %00000100
!Button_DLeft		= %00000010
!Button_DRight		= %00000001
!Button_A		= %10000000
!Button_X		= %01000000
!Button_L		= %00100000
!Button_R		= %00010000
!Button_0		= %00001000
!Button_1		= %00000100
!Button_2		= %00000010
!Button_3		= %00000001

;--------------------------------------------------

TransferPalette:
		; .longm, .shortx

		LDA.w	#(%00000010)|(!PPU_CGDATA<<8)	;\  DMA parameter = Bus: A to B / Address: Increment A / Transfer: 2 byte, 1 address
							; | B-Bus address = !PPU_CGDATA
		STA	!DMA_DMAP0			;/    with !DMA_BBAD0
		LDA.w	#.Palette			;\
		STA	!DMA_A1T0L			; | A-Bus address = .Palette
		LDX.b	#(.Palette>>16)			; |
		STX	!DMA_A1B0			;/
		LDA.w	#$0200				;\  DMA size = $0200
		STA	!DMA_DAS0L			;/
		LDX.b	#$00				;\  Set CGRAM address = $00
		STX	!PPU_CGADD			;/
		INX					;\  Execute DMA #0
		STX	!CPU_MDMAEN			;/

		RTS

.Palette
incbin	"Graphics/Palette_Main.bin"

TransferGraphics:
		; .longm, .shortx

		LDX.b	#%10000000			;   Increment at $2119, No remap, Increment 1 word
		STX	!PPU_VMAINC

		LDA.w	#!VRAM_CommonGraphics/2
		STA	!PPU_VMADDL			;   Set VRAM address = $8000

		LDA.w	#(%00000001)|(!PPU_VMDATAL<<8)	;\  DMA parameter = Bus: A to B / Address: Increment A / Transfer: 2 byte, 2 address
							; | B-Bus address = !PPU_VMDATAL
		STA	!DMA_DMAP0			;/    with !DMA_BBAD0
		LDA.w	#.Graphics			;\
		STA	!DMA_A1T0L			; | A-Bus address = .Graphics
		LDX.b	#(.Graphics>>16)		; |
		STX	!DMA_A1B0			;/
		LDA.w	#$2000				;\  DMA size = $2000
		STA	!DMA_DAS0L			;/
		LDX	#$01				;\  Execute DMA #0
		STX	!CPU_MDMAEN			;/

		RTS

	skip align 16
.Graphics
incbin	"Graphics/GFX_Main.bin"

; Tilemaps
TransferTilemap:
		; arguments:
		;   A(8 bit) : transfer data index
		; .shortm, shortx

		ASL	A
		ASL	A
		ASL	A
		TAY

		LDX.b	#%10000000			;   Increment at $2119, No remap, Increment 1 word
		STX	!PPU_VMAINC

		LDA	.TilemapTable+2, Y		;\
		STA	!DMA_A1B0			; | A-Bus address
		REP	#$20				; |
		; .longm, shortx			; |
		LDA	.TilemapTable+0, Y		; |
		STA	!DMA_A1T0L			;/
		LDA	.TilemapTable+6, Y		;\  Set VRAM address
		STA	!PPU_VMADDL			;/
		LDA.w	#(%00000001)|(!PPU_VMDATAL<<8)	;\  DMA parameter = Bus: A to B / Address: Increment A / Transfer: 2 byte, 2 address
							; | B-Bus address = !PPU_VMDATAL
		STA	!DMA_DMAP0			;/    with !DMA_BBAD0
		LDA	.TilemapTable+4, Y		;\  DMA size = $0580
		STA	!DMA_DAS0L			;/
		LDX.b	#$01				;\  Execute DMA #0
		STX	!CPU_MDMAEN			;/

		SEP	#$30
		RTS

macro	DefineTilemap(id, label, vramAddr)
	!TilemapID_<label>	= <id>
	skip align 8
	dl	.<label>
	skip align 4
	dw	.<label>End-.<label>
	dw	(<vramAddr>)/2
endmacro
macro	IncludeTilemap(id, label)
.<label>
incbin	"Tilemap/Tilemap_<label>.bin"
.<label>End
endmacro

	skip align 8
.TilemapTable
	; Address define
	%DefineTilemap(0, Edit,				!VRAM_Layer2Tilemap+$0000)	; !TilemapID_Edit
	%DefineTilemap(1, EditUsage,			!VRAM_Layer2Tilemap+$05C0)	; !TilemapID_EditUsage
	%DefineTilemap(2, Jump,				!VRAM_Layer2Tilemap+$05C0)	; !TilemapID_Jump
	%DefineTilemap(3, Menu,				!VRAM_Layer1Tilemap+$0200)	; !TilemapID_Menu
	%DefineTilemap(4, MenuUsage,			!VRAM_Layer2Tilemap+$05C0)	; !TilemapID_MenuUsage
	%DefineTilemap(5, MenuMessageUsage,		!VRAM_Layer2Tilemap+$0600)	; !TilemapID_MenuMessageUsage
	%DefineTilemap(6, MenuMessage_Blank,		!VRAM_Layer1Tilemap+$0500)	; !TilemapID_MenuMessage_Blank
	%DefineTilemap(7, MenuMessage_Running,		!VRAM_Layer1Tilemap+$0500)	; !TilemapID_MenuMessage_Running
	%DefineTilemap(8, MenuMessage_Completed,	!VRAM_Layer1Tilemap+$0500)	; !TilemapID_MenuMessage_Completed
	%DefineTilemap(9, MenuMessage_Halted,		!VRAM_Layer1Tilemap+$0500)	; !TilemapID_MenuMessage_Halted

	skip align 16
	; Include data
	%IncludeTilemap(0, Edit)
	%IncludeTilemap(1, EditUsage)
	%IncludeTilemap(2, Jump)
	%IncludeTilemap(3, Menu)
	%IncludeTilemap(4, MenuUsage)
	%IncludeTilemap(5, MenuMessageUsage)
	%IncludeTilemap(6, MenuMessage_Blank)
	%IncludeTilemap(7, MenuMessage_Running)
	%IncludeTilemap(8, MenuMessage_Completed)
	%IncludeTilemap(9, MenuMessage_Halted)

if !Debug
	; Debug mark
	pushpc
	org .Edit+$6E
	db	"( D e b u g ) "
	pullpc
endif

TransferInitialTilemaps:
		; implementation is required after value definition.
		; .longm, shortx
		LDA.b	#!TilemapID_Edit
		JSR	TransferTilemap
		LDA.b	#!TilemapID_Menu
		JSR	TransferTilemap
		LDA.b	#!TilemapID_MenuMessage_Blank
		JMP	TransferTilemap

;--------------------------------------------------

DrawHex:
		; arguments:
		;   A(8 bit) : draw value
		; Need !PPU_VMAINC = #%00000000
		; .shortm, shortx
		TAX
		LDA	HighNibbleAscii, X
		STA	!PPU_VMDATAL
		LDA	LowNibbleAscii, X
		STA	!PPU_VMDATAL
		RTS

DrawEditScreen:
%DefineLocal(VramAddress,	!ScratchMemory+0, 2)
%DefineLocal(ColOffset,		!ScratchMemory+2, 1)
		; .shortm, shortx

		REP	#$20
		; .longm, shortx

		LDX.b	#%00000000			;   Increment at $2118, No remap, Increment 1 word
		STX	!PPU_VMAINC

		LDA.w	#((!VRAM_Layer2Tilemap+$0CE)>>1);   VRAM address: "BANK"
		STA	!PPU_VMADDL

		LDA.w	#((!VRAM_Layer2Tilemap+$1C4)>>1);   draw address
		STA.b	.VramAddress

		LDA.b	!EditBaseAddress		;\
		STA	!WRAM_WMADDL			; | WRAM address = !EditBaseAddress (& $01FFFF)
		LDX.b	!EditBaseAddress+2		; |
		STX	!WRAM_WMADDH			;/

		SEP	#$30
		; .shortm, shortx

		LDA	EditBaseAddress+2		;\  draw bank
		JSR	DrawHex				;/

		LDA.b	.VramAddress+0			;\
		STA	!PPU_VMADDL			; | VRAM address: ADDR
		LDA.b	.VramAddress+1			; |
		STA	!PPU_VMADDH			;/

		STZ.b	.ColOffset

		dpbase	$2100
		PEA	$2100				;\  DP = $2100 (PPU I/O)
		PLD					;/
		LDA	#$00

		CLC
.LoopRow	LDX	!EditBaseAddress+1		;\
		LDY	HighNibbleAscii, X		; | draw address - high
		STY.b	!PPU_VMDATAL			; |   DrawHex routine (inline)
		LDY	LowNibbleAscii, X		; |
		STY.b	!PPU_VMDATAL			;/
		;CLC					;\
		ADC	!EditBaseAddress+0		; | draw address - low
		TAX					; |   DrawHex routine (inline)
		LDA	HighNibbleAscii, X		; |
		STA.b	!PPU_VMDATAL			; |
		LDA	LowNibbleAscii, X		; |
		STA.b	!PPU_VMDATAL			;/
		BIT.b	!PPU_VMDATALREAD		;   dummy read (increment VRAM address)

		LDY.b	#$08
.LoopCol	LDX.b	!WRAM_WMDATA			;\
		LDA	HighNibbleAscii, X		; | draw memory value
		STA.b	!PPU_VMDATAL			; |   DrawHex routine (inline)
		LDA	LowNibbleAscii, X		; |
		STA.b	!PPU_VMDATAL			;/
		BIT.b	!PPU_VMDATALREAD		;   dummy read (increment VRAM address)
		DEY
		BNE	.LoopCol

		REP	#$21				;   carry is 0
		; .longm, shortx
		LDA	.VramAddress+0			;\
		ADC.w	#$0040				; | next row VRAM address
		STA	.VramAddress+0			; |
		STA.b	!PPU_VMADDL			; |
		SEP	#$31				;/
		; .shortm, shortx
		LDA	.ColOffset
		ADC.b	#$07				;   +8
		STA	.ColOffset
		CMP.b	#$40
		BCC	.LoopRow

		dpbase	!RAM_DMACH0
		PEA	!RAM_DMACH0			;\  DP = $4300 (DMA I/O)
		PLD					;/

		; Redraw cursor
		JSR	ScreenRoutine_Edit_SetCursorAddress
		LDA.b	#(2<<2)				;   palette #2
		STA	!PPU_VMDATAH

		RTS

;--------------------------------------------------

UpdateEditCursorAddress:
		PHP
		REP	#$21
		SEP	#$10
		; .longm, shortx

		LDX.b	!EditBaseAddress+2		;\  bank
		STX.b	!EditCursorAddress+2		;/

		LDA.b	!EditCursorOffset		;\
		AND.w	#$00FE				; | high, low address
		LSR					; |
		ADC.b	!EditBaseAddress+0		; |   carry is 0
		STA.b	!EditCursorAddress+0		;/

		PLP
		RTS

;--------------------------------------------------

GotoScreen_Edit:
		; .shortm, shortx
		LDA.b	#!ScreenID_Edit
		STA	!ScreenMode
		LDA.b	#!TilemapID_EditUsage
		JSR	TransferTilemap
		JSR	DrawEditScreen
		JSR	ScreenRoutine_Edit_DrawCopy
		LDA.b	#%00000010			;   hide layer 1 (menu)
		STA	!PPU_TM
		RTS

GotoScreen_Jump:
		; .shortm, shortx

		; Set initial address
		LDA.b	!EditBaseAddress+0		;\
		STA.b	!JumpCursorAddress+0		; | copy address
		LDA.b	!EditBaseAddress+1		; |
		STA.b	!JumpCursorAddress+1		; |
		LDA.b	!EditBaseAddress+2		; |
		STA.b	!JumpCursorAddress+2		;/

		LDA.b	#!ScreenID_Jump
		STA	!ScreenMode
		LDA.b	#!TilemapID_Jump
		JSR	TransferTilemap
		LDA.b	#%00000010			;   hide layer 1 (menu)
		STA	!PPU_TM
		RTS

GotoScreen_Menu:
		; .shortm, shortx

		; Set cursor value
		LDX.b	#%00000000			;   Increment at $2118, No remap, Increment 1 word
		STX	!PPU_VMAINC

		LDA.b	!EditCursorOffset
		LSR
		LDA.b	[!EditCursorAddress]

		LDX.b	#((!VRAM_Layer1Tilemap+$330)>>1);\
		STX	!PPU_VMADDL			; | Fill page
		LDX.b	#((!VRAM_Layer1Tilemap+$330)>>9); |
		STX	!PPU_VMADDH			; |
		JSR	DrawHex				;/    X <= A
		LDA.b	#((!VRAM_Layer1Tilemap+$370)>>1);\
		STA	!PPU_VMADDL			; | Fill all
		LDA.b	#((!VRAM_Layer1Tilemap+$370)>>9); |
		STA	!PPU_VMADDH			; |
		TXA					; |
		JSR	DrawHex				;/
		LDA.b	#((!VRAM_Layer1Tilemap+$46C)>>1);\
		STA	!PPU_VMADDL			; | Run cursor
		LDA.b	#((!VRAM_Layer1Tilemap+$46C)>>9); |
		STA	!PPU_VMADDH			; |
		LDA.b	!EditCursorAddress+2		; |   bank
		JSR	DrawHex				; |
		LDA.b	!EditCursorAddress+1		; |   high
		JSR	DrawHex				; |
		LDA.b	!EditCursorAddress+0		; |   low
		JSR	DrawHex				;/

		STZ.b	!MenuCursorIndex

		LDA.b	#!ScreenID_Menu
		STA	!ScreenMode
		LDA.b	#!TilemapID_MenuUsage
		JSR	TransferTilemap
		LDA.b	#!TilemapID_MenuMessage_Blank
		JSR	TransferTilemap
		LDA.b	#%00000011			;   show layer 1 (menu)
		STA	!PPU_TM
		RTS

GotoScreen_RunCode:
		; .shortm, shortx

		LDA.b	#!ScreenID_RunCode
		STA	!ScreenMode
		LDA.b	#!TilemapID_MenuMessage_Running
		JSR	TransferTilemap
		LDA.b	#%00000011			;   show layer 1 (menu)
		STA	!PPU_TM
		RTS

GotoScreen_MenuMessage:
		; .shortm, shortx

		LDA.b	#!ScreenID_MenuMessage
		STA	!ScreenMode
		LDA.b	#!TilemapID_MenuMessageUsage
		JSR	TransferTilemap
		LDA.b	#%00000011			;   show layer 1 (menu)
		STA	!PPU_TM
		RTS

;--------------------------------------------------
; ScreenRoutine - Edit

ScreenRoutine_Edit:
		; .shortm, shortx

		LDX.b	#%10000000			;   Increment at $2119, No remap, Increment 1 word
		STX	!PPU_VMAINC

		; Remove cursor
		JSR	ScreenRoutine_Edit_SetCursorAddress
		STZ	!PPU_VMDATAH

		JSR	UpdateJoypad

		LDA.b	!PadPress+1			;\
		AND.b	#$0F				; | move cursor offset
		TAX					; |
		CLC					; |
		LDA.b	!EditCursorOffset		; |
		ADC	.CursorDelta, X			; |
		AND.b	#$7F				; |
		STA.b	!EditCursorOffset		;/
		JSR	UpdateEditCursorAddress

		; Set cursor position
		JSR	ScreenRoutine_Edit_SetCursorAddress

		LDA.b	!PadPrev+1			;\
		BIT.b	#!Button_Y			; | Y: Paste (always)
		BEQ	+				; |
		JSR	ScreenRoutine_Edit_Paste	; |
+							;/

		LDA.b	!PadPress+1			;\
		BIT.b	#!Button_Start			; | Start: Open menu
		BEQ	+				; |
		JSR	GotoScreen_Menu			; |
		JSR	ScreenRoutine_Edit_SetCursorAddress
		BRA	.Return				; |
+							;/
		LDA.b	!PadPress+1			;\
		BIT.b	#!Button_Select			; | Select: Jump address
		BEQ	+				; |
		JSR	GotoScreen_Jump			; |
		JSR	ScreenRoutine_Edit_SetCursorAddress
		BRA	.Return				; |
+							;/
		LDA.b	!PadPress+0			;\
		BIT.b	#!Button_R			; | R: Next page
		BEQ	+				; |
		JSR	ScreenRoutine_Edit_NextPage	; |
		BRA	.Return				; |
+							;/
		LDA.b	!PadPress+0			;\
		BIT.b	#!Button_L			; | L: Prev page
		BEQ	+				; |
		JSR	ScreenRoutine_Edit_PrevPage	; |
		BRA	.Return				; |
+							;/

		LDA.b	!PadPress+0			;\
		BIT.b	#!Button_X			; | X: Copy
		BEQ	+				; |
		JSR	ScreenRoutine_Edit_Copy		; |
		JSR	ScreenRoutine_Edit_SetCursorAddress
+							;/
		LDA.b	!PadPress+0			;\
		BIT.b	#!Button_A			; | A: Increment
		BEQ	+				; |
		JSR	ScreenRoutine_Edit_Increment	; |
+							;/
		LDA.b	!PadPress+1			;\
		BIT.b	#!Button_B			; | B: Decrement
		BEQ	+				; |
		JSR	ScreenRoutine_Edit_Decrement	; |
+							;/

.Return		; Redraw cursor
		LDA.b	#(2<<2)				;   palette #2
		STA	!PPU_VMDATAH

		RTS

;                       00  01  02  03  04  05  06  07  08  09  0A  0B  0C  0D  0E  0F
;                            >       >       >       >       >       >       >       >
;                                <   <           <   <           <   <           <   <
;                                        v   v   v   v                   v   v   v   v
;                                                        ^   ^   ^   ^   ^   ^   ^   ^
.CursorDelta	db	 0,  1, -1,  0, 16, 17, 15, 16,-16,-15,-17,-16,  0,  1, -1,  0

ScreenRoutine_Edit_SetCursorAddress:
%DefineLocal(VramAddress,	!ScratchMemory+0, 2)
		; .shortm, shortx

		LDA.b	!EditCursorOffset		;\  nibble offset
		LSR					;/    0YYY XXXN -> C
		AND.b	#$07				;\  X offset
		TAX					; |   0000 0XXX -> X
		LDA	.Mul3, X			; |
		ADC.b	#$00				; | X * 3 + nibble
		REP	#$20				;\
		; .longm, shortx			; | add initial address
		AND.w	#$00FF				; |
		ADC.w	#(!VRAM_Layer2Tilemap>>1)+((32*7)+7)
		STA.b	.VramAddress			;/

		LDA.b	!EditCursorOffset		;\
		AND.w	#$0070				; | add Y offset
		ASL					; |   ???? ???? 0YYY XXXN
		ASL					; |   0000 000Y YY00 0000 => Y * 0x40
		ADC.b	.VramAddress			;/    carry is 0
		STA	!PPU_VMADDL

		; .shortm, shortx
		SEP	#$30
		RTS

.Mul3	db	 0, 3, 6, 9,12,15,18,21

ScreenRoutine_Edit_Increment:
		; .shortm, shortx
		LDA.b	!EditCursorOffset
		LSR
		BCC	.HighNibble
.LowNibble	LDA.b	[!EditCursorAddress]
		INC
		BIT.b	#$0F				;\
		BNE	+				; | cancel carrying higher nibble
		;SEC					; |
		SBC	#$10				;/
+		TAX
		BRA	ScreenRoutine_Edit_WriteValue

.HighNibble	LDA.b	[!EditCursorAddress]
		;CLC
		ADC.b	#$10
		STA.b	[!EditCursorAddress]
		TAX
		LDA	HighNibbleAscii, X		;\  draw high nibble value
		STA	!PPU_VMDATAL			;/
		RTS

ScreenRoutine_Edit_Decrement:
		; .shortm, shortx
		LDA.b	!EditCursorOffset
		LSR
		BCC	.HighNibble
.LowNibble	LDA.b	[!EditCursorAddress]
		BIT.b	#$0F				;\
		BNE	+				; | cancel high nibble borrow
		;SEC					; |
		ADC.b	#$0F				;/
+		DEC
		TAX
		BRA	ScreenRoutine_Edit_WriteValue

.HighNibble	LDA.b	[!EditCursorAddress]
		;CLC
		SBC.b	#$0F
		STA.b	[!EditCursorAddress]
		TAX
		LDA	HighNibbleAscii, X		;\  draw high nibble value
		STA	!PPU_VMDATAL			;/
		RTS

ScreenRoutine_Edit_Copy:
		!EditScreen_VramAddressCopyValue	= !VRAM_Layer2Tilemap+$694
		; .shortm, shortx
		LDA.b	!EditCursorOffset
		LSR
		BCC	.HighNibble
.LowNibble	LDA.b	#$0F
		AND.b	[!EditCursorAddress]
		BRA	.Write

.HighNibble	LDA.b	#$F0
		AND.b	[!EditCursorAddress]
		LSR
		LSR
		LSR
		LSR

.Write
		STA.b	!EditCopyValue
ScreenRoutine_Edit_DrawCopy:
		; .shortm, shortx
		LDX.b	#(!EditScreen_VramAddressCopyValue>>1)
		STX	!PPU_VMADDL
		LDX.b	#(!EditScreen_VramAddressCopyValue>>9)
		STX	!PPU_VMADDH
		LDX.b	!EditCopyValue
		LDA	AsciiHex, X
		STA	!PPU_VMDATAL
		RTS

ScreenRoutine_Edit_Paste:
		; .shortm, shortx
		LDX.b	!EditCopyValue
		LDA.b	!EditCursorOffset
		LSR
		BCC	.HighNibble
.LowNibble	LDA.b	#$F0
		AND.b	[!EditCursorAddress]
		ORA.b	!EditCopyValue
		BRA	ScreenRoutine_Edit_WriteValue

.HighNibble	LDA.b	#$0F
		AND.b	[!EditCursorAddress]
		ORA	HighNibbleIncrement, X
ScreenRoutine_Edit_WriteValue:
		; arguments:
		;   A(8 bit) : full value
		;   X(8 bit) : write char index
		;   Y(8 bit) : write offset
		; .shortm, shortx
		STA.b	[!EditCursorAddress]
		LDA	AsciiHex, X
		STA	!PPU_VMDATAL
		RTS

ScreenRoutine_Edit_PrevPage:
		; .shortm, shortx

		REP	#$21				;   carry is 0
		; .longm, shortx
		LDA.b	!EditBaseAddress+0
		SBC.w	#$003F				;   subtract 0x40
		STA.b	!EditBaseAddress+0
		SEP	#$30
		; .shortm, shortx
		LDA.b	!EditBaseAddress+2
		BCS	.SkipBank
		EOR.b	#$01
.SkipBank	STA.b	!EditBaseAddress+2
		JMP	DrawEditScreen

ScreenRoutine_Edit_NextPage:
		; .shortm, shortx
		REP	#$21				;   carry is 0
		; .longm, shortx
		LDA.b	!EditBaseAddress+0
		ADC.w	#$0040				;   add 0x40
		STA.b	!EditBaseAddress+0
		SEP	#$30
		; .shortm, shortx
		LDA.b	!EditBaseAddress+2
		BCC	.SkipBank
		EOR.b	#$01
.SkipBank	STA.b	!EditBaseAddress+2
		JMP	DrawEditScreen

;--------------------------------------------------
; ScreenRoutine - Jump

ScreenRoutine_Jump:
		; .shortm, shortx

		; Draw setting
		LDX.b	#%00000000			;   Increment at $2118, No remap, Increment 1 word
		STX	!PPU_VMAINC
		LDA.b	#((!VRAM_Layer2Tilemap+$64A)>>1)
		STA	!PPU_VMADDL
		LDA.b	#((!VRAM_Layer2Tilemap+$64A)>>9)
		STA	!PPU_VMADDH

		; Move cursor
		JSR	UpdateJoypad

		LDA.b	!PadPress+0
		BIT.b	#!Button_A
		BEQ	+
		LDA.b	!JumpCursorAddress+0		;\
		STA.b	!EditBaseAddress+0		; | A: Confirm
		LDA.b	!JumpCursorAddress+1		; |   copy address
		STA.b	!EditBaseAddress+1		; |
		LDA.b	!JumpCursorAddress+2		; |
		STA.b	!EditBaseAddress+2		;/
-		JMP	GotoScreen_Edit
+		LDA.b	!PadPress+1			;\
		BIT.b	#(!Button_B|!Button_Select)	; | B: Cancel
		BNE	-				;/  Start: Cancel
		BIT.b	#!Button_DLeft			;\
		BEQ	.SkipLeft			; | D-Pad Left: Move cursor
		REP	#$21				; |
		; .longm, shortx			; |
		LDA.b	JumpCursorAddress+0		; |
		BIT.w	#(!JumpAddressDistance-1)	; |
		BEQ	.LeftAligned			; |
		AND.w	#!JumpAddressMask		; |   clear remainder address
		STA.b	JumpCursorAddress+0		; |
		BRA	.CheckRight			; |
.LeftAligned	LDA.b	JumpCursorAddress+1		; |
		AND.w	#(!JumpAddressMask>>8)		; |
		SBC.w	#((!JumpAddressDistance>>8)-1)	; |   carry is 0
		CMP.w	#$7E00				; |
		BCS	+				; |
		EOR.w	#$0200				; |   $7Dxx -> $7Fxx
+		STA.b	JumpCursorAddress+1		; |
.CheckRight	SEP	#$30				; |
		; .shortm, shortx
		LDA.b	!PadPress+1			; |   reload pad
.SkipLeft						;/
		BIT.b	#!Button_DRight			;\
		BEQ	.SkipRight			; | D-Pad Right: Move cursor
		STZ.b	JumpCursorAddress+0		; |
		REP	#$21				; |
		; .longm, shortx			; |
		LDA.b	JumpCursorAddress+1		; |
		AND.w	#(!JumpAddressMask>>8)		; |
		ADC.w	#(!JumpAddressDistance>>8)	; |   carry is 0
		BVC	+				; |
		EOR.w	#$FE00				; |   $80xx -> $7Exx
+		STA.b	JumpCursorAddress+1		; |
		;SEP	#$30				; |
.SkipRight						;/

		; Draw bar
		REP	#$21				;\
		; .longm, shortx			; | convert to pixel index
		LDA.b	JumpCursorAddress+1		; |
		AND.w	#($01FF)&(!JumpAddressMask>>8)	; |
		LSR	#(!JumpAddressShift-8)		; |
		TAX					; |
		SEP	#$30				;/

		INX
		CMP	#(!JumpAddressBarWidth-1)
		BEQ	.BarZero

		LDY.b	#!JumpAddressBarTile
.BarLoopStart	TXA
		CMP.b	#$08
		BCC	.BarDrawCursor
		SBC.b	#$08
		TAX
		BNE	+				;\
		LDA.b	#(!Chr_JumpBar+$09)		; | cursor crossing tile boundaries
		BRA	.BarDrawStart			; |   0: $D9
+		LDA.b	#!Chr_JumpBar			; |   other: $D0
.BarDrawStart	STA	!PPU_VMDATAL			;/
		DEY
		BRA	.BarLoopStart
.BarDrawCursor	INC
		ADC.b	!Chr_JumpBar
		STA	!PPU_VMDATAL
		DEY
		BEQ	.BarEnd
		CMP.b	#(!Chr_JumpBar+$09)		;   cursor end
		BNE	.BarDrawEnd
		LDA.b	#(!Chr_JumpBar+$01)		;   cursor start
		STA	!PPU_VMDATAL
		DEY
.BarDrawEnd	LDA.b	!Chr_JumpBar
.BarLoopEnd	STA	!PPU_VMDATAL
		DEY
		BNE	.BarLoopEnd
		BRA	.BarEnd

.BarZero	LDA.b	#(!Chr_JumpBar+$01)		;   cursor start
		STA	!PPU_VMDATAL
		LDX.b	#!JumpAddressBarTile-2
		LDA	#!Chr_JumpBar			;   blank
-		STA	!PPU_VMDATAL
		DEX
		BNE	-
		LDA.b	#(!Chr_JumpBar+$09)		;   cursor end
		STA	!PPU_VMDATAL

.BarEnd		LDA	!PPU_VMDATALREAD		;   dummy read (bar border)
		LDA	!PPU_VMDATALREAD		;   dummy read ('$')

		; Draw address
		LDA.b	JumpCursorAddress+2
		JSR	DrawHex
		LDA.b	JumpCursorAddress+1
		JSR	DrawHex
		LDA.b	JumpCursorAddress+0
		JSR	DrawHex

		RTS

;--------------------------------------------------
; ScreenRoutine - Menu

ScreenRoutine_Menu:
		; .shortm, shortx

		; Remove cursor
		LDA.b	!MenuCursorIndex
		JSR	ScreenRoutine_Menu_SetCursorAddress
		LDA.b	#!Chr_MenuBlank
		STA	!PPU_VMDATAL

		JSR	UpdateJoypad

		LDA.b	!PadPress+1			;\
		BIT.b	#(!Button_B|!Button_Start)	; | B: Cancel
		BEQ	+				; | Start: Cancel
		JMP	GotoScreen_Edit			; |
+							;/
		; Update cursor index
		LDX.b	!MenuCursorIndex
		;LDA.b	!PadPress+1			;\
		BIT.b	#!Button_DDown			; | D-Pad: Move cursor
		BEQ	+				; |
		INX					; |
+		BIT.b	#!Button_DUp			; |
		BEQ	+				; |
		DEX					;/
+		BPL	+				;\
		LDX.b	#!MenuItemCount-1		; | saturate cursor with menu items count
+		CPX.b	#!MenuItemCount			; |
		BCC	+				; |
		LDX.b	#$00				; |
+		STX.b	!MenuCursorIndex		;/

		LDA.b	!PadPress+0			;\
		BIT.b	#!Button_A			; | A: Confirm
		BEQ	+				; |
		JMP	ScreenRoutine_Menu_Confirm	; |
+							;/
		; Redraw cursor
		TXA
		JSR	ScreenRoutine_Menu_SetCursorAddress
		LDA.b	#!Chr_Cursor
		STA	!PPU_VMDATAL

		RTS

ScreenRoutine_Menu_SetCursorAddress:
		; arguments:
		;   A(8 bit) : transfer data index
		; .shortm, shortx

		REP	#$20
		; .longm, shortx
		AND.w	#$00FF
		ASL					;\
		ASL					; | A = dst + 0x20 * index
		ASL					; |
		ASL					; |
		ASL					; |
		ADC.w	#((!VRAM_Layer1Tilemap+$308)>>1);/
		STA	!PPU_VMADDL

		SEP	#$30
		; .shortm, shortx
		RTS

ScreenRoutine_Menu_Confirm:
		; .shortm, shortx
		LDA.b	!MenuCursorIndex
		ASL
		TAX
		JSR	(ScreenRoutine_MenuItem_Table, X)
		JMP	GotoScreen_Edit

ScreenRoutine_MenuItem_Table:
	dw	ScreenRoutine_MenuItem_FillPage
	dw	ScreenRoutine_MenuItem_FillAll
	dw	ScreenRoutine_MenuItem_Preset1
	dw	ScreenRoutine_MenuItem_Preset2
	dw	ScreenRoutine_MenuItem_Preset3
	dw	ScreenRoutine_MenuItem_Run

ScreenRoutine_MenuItem_FillPage:
		; .shortm, shortx

		LDA.b	[!EditCursorAddress]

		LDY.b	#$3F
-		STA.b	[!EditBaseAddress], Y
		DEY
		BPL	-

		RTS

ScreenRoutine_MenuItem_FillAll:
		; .shortm, shortx

		LDA.b	[!EditCursorAddress]
		TAY

		LDX	#$7E				;\
		STX	!WRAM_WMADDH			; | PPU WRAM access addr = $7E0000
		REP	#$21				; |
		; .longm, .shortx			; |
		STZ	!WRAM_WMADDL			;/

		LDA.w	#(%00001000)|(!WRAM_WMDATA<<8)	;\  DMA parameter = Bus: A to B / Address: Fixed / Transfer: 1 byte, 1 address
							; | B-Bus address = !WRAM_WMDATA
		STA	!DMA_DMAP0			;/    with !DMA_BBAD0
		TYA					;\
		ADC.w	#IncrementTable			; | A-Bus address = IncrementTable, Y
		STA	!DMA_A1T0L			; |
		LDY.b	#(IncrementTable>>16)		; |
		STY	!DMA_A1B0			;/
		STZ	!DMA_DAS0L			;   DMA size = $10000
		LDY.b	#$01				;\  Execute DMA #0
		STY	!CPU_MDMAEN			;/

		INX					;\
		STX	!WRAM_WMADDH			; | PPU WRAM access addr = $7F0000
		STZ	!WRAM_WMADDL			;/
		LDY.b	#$01				;\  Execute DMA #0
		STY	!CPU_MDMAEN			;/

		SEP	#$30
		; .shortm, shortx

		RTS

ScreenRoutine_MenuItem_Preset1:
		; .shortm, shortx
		LDX.b	#(PresetMemory1>>16)
		BRA	ScreenRoutine_MenuItem_PresetWrite

ScreenRoutine_MenuItem_Preset2:
		; .shortm, shortx
		LDX.b	#(PresetMemory2>>16)
		BRA	ScreenRoutine_MenuItem_PresetWrite

ScreenRoutine_MenuItem_Preset3:
		; .shortm, shortx
		LDX.b	#(PresetMemory3>>16)
		;BRA	ScreenRoutine_MenuItem_PresetWrite

ScreenRoutine_MenuItem_PresetWrite:
		; .shortm, shortx

		LDY	#$7E				;\
		STY	!WRAM_WMADDH			; | PPU WRAM access addr = $7E0000
		REP	#$21				; |
		; .longm, .shortx			; |
		STZ	!WRAM_WMADDL			;/

		LDA.w	#(%00000000)|(!WRAM_WMDATA<<8)	;\  DMA parameter = Bus: A to B / Address: Increment A / Transfer: 1 byte, 1 address
							; | B-Bus address = !WRAM_WMDATA
		STA	!DMA_DMAP0			;/    with !DMA_BBAD0

if !LoROM
		LDA.w	#$8000				;\
		STX	!DMA_A1B0			; | A-Bus address = PresetMemoryX
		STA	!DMA_A1T0L			;/
		STA	!DMA_DAS0L			;   DMA size = $8000
		LDY.b	#$01				;\  Execute DMA #0 (1)
		STY	!CPU_MDMAEN			;/

		INX					;\
		STX	!DMA_A1B0			; | A-Bus address = PresetMemoryX + $08000
		STA	!DMA_A1T0L			;/
		STA	!DMA_DAS0L			;   DMA size = $8000
		;LDY.b	#$01				;\  Execute DMA #0 (2)
		STY	!CPU_MDMAEN			;/

		INX					;\
		STX	!DMA_A1B0			; | A-Bus address = PresetMemoryX + $10000
		STA	!DMA_A1T0L			;/
		STA	!DMA_DAS0L			;   DMA size = $8000
		;LDY.b	#$01				;\  Execute DMA #0 (3)
		STY	!CPU_MDMAEN			;/

		INX					;\
		STX	!DMA_A1B0			; | A-Bus address = PresetMemoryX + $18000
		STA	!DMA_A1T0L			;/
		STA	!DMA_DAS0L			;   DMA size = $8000
		;LDY.b	#$01				;\  Execute DMA #0 (4)
		STY	!CPU_MDMAEN			;/

else
		STZ	!DMA_A1T0L			;\  A-Bus address = PresetMemoryX
		STX	!DMA_A1B0			;/
		STZ	!DMA_DAS0L			;   DMA size = $10000
		LDY.b	#$01				;\  Execute DMA #0
		STY	!CPU_MDMAEN			;/

		INX					;\  A-Bus address = PresetMemoryX + $10000
		STX	!DMA_A1B0			;/
		LDY.b	#$01				;\  Execute DMA #0
		STY	!CPU_MDMAEN			;/
endif

		SEP	#$30

		RTS

ScreenRoutine_MenuItem_Run:
		; .shortm, shortx

		JSR	GotoScreen_RunCode

		REP	#$10
		; .shortm, longx

		PLX					;   cancel return to ScreenRoutine_Menu_Confirm

		; Jump to cursor address
		LDA.b	#$0F				;   show screen
		STA	!PPU_INIDISP
		LDA.b	#%10000001			;\  Enable NMI, Joypad auto-read
		STA	!CPU_NMITIMEN			;/

		LDX.w	#!RunCode_StackPointer		;\  change stack pointer
		TXS					;/
		LDA.b	#(RunCode_Return-1)>>16		;\
		PHA					; | push return address
		PEA	RunCode_Return-1		;/
		LDA.b	!EditCursorAddress+2		;\
		PHA					; | set registers
		PLB					; |   A = $0000
		LDX.w	#$0000				; |   X = $0000
		TXA					; |   Y = $0000
		TXY					; |   D = $0000
		PHX					; |   DB = (dst bank)
		PLD					;/    PB = (dst bank - set by JML)

		REP	#$C9				;   nvMxdIzc
		SEP	#$36				;   nvMXdIZc
		JML	[!EditCursorAddress]

;--------------------------------------------------
; ScreenRoutine - Run code

ScreenRoutine_RunCode:
		; .shortm, shortx

		; None
		RTS

RunCode_Return:
		SEP	#$34				;   ??MX?I??
		; .shortm, shortx

		LDA.b	#!TilemapID_MenuMessage_Completed
		BRA	RunCode_RestoreStatus

RunCode_Halted:
		SEP	#$34				;   ??MX?I??
		; .shortm, shortx

		LDA.b	#!TilemapID_MenuMessage_Halted
		;BRA	RunCode_RestoreStatus		;   fall through

RunCode_RestoreStatus:
		REP	#$DB				;   nvMxdIzc
		XCE					;   goto native
		; .shortm, longx

		XBA

		LDX.w	#!Stack_Bottom			;\
		TXS					; | reset registers
		JML	.SetPBR				; |   SP = #$437B
.SetPBR							; |   PB = (PC Bank)
		PHK					; |   DB = (PC Bank)
		PLB					; |   D  = #$4300
		PEA	!RAM_DMACH0			; |
		PLD					;/
		SEP	#$30
		; .shortm, .shortx

		LDA.b	#$8F				;   forced blank
		STA	!PPU_INIDISP
		LDA.b	#%00000001			;\  Disable NMI, Joypad auto-read
		STA	!CPU_NMITIMEN			;/

		XBA					;   !TilemapID_MenuMessage_xxx
		JSR	TransferTilemap
		JSR	GotoScreen_MenuMessage
		JML	NextFrame

;--------------------------------------------------
; ScreenRoutine - Menu message

ScreenRoutine_MenuMessage:
		; .shortm, shortx

		JSR	UpdateJoypad
		LDA.b	!PadPress+0			;\
		BIT.b	#!Button_A			; | A: OK
		BEQ	+				; |
-		JMP	GotoScreen_Edit			;/
+		LDA.b	!PadPress+1			;\
		BIT.b	#!Button_Start			; | Start: OK
		BNE	-				;/
		RTS

;--------------------------------------------------
; User preset data
;--------------------------------------------------

	check bankcross	off
	dpbase		$0000

macro FillPreset(fillValue)
	if !Debug
		print "Preset: $", pc
	endif

	fillbyte	<fillValue>
	fill		$8000
	fill		$8000
	fill		$8000
	fill		$8000
endmacro
macro BinPreset(file)
	if !Debug
		print "Preset: $", pc
	endif

	incbin		<file>:000000-008000
	incbin		<file>:008000-010000
	incbin		<file>:010000-018000
	incbin		<file>:018000-020000
endmacro

if !LoROM
-	org		$800000+(-)			;\  to lorom address
	skip align	$040000				;/  $800000 + ceilBank(pc)
else
-	org		$C00000+(-)			;\  to hirom address
	skip align	$20000				;/  $C00000 + ceilBank(pc)
endif

incsrc	"PresetMemory.asm"

;--------------------------------------------------

	print	"Code end: $", pc
	warnpc	!EofAddress

	print	"EOF Addr: $", hex(!EofAddress)


