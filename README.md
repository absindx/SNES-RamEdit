# Ram edit  

![Use landscape](Images/UseLandscape.gif)

Utility ROM to change the main memory of SNES to any value and pass the value to other games.  
By using DMA registers as general-purpose RAM, it operates without overwriting the main memory.  

### Related  
[NES version](https://github.com/absindx/NES-RamEdit)  

## Assemble  
Assemble using asar.  

```shell
asar Main.asm RamEdit.sfc
```

[build.bat](build.bat) is available for windows.  

## Cartridge  
Burn to 512 KiB ROM cartridge.  
Flash cartridges such as FXPAK can also be used, but some initial values in memory will be overwritten by the firmware.  

## How to  
### Memory editing  

| Key                   | Description                                           |
|:----------------------|:------------------------------------------------------|
| D-Pad                 | Move cursor                                           |
| A                     | Increment the value at the cursor position            |
| B                     | Decrement the value at the cursor position            |
| X                     | Copy nibble at cursor position                        |
| Y                     | Pastes the copied nibble at the cursor position       |
| L                     | Move to previous page                                 |
| R                     | Move to next page                                     |
| Start                 | Open menu                                             |
| Select                | Open jump address                                     |

### Menu  

| Key                   | Description                                           |
|:----------------------|:------------------------------------------------------|
| D-Pad Up              | Move cursor up                                        |
| D-Pad Down            | Move cursor down                                      |
| A                     | Confirm                                               |
| B                     | Cancel (close menu)                                   |
| Start                 | Cancel (close menu)                                   |

#### Fill page  
Fill page (64 bytes) with value at cursor position.  

#### Fill all  
Fill all memory (0x20000 bytes) with the value at the cursor position.  

#### Preset memory  
Initialize to a pre-defined value.  
See also the `Preset memory` section below.  

#### Run cursor  
Execute the cursor position as the program start address.  
The registers are initialized with the following values.  

| Register      | Value                                 |
|:--------------|:--------------------------------------|
| A             | `$0000` (8bit)                        |
| X             | `$0000` (8bit)                        |
| Y             | `$0000` (8bit)                        |
| SP            | `$01FC` (return address is pushed)    |
| P             | `$36` (`nvMXdIZc e`)                  |
| D             | `$0000`                               |
| DB            | `$7E` or `$7F` (cursor bank)          |
| PB            | `$7E` or `$7F` (cursor bank)          |
| PC            | (cursor address)                      |

Use `RTL` instruction (`$6B`) to end execution.  
If the `BRK` (`$00`) or `COP` (`$02`) instruction is executed and a certain amount of time is exceeded,
it will be halted.  

### Jump address  
Jump the address in units larger than the edit screen.  

| Key                   | Description                                           |
|:----------------------|:------------------------------------------------------|
| D-Pad Left            | Move cursor left (backward 0x400 bytes)               |
| D-Pad Right           | Move cursor right (forward 0x400 bytes)               |
| A                     | Confirm                                               |
| B                     | Cancel (back to edit)                                 |
| Select                | Cancel (back to edit)                                 |

## Preset memory  
It has 3 presets that can initialize memory to specific values.  
Create `PresetMemory/blabla.asm` file and edit [PresetMemory.asm](PresetMemory.asm) file.  
Or edit the `RamEdit.sfc` file directly. (Slot1: 0x20000-0x3FFFF, Slot2: 0x40000-0x5FFFF, Slot3: 0x60000-0x7FFFF)  
As a sample, memory definition is set in slot 1 to enable SMB3 debug flag for the Super Mario All-Stars.  

## ToDo  
* Embedded assembler?  

## Warning  
Removing and inserting the cassette while the power is on may damage the SNES main unit.  
Use at your own risk.  

## License  
[MIT License](LICENSE).  
