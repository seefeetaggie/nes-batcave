; This game displays an animated bat flying.

; Bat animation from spritesheet found within Heartbeast Action RPG tutorial
; https://github.com/uheartbeast/youtube-tutorials/blob/master/Action%20RPG/Enemies/Bat.png
; Bat recolored for NES palette

; Enable debugging info
.debuginfo

.code
; FamiStudio audio driver configuration
FAMISTUDIO_CFG_EXTERNAL       = 1
FAMISTUDIO_CFG_DPCM_SUPPORT   = 1
FAMISTUDIO_CFG_SFX_SUPPORT    = 1 
FAMISTUDIO_CFG_SFX_STREAMS    = 2
FAMISTUDIO_CFG_EQUALIZER      = 1
FAMISTUDIO_USE_VOLUME_TRACK   = 1
FAMISTUDIO_USE_PITCH_TRACK    = 1
FAMISTUDIO_USE_SLIDE_NOTES    = 1
FAMISTUDIO_USE_VIBRATO        = 1
FAMISTUDIO_USE_ARPEGGIO       = 1
FAMISTUDIO_CFG_SMOOTH_VIBRATO = 1
FAMISTUDIO_USE_RELEASE_NOTES  = 1
FAMISTUDIO_DPCM_OFF           = $e000
.define FAMISTUDIO_CA65_ZP_SEGMENT   ZEROPAGE
.define FAMISTUDIO_CA65_RAM_SEGMENT  BSS
.define FAMISTUDIO_CA65_CODE_SEGMENT CODE
.include "famistudio_ca65.s"
.include "sounds.s"

; Store global variables in zero page for easy access
.zeropage

; The horizontal distance in pixels of the bat from the left edge of the screen
bat_fly_x:      .res 1
; The vertical distance in pixels of the bat from the top edge of the screen
bat_fly_y:      .res 1
; The frame number (0 through 4) of the bat animation to display
bat_fly_frame:  .res 1
; countdown
countdown_bat:  .res 1
button: .res 1
bat_flap: .res 1
;if zero bat faces right, if one bat faces left
flip_count: .res 1

.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr 0

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segment for the program
.code

reset:
  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx $4017	; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs		;  .
  inx		; now X = 0
  stx $2000	  ; disable NMI
  stx $2001 	; disable rendering
  stx $4010 	; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit $2002
  bpl vblankwait1

;; second wait for vblank, PPU is ready after this
vblankwait2:
  bit $2002
  bpl vblankwait2

main:

enable_rendering:
  lda #%10000000	; Enable NMI
  sta $2000
  lda #%00011110	; Enable background and sprites
  sta $2001

; initialize values of variables
  lda #$00
  sta bat_fly_x
  lda #$70
  sta bat_fly_y
  lda #$00
  sta bat_fly_frame
  lda #$08
  sta countdown_bat
  lda #$08
  sta bat_flap

; initialize FamiStudio
  lda FAMISTUDIO_CFG_NTSC_SUPPORT
  ldx #$00
  ldy #$00
  jsr famistudio_init
; initialize FamiStudio sound effects
  ldx #<sounds
  ldy #>sounds
  jsr famistudio_sfx_init


forever:
  jmp forever

nmi:
; This is called when vertical blank starts after each frame is drawn,
; or 60 times every second

  lda $2002
  ; set background color
  lda #$3F
  sta $2006
  lda #$00
  sta $2006
  lda #$06
  sta $2007

  ; set sprite palette 0
  lda #$3F
  sta $2006
  lda #$11
  sta $2006
  lda #$0F
  sta $2007
  lda #$04
  sta $2007
  lda #$14
  sta $2007

; Set PPU to start of Object Attribute Memory (OAM)
  lda #$00
  sta $2003

; all zeros for blank sprites
  lda #$00
; number of bytes since each sprite takes four bytes and there are two of them  
  ldx #$08
blank_sprite_loop:
  sta $2004
  dex
  bne blank_sprite_loop

; bat wing upper left
  lda bat_fly_y
  sta $2004
  lda bat_fly_frame
  asl A
  clc
  adc #$02
  adc flip_count
  sta $2004
  lda flip_count
  clc
  ror a 
  ror a 
  ror a
  sta $2004
  lda bat_fly_x
  sta $2004

; bat head upper right
  lda bat_fly_y
  sta $2004
  lda bat_fly_frame
  asl A
  clc
  adc #$03
  sec 
  sbc flip_count
  sta $2004
  lda flip_count
  clc
  ror a 
  ror a 
  ror a
  sta $2004
  lda bat_fly_x
  clc
  adc #$08
  sta $2004

; bat wings lower left
  lda bat_fly_y
  clc
  adc #$08
  sta $2004
  lda bat_fly_frame
  asl A
  clc
  adc #$12
  adc flip_count
  sta $2004
  lda flip_count
  clc
  ror a 
  ror a 
  ror a
  sta $2004
  lda bat_fly_x
  sta $2004

; bat wings lower right
  lda bat_fly_y
  clc
  adc #$08
  sta $2004
  lda bat_fly_frame
  asl A
  clc
  adc #$13
  sec 
  sbc flip_count
  sta $2004
  lda flip_count
  clc
  ror a 
  ror a 
  ror a
  sta $2004
  lda bat_fly_x
  clc
  adc #$08
  sta $2004

  dec countdown_bat
  bne fly 
;change image
  lda bat_flap
  sta countdown_bat
  ldx bat_fly_frame
  inx
  cpx #$05
  bne batmovement
  ; play wing flap sound
  lda #$00
  ldx #FAMISTUDIO_SFX_CH0
  jsr famistudio_sfx_play
  ldx #$00
batmovement:
  stx bat_fly_frame


fly:

; read controller
  lda #$01
  sta button
  sta $4016
  lda #$00
  sta $4016
start_me:
  lda $4016
  lsr a
  rol button
  bcc start_me
up:
; check W
  lda button
  and #%00001000
  beq right
;bat go up
  dec bat_fly_y
  

right:

  lda button
  and #%00000001
  beq right_next 
;bat go right
  inc bat_fly_x
  lda #$05
  sta bat_flap
  lda #$00
  sta flip_count
  jmp flap_speed_right

right_next:
  lda #$08
  sta bat_flap


flap_speed_right:
  
left:

  lda button
  and #%00000010
  beq left_next 
;bat go left
  dec bat_fly_x
  lda #$05
  sta bat_flap
  lda #$01
  sta flip_count

left_next:



down:

  lda button
  and #%00000100
  beq down_next
;bat go down
  lda countdown_bat
  ror a 
  bcc down_speed
  inc bat_fly_y
down_speed:
  lda #$0A
  sta bat_flap
  lda #$03
  sta bat_fly_frame


down_next:



flip:

  ; run the sound engine
  jsr famistudio_update

; end of the nmi (vblank) handler
  rti

.segment "CHARS"
  ; Include the CHR ROM that has the different tiles available.
  .incbin "batcave.chr"
