;------------------------------------------------------------------------------
; Stores current VIA interrupt handler so that it can be restored later and
; replaces it with our own.
;------------------------------------------------------------------------------
.setup_interrupt_handler
{
    SEI

    ; enable vsync interrupt
    LDA #%10000010
    STA VIA_INT_EN ; interrupt enable register

    ; Store old IRQ1V
    LDA IRQ1V
    STA old_irqv
    LDA IRQ1V+1
    STA old_irqv + 1

    ; Setup IRQ handler
    LDA #irq_handler MOD 256
    STA IRQ1V
    LDA #irq_handler DIV 256
    STA IRQ1V + 1

    CLI
    RTS    
}

;------------------------------------------------------------------------------
; Restores original VIA interrupt handler, replaced by setup_interrupt_handler.
;------------------------------------------------------------------------------
.restore_interrupt_handler
{
    SEI

    LDA old_irqv     : STA IRQ1V
    LDA old_irqv + 1 : STA IRQ1V + 1

    CLI
    RTS
}

;------------------------------------------------------------------------------
; On VSYNC interrupt, sets tick_flag to 1.
;------------------------------------------------------------------------------
.irq_handler
{
    LDA &FC
    PHA

    LDA VIA_INT_FLAG
    AND #%00000010 ; vsync interrupt flag
    BEQ irq_handler_done

    STA VIA_INT_FLAG ; clear interrupt flag

    ; set tick flag to 1 to vert refresh
    LDA #1
    STA tick_flag

    .irq_handler_done

    PLA
    STA &FC
    RTI
}

;------------------------------------------------------------------------------
; Waits for VSYNC interrupt by setting tick_flag to 0 and then polling for
; irq_handler to set it to 1.
;------------------------------------------------------------------------------
.wait_vsync
{
    LDA #0
    STA tick_flag
    .wait_loop
    LDA tick_flag
    BEQ wait_loop
    RTS
}
