include "hardware.inc"

section "queue variables", WRAM0
QUEUE: ds 256 ;make the queue 256 large so it wraps itself using overflow
rHEAD: ds 1
rTAIL: ds 1

section "serial interrupt", ROM0[$0058]
    jp serial_interrupt


section "serial queue functions", ROM0 ;NEED TO PUT THIS IN THE RIGHT SPOT (after header) otherwise it'll try to put it between the interrupts and the header


;clobbers A and B
;F.z == 0 if there is a new serial byte, F.z == 1 if there is no new serial byte
check_serial: macro
    ld a, [rHEAD]
    ld b, a
    ld a, [rTAIL]
    cp b
endm


;do NOT call this before checking if there is a new serial byte using check_serial()
;clobbers B, C, H and L
;returns the new serial byte in B
get_serial_byte: macro
    ld hl, rTAIL ;load into hl because I'm going to use rTAIL twice
    ld c, [hl] ;get latest byte
    inc [hl] ;move tail forward
    ld b, 0 ;so I can add HL and BC
    ld hl, QUEUE
    add hl, bc ;hl = QUEUE[bc] = QUEUE[TAIL]
    ld b, [hl] ;b = QUEUE[TAIL]
endm


init_serial:
 
    push af
    push hl
 
    ld a, %10000000 ;external serial clock, normal speed, SET THE BEGIN TRANSFER BIT SO I CAN RECIEVE DATA (begin transfer bit really just means "when the serial clock ticks, latch/send data")
    ld [rSC], a

    ld a, 0
    ld [rHEAD], a
    ld [rTAIL], a ;clear head and tail
 
    ld hl, rIE
    set 3, [hl] ;enable serial interrupt
 
    pop hl
    pop af
ret


serial_interrupt:

    push af
    push bc
    push de
    push hl
 
    ld a, [rSB] ;get the recieved serial data
    ld d, a ;save data for later
    ld a, [rHEAD]
    ld c, a ;save head for later
    ld a, [rTAIL]
    dec a
    cp c
    jr z, .return ;don't insert any data if tail - 1 = head
    
    ld hl, QUEUE
    ld b, 0 ;so I can add bc to hl and get the address to put the data into
    add hl, bc ;set hl to QUEUE[HEAD] (the location we want to put the data)
    ld [hl], d ;load data into hl

    ld hl, rHEAD
    inc [hl] ;move head forward

.return
    ld hl, rSC
    set 7, [hl] ;BEGIN SERIAL TRANSFER AGIAN so that when the external clock ticks I recieve more data

    pop hl
    pop de
    pop bc
    pop af
reti

