ROMADR		EQU	04000H	;ROMの開始アドレス

NDPWKADR	EQU	0E800H	;NDPワークエリアの開始アドレス

HTIMI	EQU	0FD9FH	;タイマ割り込みフック
WSIZE	EQU	61	;各トラックのワークエリアのサイズ
RWSIZE	EQU	5*4	;各トラックのリピート用ワークエリアのサイズ (1ネストあたりのサイズ*ネスト数)F
CHNUM	EQU	4	;使用チャンネル数


CALSLT	EQU 001Ch
ENASLT	EQU	0024h
INIFNK	EQU 003EH
CHPUT	EQU 00A2H
CLS		EQU 00C3H

CSRY	EQU 0F3DCH
CSRX	EQU 0F3DDH
FNKSTR	EQU	0F87Fh
HIMEM	EQU	0FC4Ah

;============================================================== ROMヘッダー
	ORG ROMADR

	DB	'A','B'
	DW	ROMMAIN	; INIT
	DW	0	; STATMENT
	DW	0	; DEVICE
	DW	0	; TEXT
	DS	10H-0AH,0

;==============================================================
;---------------------------------------- ROM プログラム
ROMMAIN:
	DI
	LD  (SPBACKUP),SP
	LD  SP,(HIMEM)
	CALL GET_PAGE1_SLOT
	LD  (MYSLOT_P1),A

	LD  A,(MYSLOT_P1)
	LD  HL,8000h
	CALL ENASLT			; ROM後半=PAGE2(8000h-) を ROMのスロットに切り替え
	EI

	CALL ROM_MAIN1	; メインプログラム

	DI
	LD  SP,(SPBACKUP)
	EI
	CALL INIFNK		
	RET

;---------------------------------------- ROM自身がどのスロットにあるか
GET_PAGE1_SLOT:
	; Page1 Base-Slot Detection
	IN  A,(0A8h)
	AND A,0Ch
	RRCA
	RRCA
	PUSH AF
	
	; Page1 Expand-Slot Detection
	LD  B,A
	ADD A,0C1h
	LD  L,A
	LD  H,0FCh
	LD  A,(HL)
	AND A,80h
	JP  Z,GET_PAGE1_SLOT_SKIP1
	
	LD  A,B
	RRCA
	RRCA
	LD  B,A
	IN  A,(0A8h)
	LD  C,A
	AND A,3Fh
	OR  A,B
	DI
	OUT (0A8h),A
	LD  A,(0FFFFh)
	LD  B,A
	LD  A,C
	OUT (0A8h),A
	EI
	LD  A,B
	CPL
	AND A,0Ch
	OR  A,80h
GET_PAGE1_SLOT_SKIP1:
	POP BC
	OR  A,B
	RET

;---------------------------------------- メッセージ出力
SCRINI:
	XOR  A
	CALL CLS		; 画面クリア

	LD  HL,MSG001
	CALL PUTSYX		; "MSXNDP"

	CALL SYSVER		; VER H.L
	LD  A,H
	CALL PUTSHEX
	LD  A,'.'
	CALL CHPUT
	LD  A,L
	CALL PUTSHEX
	RET

;----------------------- Aの値を画面出力（HEX）
PUTSHEX:
	PUSH HL
	LD  E,A
	RRCA
	RRCA
	RRCA
	RRCA
	CALL PUTSHEX_CHAR
	LD  A,E
	CALL PUTSHEX_CHAR

	POP HL
	RET

PUTSHEX_CHAR:
	AND 0Fh
	CP  0Ah
	JR  C,PUTSHEX_CHAR_A
	ADD A,'A'-':'
PUTSHEX_CHAR_A:
	ADD A,'0'
	CALL CHPUT
	RET
	
;----------------------- Y,X 指定して文字列出力
PUTSYX:
	LD  A,(HL)
	LD  (CSRY),A
	INC HL
	LD  A,(HL)
	LD  (CSRX),A
	INC HL
PUTSYX_LOOP:
	LD  A,(HL)
	OR  A
	RET Z
	CALL CHPUT
	INC HL
	JR  PUTSYX_LOOP
;-----------------------
MSG001:
	DB  1	; Y
	DB  1	; X
	DB	"MSXNDP ",0


;==============================================================
; NDP 関連を含むメインプログラム
;==============================================================
;---------------------------------------- ROM メインプログラム
ROM_MAIN1:
	CALL SCRINI

;-------------------------------------------
	CALL NDPINI_ROM_INI		; 初期化＆ NDPフック接続

;------------- 曲１再生
	DI
	LD  DE,MUSDAT1
    CALL ADRSET
	CALL MSTART
ROM_MAIN1_LOOP1:
	EI
    HALT
	CALL RDLOOP
	OR  A
    JR  Z,ROM_MAIN1_LOOP1
	CALL MSTOP

;------------- 曲２再生
	DI
	LD  DE,MUSDAT2
    CALL ADRSET
	CALL MSTART
ROM_MAIN1_LOOP2:
	EI
    HALT
	CALL RDLOOP
	OR  A
    JR  Z,ROM_MAIN1_LOOP2
	CALL MSTOP

;-------------
	CALL NDPOFF
	RET

;==============================================================
; NDP 関連を含むサブプログラム
;==============================================================
;------	音程テーブル用データ
PTABLE_DAT:
;		c     c+    d     d+    e     f     f+    g     g+    a     a+    b
	DW	0D5DH,0C9CH,0BE7H,0B3CH,0A9BH,0A02H,0973H,08EBH,086BH,07F2H,0780H,0714H	;O1
	DW	06AFH,064EH,05F4H,059EH,054EH,0501H,04BAH,0476H,0436H,03F9H,03C0H,038AH	;O2
	DW	0357H,0327H,02FAH,02CFH,02A7H,0281H,025DH,023BH,021BH,01FDH,01E0H,01C5H	;O3
	DW	01ACH,0194H,017DH,0168H,0153H,0140H,012EH,011DH,010DH,00FEH,00F0H,00E3H	;O4
	DW	00D6H,00CAH,00BEH,00B4H,00AAH,00A0H,0097H,008FH,0087H,007FH,0078H,0071H	;O5
	DW	006BH,0065H,005FH,005AH,0055H,0050H,004CH,0047H,0043H,0040H,003CH,0039H	;O6
	DW	0035H,0032H,0030H,002DH,002AH,0028H,0026H,0024H,0022H,0020H,001EH,001CH	;O7
	DW	001BH,0019H,0018H,0016H,0015H,0014H,0013H,0012H,0011H,0010H,000FH,000EH	;O8
PTABLE_DAT_END:

;----------------------------------
;------	初期化＆ NDPフック接続
NDPINI_ROM_INI:
	XOR A
	LD  HL,CH1WRK
	LD  (HL),A
	LD  DE,CH1WRK+1
	LD  BC,BGMADR - CH1WRK - 1
	LDIR							; ★ワークエリアをゼロクリアしないと正しく再生されない？

	XOR A
	LD  HL,VADTBL
	LD  (HL),A
	LD  DE,VADTBL+1
	LD  BC,MCLRST - VADTBL - 1
	LDIR							; ★ワークエリアをゼロクリアしないと正しく再生されない？

	LD  HL,PTABLE_DAT
	LD  DE,PTABLE
	LD  BC,PTABLE_DAT_END - PTABLE_DAT - 1
	LDIR			; 音程テーブル用データの転送

	XOR A
	CALL SETHF		; フック接続前に、ドライバ接続済みフラグの初期化

;----------------------------------
;------	フック接続（ROM用にカスタム）
NDPINI_R:
	DI

	LD	A,(HKFLG)	;簡易的な多重実行対策
	OR	A
	RET	NZ

	LD	HL,HTIMI
	LD	DE,OLDTH
	LD	BC,5
	LDIR

	;----------------------------------------
;	LD	A,0C3H		;JP
;	LD	HL,INTRPT	;ドライバ割り込みルーチンアドレス
;	LD	(HTIMI),A
;	LD	(HTIMI+1),HL
	;---------------------------------------- インタースロットコールする
	LD	A,0F7h		;RST 30h
	LD	HL,INTRPT	;ドライバ割り込みルーチンアドレス
	LD	(HTIMI+0),A
	LD	A,(MYSLOT_P1)	;ROM スロット
	LD	(HTIMI+1),A
	LD	(HTIMI+2),HL
	LD	A,0C9h		;RET
	LD	(HTIMI+4),A
	;----------------------------------------

	LD	A,1
;SETHF:
	LD	(HKFLG),A

	EI
	RET
	
;==============================================================
;-------------------------------------------

	DS  04800h-$-ROMADR,0C9h

;==============================================================
; NDPドライバをINCLUDE
;==============================================================
;---------------------------------- この辺はページ１
ROM4800h:
INCLUDE "NDP_DRV.ASM"

;-------------------------------------------
	DS  06000h-$-ROMADR,0C9h


;==============================================================
; 以降は曲データ	
;==============================================================
;---------------------------------- この辺はページ１
ROM6000h:
MUSDAT1:	; 曲データ１
	DB	00Eh, 000h, 013h, 000h, 042h, 000h, 071h, 000h, 075h, 000h, 000h, 001h, 055h, 000h, 0BFh, 000h
	DB	0FFh, 000h, 000h, 060h, 087h, 0FFh, 072h, 02Eh, 03Ch, 02Ah, 03Ch, 02Ch, 03Ch, 025h, 078h, 000h
	DB	03Ch, 025h, 03Ch, 02Ch, 03Ch, 02Eh, 03Ch, 02Ah, 078h, 000h, 03Ch, 02Ah, 03Ch, 02Eh, 03Ch, 02Ch
	DB	03Ch, 025h, 078h, 000h, 03Ch, 025h, 03Ch, 02Ch, 03Ch, 02Eh, 03Ch, 02Ah, 078h, 000h, 03Ch, 0FFh
	DB	000h, 000h, 060h, 087h, 001h, 072h, 02Eh, 03Ch, 02Ah, 03Ch, 02Ch, 03Ch, 025h, 078h, 000h, 03Ch
	DB	025h, 03Ch, 02Ch, 03Ch, 02Eh, 03Ch, 02Ah, 078h, 000h, 03Ch, 02Ah, 03Ch, 02Eh, 03Ch, 02Ch, 03Ch
	DB	025h, 078h, 000h, 03Ch, 025h, 03Ch, 02Ch, 03Ch, 02Eh, 03Ch, 02Ah, 078h, 000h, 03Ch, 0FFh, 000h
	DB	000h, 060h, 0FFh, 000h, 000h, 002h, 010h, 00Fh, 01Dh, 02Ch, 03Bh, 04Ah, 059h, 068h, 077h, 076h
	DB	075h, 074h, 073h, 072h, 071h, 000h, 0F1h, 0FFh

;-------------------------------------------
	DS  09000h-$-ROMADR,000h

;---------------------------------- この辺はページ２
ROM9000h:
MUSDAT2:	; 曲データ２
	DB	00Eh, 000h, 013h, 000h, 020h, 000h, 025h, 000h, 02Ah, 000h, 000h, 001h, 055h, 000h, 0BFh, 000h
	DB	0FFh, 000h, 000h, 060h, 073h, 02Eh, 03Ch, 02Eh, 03Ch, 02Eh, 03Ch, 03Ah, 03Ch, 0FFh, 000h, 000h
	DB	060h, 073h, 0FFh, 000h, 000h, 060h, 073h, 0FFh, 000h, 000h, 003h, 011h, 00Fh, 00Eh, 00Dh, 01Ch
	DB	02Bh, 02Ah, 039h, 038h, 047h, 046h, 045h, 044h, 043h, 052h, 051h, 000h, 0F1h, 0FFh



;==============================================================
; 以降は RAM , アドレス定義用
;==============================================================
;---------------------------------- NDP ワークエリア
SECTION ndp_wk
	ORG	NDPWKADR

INCLUDE "NDP_WRK.ASM"

;==============================================================
;---------------------------------- ワークエリア
SECTION user_wk
	ORG	FNKSTR	; ファンクションキー定義エリアを一時的に間借り

SPBACKUP:
	DW	0
MYSLOT_P1:
	DB	0
MYSLOT_P2:
	DB	0

;============================================================== OVER