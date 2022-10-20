;--------------------------------------------------
; RAM Map
;--------------------------------------------------

includeonce

incsrc	"Include/IOName_Standard.asm"
incsrc	"Include/Library_Macro.asm"

pushpc

;--------------------------------------------------

!RAM_DMACH0	= !DMA_DMAP0				; Used by DMA
!RAM_DMACH1	= !DMA_DMAP1
!RAM_DMACH2	= !DMA_DMAP2
!RAM_DMACH3	= !DMA_DMAP3
!RAM_DMACH4	= !DMA_DMAP4
!RAM_DMACH5	= !DMA_DMAP5
!RAM_DMACH6	= !DMA_DMAP6
!RAM_DMACH7	= !DMA_DMAP7

%DefineRam(ScratchMemory,	!RAM_DMACH1, 11)
%DefineRam(StackUserExec,	!RAM_DMACH6, 11)
%DefineRam(Stack,		!RAM_DMACH7, 11)
!StackLength	= 10					; MEMO : Mesen-S cannot use $43xB unknown registers as stack (general purpose) memory.
							;        Works even at +11 on real machines and bsnes.
!Stack_Bottom		= !Stack+!StackLength
!StackUserExec_Bottom	= !StackUserExec+!StackLength

;--------------------------------------------------

	org	!RAM_DMACH2
%DefineRamNext(PadPrev,			2)		; High   +1, Low    +0
%DefineRamNext(PadPress,		2)		; BYsS udlr, AXLR 0123
%DefineRamNext(PadRepeatTimer,		1)
%DefineRamNext(AliveCounter,		1)
%DefineRamNext(JumpCursorAddress,	3)

	org	!RAM_DMACH3
%DefineRamNext(ScreenMode,		1)		; !ScreenID_xxx
%DefineRamNext(EditBaseAddress,		3)
%DefineRamNext(EditCursorAddress,	3)
%DefineRamNext(EditCursorOffset,	1)		; 0YYY XXXN
%DefineRamNext(EditCopyValue,		1)
%DefineRamNext(MenuCursorIndex,		1)

;--------------------------------------------------

pullpc

;--------------------------------------------------
; Constant definition
;--------------------------------------------------

!ScreenID_Edit		= 0
!ScreenID_Jump		= 1
!ScreenID_Menu		= 2
!ScreenID_MenuMessage	= 3
!ScreenID_RunCode	= 4

!MenuItemCount		= 6

!JumpAddressBarTile	#= 16
!JumpAddressBarWidth	#= !JumpAddressBarTile*8		; 128 [px]
!JumpAddressStep	#= 1					; [px]
!JumpAddressCount	#= !JumpAddressBarWidth/!JumpAddressStep; 128
!JumpAddressDistance	#= $20000/!JumpAddressCount		; 0x20000 [byte] / 128 [px] = 0x400
!JumpAddressMask	#= $1000000-!JumpAddressDistance	; $FFFC00
!JumpAddressShift	#= log2($20000/!JumpAddressBarWidth)	; 10

!Chr_MenuBlank		= $0F
!Chr_Cursor		= $EA
!Chr_JumpBar		= $D0

!RunCode_StackPointer	= $01FF

!KeyRepeat_Wait		= 20
!KeyRepeat_Tick		= 3
!KeyRepeat_Reload	= !KeyRepeat_Wait-!KeyRepeat_Tick

;--------------------------------------------------
; VRAM Map
;--------------------------------------------------

; +-------------+-----------------------+
; | ADDRESS     | 			|
; +-------------+-----------------------+
; | $0000-$0FFF | Layer 1 Tilemap	|
; | $1000-$1FFF | Layer 2 Tilemap	|
; | $2000-$3FFF | Unused		|
; | $4000-$5FFF | Unused		|
; | $6000-$7FFF | Unused		|
; | $8000-$9FFF | Unused (Object GFX)	|
; | $A000-$BFFF | Unused		|
; | $C000-$DFFF | Layer 1&2 GFX (4bpp)	|
; | $E000-$FFFF | Unused		|
; +-------------+-----------------------+

!VRAM_Layer1Tilemap	= $0000
!VRAM_Layer2Tilemap	= $1000
!VRAM_CommonGraphics	= $C000


