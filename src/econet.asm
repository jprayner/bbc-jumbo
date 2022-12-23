;------------------------------------------------------------------------------
; Called by BASIC launcher Menu to start the application on a remote machine.
; This is done by performing two immediate (non-cooperative) operations: a POKE
; to load the app into memory — including its start args and message to be
; displayed — followed by a jsr to start it.
;
;   A:                  Econet station number
;   run_mode:           Should be set to RUN_MODE_ECONET_FOLLOWER
;   num_screens_delay:  How long this station is to wait before starting to
;                       scroll: first follower delayed by 1 screen, second by 2
;                       etc.
;   message:            Message to scroll, terminated by &0d.
;------------------------------------------------------------------------------
.launch_app_remote
{
  sta jsr_control_block_station

  jsr poke_app
  txa
  and #&40
  bne done ; error poking app

  lda #&10
  ldx #jsr_control_block MOD 256
  ldy #jsr_control_block DIV 256
  jsr OSWORD

  .done
  rts
}

;------------------------------------------------------------------------------
; POKES the app into memory on the remote machine (from start to end),
; including its start args.
;   A:                  Econet station number
;------------------------------------------------------------------------------
.poke_app
{
  pha
  sta poke_control_block_station

  ; configure for econet follower before poking so stations start in correct mode
  lda run_mode
  pha
  lda #RUN_MODE_ECONET_FOLLOWER
  sta run_mode

  lda #10
  sta econet_retries

  .retry_poke
  dec econet_retries
  beq done

  .start_poke
  ; restore control byte which gets overwritten by OSWORD before retry
  lda #&82
  sta poke_control_block_control_byte

  lda #&10
  ldx #poke_control_block MOD 256
  ldy #poke_control_block DIV 256
  jsr OSWORD

  lda poke_control_block_control_byte
  beq start_poke ; retry until started
  
  .wait_for_completion
  lda #&32
  jsr OSBYTE
  txa
  and #%10000000
  bne wait_for_completion

  ; check for non-fatal errors
  cpx #&41
  beq delay_and_retry
  cpx #&42
  beq delay_and_retry
  jmp done

  .delay_and_retry
  jsr delay
  jmp retry_poke

  .done
  pla 
  sta run_mode
  pla 
  rts
}

;------------------------------------------------------------------------------
; Sends an Econet broadcast packet from the leader to kick off scrolling on all
; followers at the same time.
;------------------------------------------------------------------------------
.broadcast_start
{
  lda #10
  sta econet_retries

  .retry_broadcast
  dec econet_retries
  beq done

  .start_broadcast
  ; restore control byte which gets overwritten by OSWORD before retry
  lda #&82
  sta broadcast_control_block_control_byte

  lda #&10
  ldx #broadcast_control_block MOD 256
  ldy #broadcast_control_block DIV 256
  jsr OSWORD

  lda broadcast_control_block_control_byte
  beq start_broadcast ; retry until started
  
  .wait_for_completion
  lda #&32
  jsr OSBYTE
  txa
  and #%10000000
  bne wait_for_completion

  ; check for non-fatal errors
  cpx #&41
  beq delay_and_retry
  cpx #&42
  beq delay_and_retry
  jmp done

  .delay_and_retry
  jsr delay
  jmp retry_broadcast

  .done
  rts
}

;------------------------------------------------------------------------------
; Waits for an Econet broadcast packet from the leader before starting scroll
; on a follower.
;------------------------------------------------------------------------------
.wait_broadcast_start
{
  ; read jsr args and clear protection bits
  lda #&12
  ldx #jsr_rx_control_block MOD 256
  ldy #jsr_rx_control_block DIV 256
  jsr OSWORD

  ; reenable interrupts
  cli

  ; open receive block
  lda #&00
  sta receive_control_block_control_byte

  lda #&11
  ldx #receive_control_block MOD 256
  ldy #receive_control_block DIV 256
  jsr OSWORD

  ; note receive_control_block_control_byte now contains RX CB number

  ; poll receive block for reception 
  .wait_loop
  lda #&33
  ldx receive_control_block_control_byte
  jsr OSBYTE
  txa
  and #%10000000
  beq wait_loop

  ; read control block back
  lda #&11
  ldx #receive_control_block MOD 256
  ldy #receive_control_block DIV 256
  jsr OSWORD

  lda #68
  jsr OSWRCH

  rts
}

.econet_retries
  SKIP 1

.poke_control_block
  .poke_control_block_control_byte
  EQUB &82
  .poke_control_block_port
  EQUB &00 ; TO CHECK
  .poke_control_block_station
  EQUB &00
  .poke_control_block_network ; TODO: check byte order
  EQUB &00
  .poke_control_block_start
  EQUD start
  .poke_control_block_end
  EQUD end
  .poke_control_block_remote_start
  EQUD start

.jsr_control_block
  EQUB &83
  EQUB &00
  .jsr_control_block_station
  EQUB &00
  .jsr_control_block_network
  EQUB &00
  .jsr_control_block_arg_start
  EQUD &00
  .jsr_control_block_arg_end
  EQUD &00
  .jsr_control_block_call_address
  EQUD start

.jsr_rx_control_block
  .jsr_rx_control_block_station
  EQUB &00
  .jsr_rx_control_block_network
  EQUB &00
  .jsr_rx_control_block_arg_start
  EQUD &00
  .jsr_rx_control_block_arg_end
  EQUD &00

.broadcast_control_block
  .broadcast_control_block_control_byte
  EQUB &80
  .broadcast_control_block_port
  EQUB &94
  .broadcast_control_block_station
  EQUB &FF
  .broadcast_control_block_network
  EQUB &FF
  .broadcast_control_block_data
  SKIP 8

.receive_control_block
  .receive_control_block_control_byte
  EQUB &00
  .receive_control_block_flag
  EQUB &7F
  .receive_control_block_port
  EQUB &94 ; match broadcast port
  .receive_control_block_station
  EQUB &00
  .receive_control_block_network
  EQUB &00
  .receive_control_block_buffer_start
  EQUD receive_data_start
  .receive_control_block_buffer_end
  EQUD receive_data_end

.receive_data_start
  SKIP 16
.receive_data_end