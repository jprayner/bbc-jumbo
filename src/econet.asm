;------------------------------------------------------------------------------
; Called by BASIC launcher Menu to start the application on a remote machine.
; This is done by performing two immediate (non-cooperative) operations: a POKE
; to load the app into memory — including its start args and message to be
; displayed — followed by a JSR to start it. Prior to calling.
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
  STA jsr_control_block_station

  JSR poke_app
  TXA
  AND #&40
  BNE done ; error poking app

  LDA #&10
  LDX #jsr_control_block MOD 256
  LDY #jsr_control_block DIV 256
  JSR OSWORD

  .done
  RTS
}

;------------------------------------------------------------------------------
; POKES the app into memory on the remote machine (from start to end),
; including its start args.
;   A:                  Econet station number
;------------------------------------------------------------------------------
.poke_app
{
  PHA
  STA poke_control_block_station

  ; configure for econet follower before poking so stations start in correct mode
  LDA run_mode
  PHA
  LDA #RUN_MODE_ECONET_FOLLOWER
  STA run_mode

  LDA #10
  STA econet_retries

  .retry_poke
  DEC econet_retries
  BEQ done

  .start_poke
  ; restore control byte which gets overwritten by OSWORD before retry
  LDA #&82
  STA poke_control_block_control_byte

  LDA #&10
  LDX #poke_control_block MOD 256
  LDY #poke_control_block DIV 256
  JSR OSWORD

  LDA poke_control_block_control_byte
  BEQ start_poke ; retry until started
  
  .wait_for_completion
  LDA #&32
  JSR OSBYTE
  TXA
  AND #%10000000
  BNE wait_for_completion

  ; check for non-fatal errors
  CPX #&41
  BEQ delay_and_retry
  CPX #&42
  BEQ delay_and_retry
  JMP done

  .delay_and_retry
  JSR delay
  JMP retry_poke

  .done
  PLA
  STA run_mode
  PLA
  RTS
}

;------------------------------------------------------------------------------
; Sends an Econet broadcast packet from the leader to kick off scrolling on all
; followers at the same time.
;------------------------------------------------------------------------------
.broadcast_start
{
  LDA #10
  STA econet_retries

  .retry_broadcast
  DEC econet_retries
  BEQ done

  .start_broadcast
  ; restore control byte which gets overwritten by OSWORD before retry
  LDA #&82
  STA broadcast_control_block_control_byte

  LDA #&10
  LDX #broadcast_control_block MOD 256
  LDY #broadcast_control_block DIV 256
  JSR OSWORD

  LDA broadcast_control_block_control_byte
  BEQ start_broadcast ; retry until started
  
  .wait_for_completion
  LDA #&32
  JSR OSBYTE
  TXA
  AND #%10000000
  BNE wait_for_completion

  ; check for non-fatal errors
  CPX #&41
  BEQ delay_and_retry
  CPX #&42
  BEQ delay_and_retry
  JMP done

  .delay_and_retry
  JSR delay
  JMP retry_broadcast

  .done
  RTS
}

;------------------------------------------------------------------------------
; Waits for an Econet broadcast packet from the leader before starting scroll
; on a follower.
;------------------------------------------------------------------------------
.wait_broadcast_start
{
  ; read JSR args and clear protection bits
  LDA #&12
  LDX #jsr_rx_control_block MOD 256
  LDY #jsr_rx_control_block DIV 256
  JSR OSWORD

  ; reenable interrupts
  CLI

  ; open receive block
  LDA #&00
  STA receive_control_block_control_byte

  LDA #&11
  LDX #receive_control_block MOD 256
  LDY #receive_control_block DIV 256
  JSR OSWORD

  ; note receive_control_block_control_byte now contains RX CB number

  ; poll receive block for reception 
  .wait_loop
  LDA #&33
  LDX receive_control_block_control_byte
  JSR OSBYTE
  TXA
  AND #%10000000
  BEQ wait_loop

  ; read control block back
  LDA #&11
  LDX #receive_control_block MOD 256
  LDY #receive_control_block DIV 256
  JSR OSWORD

  LDA #68
  JSR OSWRCH

  RTS
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