; Select memory initialize table

PresetMemory1:
	incsrc	"PresetMemory/SMAS(J)_SMB3Debug.asm"

PresetMemory2:
	incsrc	"PresetMemory/Template.asm"

PresetMemory3:
	%BinPreset("PresetMemory/Template.bin")
