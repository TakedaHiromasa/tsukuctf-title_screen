.setcpu		"6502"
.autoimport	on

PPU_ADDR1	=	$0001
PPU_ADDR2	=	$0002

PPU_STATUS  =   $2002

; iNESヘッダ
.segment "HEADER"
	.byte	$4E, $45, $53, $1A  ; "NES" Header
	.byte	$02                 ; PRG-BANKS
	.byte	$01                 ; CHR-BANKS
	.byte	$01                 ; Vetrical Mirror
	.byte	$00                 ;
	.byte	$00, $00, $00, $00  ; 予約領域
	.byte	$00, $00, $00, $00  ; 予約領域

.segment "STARTUP"
; リセット割り込み
.proc	Reset
	; CPUの各レジスタとフラグを初期化
	sei             ; 割り込みを無効にする
	ldx #$ff
	txs             ; スタックポインタを初期化
	clc             ; キャリーフラグをクリア
	cld             ; 10進モードフラグをクリア
	
	; PPU関連の初期化
	lda #$00
	sta $2000       ; PPU制御レジスタ1
	sta $2001       ; PPU制御レジスタ2
	sta $2005       ; スクロールオフセット
	sta $2006       ; PPUアドレス
	
	; サウンド関連の初期化
	lda $4015       ; サウンド制御レジスタ
	and #%11111110  ; 最下位ビットをクリアして全てのチャンネルを無効化
	sta $4015
	; == 初期化ここまで ==

; スクリーンオフ
	lda PPU_STATUS
	lda	#$00
	sta	$2000
	sta	$2001

; メモリクリア
	lda #$00
	ldx #$00
clear_memory:
	sta $0000, X
	sta $0100, X
	sta $0200, X
	sta $0300, X
	sta $0400, X
	sta $0500, X
	sta $0600, X
	sta $0700, X
	inx
	cpx #$00
	bne clear_memory

; VRAM クリア
	lda #$20   ; ネームテーブル1の先頭アドレスの上位バイト
	sta $2006  ; 上位アドレスを設定
	lda #$00   ; ネームテーブル1の先頭アドレスの下位バイト
	sta $2006  ; 下位アドレスを設定
	lda #$00   ; クリアするデータ（0x00）
	ldx #$00   ; Xレジスタを0に設定
	ldy #$04   ; Yレジスタを4に設定（4回の256バイトブロックで1024バイト）

clear_vram_loop:
	sta $2007           ; VRAMに0x00を書き込む
	inx                 ; Xをインクリメント
	bne clear_vram_loop ; Xが0に戻るまでループ（256バイト）
	dey                 ; Yをデクリメント
	bne clear_vram_loop ; Yが0になるまでループ（1024バイト）

; パレットテーブルへ転送(BG用のみ転送)
	lda	#$3F   ; [0x3F00-0x3F0F]BGパレットテーブル
	sta	$2006  ; VRAMアドレスレジスタ
	lda	#$00   ; [0x3F00-0x3F0F]BGパレットテーブル
	sta	$2006  ; VRAMアドレスレジスタ
	ldx	#$00   ; Xに00
	ldy	#$10   ; Yに10(DEC 16)

setpal:
	lda	palettes, x   ; Aに(palettes + x)の値をロードする。
	sta	$2007         ; $2007にパレットの値を読み込む
	inx               ; X++
	dey               ; Y--
	bne	setpal        ; 上が0でない場合は、loadPalラベルの位置にジャンプする
	
; ネームテーブルへ転送
	lda	#$20
	sta	$2006
	lda	#$00
	sta	$2006

	ldy #0
	jsr set_row

	jmp mapping1

mapping1:
	ldy	#11
	ldx	#$00
	lda	#$8c  ; ブロック
mapping1_y_loop:

	jsr set_row

	ldx #05
	jsr set_col

	ldx #$14
mapping1_x_loop:
	sta	$2007
	dex
	bne	mapping1_x_loop

	iny
	cpy #16
	bne mapping1_y_loop


mapping2:
	ldy	#13
	jsr set_row

	ldx #08
	jsr set_col

	ldx #00
	ldy #14
mapping2_x_loop:
	lda	data, x
	sta	$2007
	inx
	dey
	bne	mapping2_x_loop


screenend:

; スクロール設定
	lda	#$00
	sta	$2005
	sta	$2005

; スクリーンオン
	lda	#$08   ; [#%0000 1000] PPUコントロset
	sta	$2000  ; PPUコントロレジ1
	lda	#$1e   ; [#%0001 1110] PPUコントロset
	sta	$2001  ; PPUコントロレジ2

; 無限ループ
loop:
	jmp	loop

; Yに0~29行のDECを指定
set_row:
	pha  ; Aをスタックへpush

	tya
	lsr a
	lsr a
	lsr a
	clc
	adc #$20
	sta	PPU_ADDR1

	; 下位バイト計算
	tya
	asl a
	asl a
	asl a
	asl a
	asl a
	sta	PPU_ADDR2

	lda	PPU_ADDR1
	sta	$2006
	lda	PPU_ADDR2
	sta	$2006

	pla  ; スタックからAへpull
	rts

; Xに0~30列のDECを指定
set_col:
	pha  ; Aをスタックへpush

	txa
	adc PPU_ADDR2
	sta	PPU_ADDR2

	lda	PPU_ADDR1
	sta	$2006
	lda	PPU_ADDR2
	sta	$2006

	pla  ; スタックからAへpull
	rts

.endproc

; パレットテーブル
palettes:
	;.incbin "character.dat"
	.byte	$01, $18, $39, $30
	.byte	$0f, $06, $16, $26
	.byte	$0f, $08, $18, $28
	.byte	$0f, $0a, $1a, $2a

; 表示文字列
data:
	; .byte	"Tsukushi_Quest"
	.byte	$22, $a4, $39, $26, $39
	.byte	$a4, $55, $79, $bb, $4c
	.byte	$39, $c7, $a4, $d1, $8c

.segment "VECINFO"
	.word	$0000
	.word	Reset
	.word	$0000

.segment "CHARS"
	.incbin "character.chr"