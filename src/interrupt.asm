;------------------------------------------------------------------------------
.setup_interrupt_handler
;   Stores current VIA interrupt handler so that it can be restored later and
;   replaces it with our own.
;------------------------------------------------------------------------------
{
    sei

    ; enable vsync interrupt
    lda #%10000010
    sta VIA_INT_EN ; interrupt enable register

    ; Store old IRQ1V
    lda IRQ1V
    sta old_irqv
    lda IRQ1V+1
    sta old_irqv + 1

    ; Setup IRQ handler
    lda #irq_handler MOD 256
    sta IRQ1V
    lda #irq_handler DIV 256
    sta IRQ1V + 1

    cli
    rts    
}

;------------------------------------------------------------------------------
.restore_interrupt_handler
;   Restores original VIA interrupt handler, previously replaced by
;   setup_interrupt_handler.
;------------------------------------------------------------------------------
{
    sei

    lda old_irqv     : sta IRQ1V
    lda old_irqv + 1 : sta IRQ1V + 1

    cli
    rts
}

;------------------------------------------------------------------------------
.irq_handler
;   On VSYNC interrupt sets tick_flag to 1.
;------------------------------------------------------------------------------
{
    lda &FC
    pha

    lda VIA_INT_FLAG
    and #%00000010 ; vsync interrupt flag
    beq irq_handler_done

    sta VIA_INT_FLAG ; clear interrupt flag

    ; set tick flag to 1 to vert refresh
    lda #1
    sta tick_flag

    .irq_handler_done

    pla 
    sta &FC
    RTI
}

;------------------------------------------------------------------------------
.wait_vsync
;   Waits for VSYNC interrupt by setting tick_flag to 0 and then polling for
;   irq_handler to set it to 1.
;------------------------------------------------------------------------------
{
    lda #0
    sta tick_flag
    .wait_loop
    lda tick_flag
    beq wait_loop
    rts
}
