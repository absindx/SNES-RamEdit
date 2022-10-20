;--------------------------------------------------
; Library macro
;--------------------------------------------------

includeonce

;--------------------------------------------------
; System

; Usage:
;   %DefineRam(ScratchMemory, $0000, 16)
;   LDA.b	!ScratchMemory	; $00
macro	DefineRam(name, addr, size)
	pushpc
	org <addr>
	<name>:		skip <size>
	!<name>		= <name>
	pullpc
endmacro
macro	DefineRamNext(name, size)
	<name>:		skip <size>
	!<name>		= <name>
endmacro

; Usage:
;   !WordVariable	= $0100
;   %DefineWord(WordVariable)
;   LDA.b	!WordVariableL	; $0100
;   LDX.b	!WordVariableH	; $0101
macro	DefineWord(name)
	!<name>L	= !<name>+0
	!<name>H	= !<name>+1
endmacro

; Usage:
;   %DefineLocal(Temp, !ScratchMemory+0, 1)
;   LDA.b	.Temp	; $00
macro	DefineLocal(name, addr, size)
	pushpc
	org <addr>
	.<name>	skip <size>
	pullpc
endmacro


