;------------------------------------------------------------------------------
; Implements a short delay, useful for Econet retries or slowing things down
; during debugging.
;------------------------------------------------------------------------------
.delay
{
    PHA
    LDA #$00
    STA temp  ; high byte
    .delay_loop
    ADC #01
    BNE delay_loop
    CLC
    INC temp
    BNE delay_loop
    CLC
    PLA
    RTS
}

;------------------------------------------------------------------------------
; Waits for any keypress. Does so by temporarily enabling System VIA interrups,
; calling OSRDCH, and then disabling the interrupts again. Useful for debugging
; purposes.
;------------------------------------------------------------------------------
.wait_key
{
    SEI
        LDA #%11111111   ; enable all System VIA interrupts
        STA VIA_INT_EN
    CLI
    JSR OSRDCH
    SEI
        LDA #%01111101   ; disable all System VIA interrupts (except VSYNC)
        STA VIA_INT_EN
    CLI
    RTS
}
