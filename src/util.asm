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

.wait_key
{
    SEI
        LDA #%11111111   ; enable all System VIA interrupts
        STA VIA_INT_EN
    CLI
    JSR OSRDCH
    SEI
        LDA #%01111111   ; disable all System VIA interrupts
        STA VIA_INT_EN
    CLI
    RTS
}
