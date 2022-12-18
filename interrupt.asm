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

.restore_interrupt_handler
{
    SEI

    LDA old_irqv     : STA IRQ1V
    LDA old_irqv + 1 : STA IRQ1V + 1

    CLI
    RTS
}

.irq_handler
{
    LDA &FC
    PHA

    LDA VIA_INT_FLAG ; System VIA interrupt flag register
    AND #%00000010 ; vsync interrupt flag
    BEQ irq_handler_done

    STA VIA_INT_FLAG ; clear flag

    ; set tick flag to 1 to vert refresh
    LDA #1
    STA tick_flag

    .irq_handler_done

    PLA
    STA &FC
    RTI
}