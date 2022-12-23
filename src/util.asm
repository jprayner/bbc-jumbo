;------------------------------------------------------------------------------
; Implements a short delay, useful for Econet retries or slowing things down
; during debugging.
;------------------------------------------------------------------------------
.delay
{
    pha
    lda #$00
    sta temp  ; high byte
    .delay_loop
    adc #01
    bne delay_loop
    clc
    inc temp
    bne delay_loop
    clc
    pla 
    rts
}

;------------------------------------------------------------------------------
; Waits for any keypress. Does so by temporarily enabling System VIA interrups,
; calling OSRDCH, and then disabling the interrupts again. Useful for debugging
; purposes.
;------------------------------------------------------------------------------
.wait_key
{
    sei
        lda #%11111111   ; enable all System VIA interrupts
        sta VIA_INT_EN
    cli
    jsr OSRDCH
    sei
        lda #%01111101   ; disable all System VIA interrupts (except VSYNC)
        sta VIA_INT_EN
    cli
    rts
}
