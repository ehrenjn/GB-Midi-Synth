include "hardware.inc"
include "GB Midi Synth/header.inc"
include "GB Midi Synth/serial_queue.asm"

section "midi variables", WRAM0 

rNEXT_BYTE_TYPE: ds 1 ;to keep track of whether the next byte will be a frequency or velocity byte
rNEXT_NOTE_TYPE: ds 1 ;to keep track of what kind of data the next note will contain
rFREQ_HIGH_TEMP: ds 1 ;to keep track of the hi frequency bits (between set_freq and play_note)

FREQ_BYTE equ 0 ;would make this an enum but theres doesn't seem to be enums in rgbasm
VEL_BYTE equ 1

NOTE_ON equ $90 ;midi values for note on and note off commands
NOTE_OFF equ $80


section "main", ROM0[$150]

main:

    di 
    call init_serial
    call init_audio
    ld a, 0
    ld [rIF], a ;CLEAR INTERRUPT FLAGS!! (just in case)
    ei 

.loop
    check_serial() ;check if theres a new serial byte, update Z flag
    call nz, parse_midi_byte ;call parse_midi_byte if a new byte is recieved
    ;ld b, $90
    ;call parse_midi_byte
    ;ld b, %01000000
    ;call parse_midi_byte
    ;ld b, %01111111
    ;call parse_midi_byte
    jr .loop
.DELPLS
    halt 
    jr .DELPLS


init_audio:

    push af

    ld a, 0
    ld [rNR10], a ;no sweep time, no sweep increase decrease
    ld a, %10000000 
    ld [rNR11], a ;50% duty cycle, 0 sound length (since we'll be flipping the audio on and off using bit 6 of NR14)

    pop af
ret


;param A: a new midi byte
parse_midi_byte:

	push af
	push hl
	push bc
	push de
	
    get_serial_byte() ;retrieve the latest serial byte, store in b
	ld e, b ;save midi byte for later

;check what kind of midi byte it is, behave accordingly
	bit 7, b
	jr nz, .parse_command_byte ;if bit 7 of the midi byte is 1 then it's a command byte
	ld a, [rNEXT_BYTE_TYPE] ;we have to check next byte type if the midi byte begins with a 0
	cp FREQ_BYTE 
	jr z, .parse_freq_byte ;if the next byte is a freq byte, parse it as such
	cp VEL_BYTE
	jr z, .parse_vel_byte ;if the next byte is a velocity byte, parse it as such
	jr .return ;we should never get here but lets return just in case something weird happens

.parse_command_byte	
	ld b, %11110000 ;bit mask to get command nybble
	and a, b ;get rid of channel nybble, keep command nybble
	ld [rNEXT_NOTE_TYPE], a ;so we know how to play the note when the time comes
	ld a, FREQ_BYTE ;next byte will be a frequency byte
	ld [rNEXT_BYTE_TYPE], a ;update the next byte type
	jr .return

.parse_freq_byte
	call set_freq ;set frequency
	ld a, VEL_BYTE ;next byte will be a velocity byte
	ld [rNEXT_BYTE_TYPE], a ;update the next byte type
	jr .return

.parse_vel_byte
	call play_note
	jr .return

.return
	pop de
	pop bc
	pop hl
	pop af
ret


;param E: a midi velocity byte
play_note:

	push af
	push bc

	ld b, %01111000 ;bit mask to scale velocity to 4 bits
	ld a, e ;so we can do an and operation
	and a, b
    sla a ;shift bits left by one so velocity is top 4 bits of A
	ld [rNR12], a ;update volume (lo nybble can just stay 0 since we're not using any volume envelope)

	ld a, [rFREQ_HIGH_TEMP] ;get hi 3 bits of frequency
    ld b, %10000000 ;high bit 7 means note is restarted
    or a, b ;combine A and B
    ld [rNR14], a ;play the note
	
	pop bc
	pop af
ret


;param E: a midi note pitch
set_freq:
     
    push af
    push hl
    push de

    ld hl, rMIDI_FREQ_LUT_LO 
    ld d, 0 ;so I can add hl and e
    add hl, de ;look up midi byte in lo lut
    ld a, [hl] ;convert midi byte to lo freq bits
    ld [rNR13], a ;set lo bits of frequency

    ld hl, rMIDI_FREQ_LUT_HI
    add hl, de ;look up midi byte in hi lut
    ld a, [hl] ;get hi bits
    ld [rFREQ_HIGH_TEMP], a ;cant write hi freq bits to NR14 yet because I'm going to have to write other bits of NR14 later and freq bits are read only
   
    pop de
    pop hl
    pop af
ret


;look up tables to convert midi note frequencies to bits used in tone registers
rMIDI_FREQ_LUT_LO: 
    incbin "GB Midi Synth/midi_lut_lo"
rMIDI_FREQ_LUT_HI:
    incbin "GB Midi Synth/midi_lut_hi"