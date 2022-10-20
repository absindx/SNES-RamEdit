.Start
	fillbyte	$00
	fill		$20000
	pushpc

;--------------------------------------------------
; Define here

	; .shotm, .shortx
	;23CCB0:	LDA	$0160
	;23CCB3:	CMP.b	#$80
	;23CCB5:	BNE	$23CCE0	; debug routine

	; $7E0160 = $80
	org	.Start+$00160
	db	$80

;--------------------------------------------------

	pullpc
