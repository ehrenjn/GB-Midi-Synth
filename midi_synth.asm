include "hardware.inc"
include "GB Midi Synth/header.inc"
include "GB Midi Synth/serial_queue.asm"

section "midi variables", WRAM0 

rNEXT_BYTE_TYPE: ds 1 ;to keep track of whether the next byte will be a frequency or velocity byte
rNEXT_NOTE_TYPE: ds 1 ;to keep track of what kind of data the next note will contain
rNEXT_MIDI_FREQ: ds 1 ;to keep track of note frequency between recieving frequency byte and waiting for velocity byte
rCURRENT_MIDI_FREQ: ds 1 ;to keep track of the last note played so we know if a midi event corresponds to the currently played note or note

FREQ_BYTE equ 0 ;would make this an enum but theres doesn't seem to be enums in rgbasm
VEL_BYTE equ 1

NOTE_ON_CMD equ $90 ;midi values for different commands
NOTE_OFF_CMD equ $80


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
    jr .loop


init_audio:

    push af

    ld a, 0
    ld [rNR10], a ;no sweep time, no sweep increase decrease
    ld a, %10000000 
    ld [rNR11], a ;50% duty cycle, 0 sound length (since we'll be flipping the audio on and off using bit 6 of NR14)

    pop af
ret


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
	ld a, %11110000 ;bit mask to get command nybble
	and a, e ;get rid of channel nybble, keep command nybble
	ld [rNEXT_NOTE_TYPE], a ;so we know how to play the note when the time comes
	ld a, FREQ_BYTE ;next byte will be a frequency byte
	ld [rNEXT_BYTE_TYPE], a ;update the next byte type
	jr .return

.parse_freq_byte
    ld hl, rNEXT_MIDI_FREQ ;don't actually parse the freq byte yet
    ld [hl], e ;just set it up so play_note can parse it later
	ld a, VEL_BYTE ;next byte will be a velocity byte
	ld [rNEXT_BYTE_TYPE], a ;update the next byte type
	jr .return

.parse_vel_byte
	ld a, [rNEXT_NOTE_TYPE] ;check NEXT_NOTE_TYPE
    cp NOTE_OFF_CMD 
    call z, note_off ;if it's a note off command, call note off
    cp NOTE_ON_CMD ;if it's a note on command, call note on
    call z, note_on
	jr .return

.return
	pop de
	pop bc
	pop hl
	pop af
ret


;param E: a midi velocity byte
note_on:

	push af
	push bc
    push hl
    push de

;update volume of tone generator with velocity byte
	ld b, %01111000 ;bit mask to scale velocity to 4 bits
	ld a, e ;so we can do an and operation on the velocity byte
	and a, b
    sla a ;shift bits left by one so velocity is top 4 bits of A
	ld [rNR12], a ;update volume (lo nybble can just stay 0 since we're not using any volume envelope)

;update lo frequency bits of square tone generator 
    ld hl, rNEXT_MIDI_FREQ
    ld e, [hl] ;using e so I can add hl and de
    ld d, 0 ;so de == e

    ld hl, rMIDI_FREQ_LUT_LO 
    add hl, de ;look up midi byte in lo lut
    ld a, [hl] ;convert midi byte to lo freq bits
    ld [rNR13], a ;set lo bits of frequency

;update hi frequency bits and play sound
    ld hl, rMIDI_FREQ_LUT_HI
    add hl, de ;look up midi byte in hi lut
    ld a, [hl] ;get hi bits

    ld b, %10000000 ;high bit 7 means note is restarted
    or a, b ;combine A and B (hi frequency and note on/off)
    ld [rNR14], a ;play the note

;update CURRENT_MIDI_FREQ
    ld hl, rCURRENT_MIDI_FREQ
    ld [hl], e
	
    pop de
    pop hl
	pop bc
	pop af
ret


note_off:

    push af
    push bc

    ld a, [rCURRENT_MIDI_FREQ] ;get the midi freq of the note currently being played
    ld b, a
    ld a, [rNEXT_MIDI_FREQ] ;get the midi freq of the note that's being turned off
    cp b ;check if the note being turned off is the note being played
    jr nz, .return ;don't turn off sound if the note being turned off is not the note being played

    ld a, 0
    ld [rNR12], a ;turn sound off by lowering volume to 0

.return
    pop bc
    pop af
ret


;look up tables to convert midi note frequencies to bits used in tone registers
rMIDI_FREQ_LUT_LO: 
    incbin "GB Midi Synth/midi_lut_lo"
rMIDI_FREQ_LUT_HI:
    incbin "GB Midi Synth/midi_lut_hi"