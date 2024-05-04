; boot.asm 程序包含了 Boot、Loader 能力。
; 可优化点：
; 1. 查找函数用 Func 隔离下会更好阅读
;
; BIOS 颜色：https://en.wikipedia.org/wiki/BIOS_color_attributes
;

	org 0x7c00								;
	jmp	short Label_Start
	nop

; 定义立即数别名，不占真实内存
BaseOfStack 				equ 0x7c00	; 程序在物理内存中的起点
BaseOfLoader				equ	0x1000	; 文件系统中加载 Loader 段基地址
OffsetOfLoader				equ	0x00	; 同 BaseOfLoader，偏移地址
RootDirSectors				equ	14		; FAT32文件系统的根目录分区数
SectorNumOfRootDirStart		equ	19		; FAT32文件系统的根目录起始扇区，扇区起始号为 0。所以 19 类似 index。
SectorNumOfFAT1Start		equ	1		; FAT1表起始扇区
SectorBalance				equ	17		; 建设没有FAT1表和FAT2表的起始扇区

; FAT32文件系统在第一个扇区起始位置记录了文件系统结构
BS_OEMName		db	'MINEboot'			; 堆栈不会覆盖到这些，因为是向低地址增长
BPB_BytesPerSec	dw	512
BPB_SecPerClus	db	1
BPB_RsvdSecCnt	dw	1
BPB_NumFATs		db	2
BPB_RootEntCnt	dw	224
BPB_TotSec16	dw	2880
BPB_Media		db	0xf0
BPB_FATSz16		dw	9
BPB_SecPerTrk	dw	18
BPB_NumHeads	dw	2
BPB_HiddSec		dd	0
BPB_TotSec32	dd	0
BS_DrvNum		db	0
BS_Reserved1	db	0
BS_BootSig		db	0x29
BS_VolID		dd	0
BS_VolLab		db	'boot loader'
BS_FileSysType	db	'FAT12   '

Label_Start: 
	mov	ax,	cs								; 段寄存器初始化
	mov	ds,	ax								; ds及以下 设置为 0x0000
	mov	es,	ax								;
	mov	fs,	ax								;
	mov	gs,	ax								;
	mov	ss,	ax								;

	mov	sp,	BaseOfStack						; sp 和 bp 属于 r16 而不是 sreg
	mov	bp,	BaseOfStack						;

; 清空屏幕
	mov	ax, 0600h							; Clear/Scroll Screen Up. https://en.wikipedia.org/wiki/BIOS_interrupt_call
	mov bh, 0ah								; 黑底绿字
	mov cx, 0								; 左上角
	mov dx, 184fh							; 右下角
	int 10h									; 调用 BIOS 中断

; 设置光标位置
	mov ah, 2;								; INT 10,2 - Set Cursor Position
	mov bh, 0								; page number。BH (Page Number): 在某些文本模式或图形模式下，尤其是具有多页显示能力的视频模式中，BH 寄存器可能被用来指定“页面”（Page）编号。这里的“页面”是指视频内存中用于显示的一个独立区域，可以理解为屏幕上的一组固定行数。切换页面编号可以快速在不同屏幕区域之间切换，而不必重新绘制整个屏幕。例如，在某些BIOS调用（如INT 10h）或显卡编程接口中，通过设置BH寄存器，可以指定要在哪个页面上进行文本输出、图形绘制或屏幕操作。
	mov dh, 0								; 行
	mov dl, 0								; 列
	int 10h									; 调用 BIOS 中断

; 输出字符
	mov ah, 13h								; 写入字符串
	mov al, 01h								; 1 移动光标， 0 不移动。https://helppc.netcore2k.net/interrupt/int-10-13；https://helppc.netcore2k.net/interrupt
	mov bh, 0h								; video page number
	mov bl, 0ah								; color
	mov cx, 7								; length of string (ignoring attributes)
	mov dh, 0								; 行
	mov dl, 0								; 列
	mov bp, StartBootMessage				;
	int 10h									; 调用 BIOS 中断

; 重置软盘
	mov ah, 0								; 重置软盘
	mov dl, 0								; 
	int 13h									; 调用 BIOS 中断

; 在 FAT32 文件系统中查询 loader.bin文件
	mov	word	[SectorNo],	SectorNumOfRootDirStart

; FAT12 Root Dir 项目遍历，查找“Loader  Bin”文件名
Iterator_Root_Dir_Sectors:
	cmp	word	[RootDirSizeForLoop],	0	; 循环 RootDirSizeForLoop 次，每次减 1
	jz	Func_No_LoaderBin					; 循环结束，未找到
	dec	word	[RootDirSizeForLoop]		; 循环计数减 1
	
	; 设置函数参数，调用函数 Func_ReadOneSector。读取一个根目录分区
	mov	cx,	00h								; 赋值 es 段
	mov	es,	cx
	mov	bx,	8000h
	mov	ax,	[SectorNo]
	mov	cl,	1									
	call	Func_ReadOneSector
	
	; 读取完毕1次删除, 对比文件名前，设置 si，di 和 清楚标记位 DF=0
	mov	si,	LoaderFileName
	mov	di,	8000h
	cld

	mov	dx,	10h								; 遍历 16 次，每次读取 32B
Iterator_Root_Dir_Sector:					; 扇区中的根目录项遍历
	cmp	dx,	0
	jz	Iterator_Root_Dir_Sectors			; 跳转到这里时， dx = 0 意味查找下一个扇区
	dec	dx									; 遍历一次减 1

	mov	cx,	11								; 遍历 11 次，因为FAT21规定文件名+扩展名最多这么大
Iterator_Cmp_FileName:						; 
	cmp	cx,	0
	jz	Func_FileName_Found					; 跳出：进入下一个流程
	dec	cx
	lodsb									; SI 指向的字符加载一个字节到 AL。并自动SI加1
	cmp	al,	byte	[es:di]					; DI 指向了缓冲区，比如AL和DI字符字符相当
	jz	Iterator_Cmp_FileName_Continue		; 相等则继续，否则跳出循环
	jmp	Iterator_Cmp_FileName_Break

Iterator_Cmp_FileName_Continue:
	inc	di
	jmp	Iterator_Cmp_FileName

Iterator_Cmp_FileName_Break:
	and	di,	0ffe0h							; DI 不是在32边界处，去除多余尾部数子
	add	di,	20h								; 增加 32B，下一个根目录项
	mov	si,	LoaderFileName					; 恢复 SI
	jmp	Iterator_Root_Dir_Sector

Iterator_Root_Dir_Sector_Continue:
	add	word	[SectorNo],	1				; 下一个扇区；这里直接对内存存储的数据加1
	jmp	Iterator_Root_Dir_Sector


; 遍历 FAT 根目录之后,未找到文件项
Func_No_LoaderBin:
	mov	ax,	1301h
	mov	bx,	008ch
	mov	dx,	0100h
	mov	cx,	21
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	NoLoaderMessage
	int	10h
	jmp	$


; 找到loader.bin文件后，依赖FAT1表找到簇
Func_FileName_Found:
	mov	ax,	RootDirSectors				; 起始扇区放入 ax
	and	di,	0ffe0h						; di 去除前面比较时的多余项，在32B的目录中间，变成执行首位
	add	di,	01ah						; 第 26 位，指向起始簇号
	mov	cx,	word	[es:di]				; 起始簇号（也就是扇区号了）放入 cx
	push	cx							; cx 入栈，后面 pop 到了 ax 中

	add	cx,	ax							; 文件扇区号 + SectorBalance ，就像没有前面的保留扇区一样。
	add	cx,	SectorBalance				
	mov	ax,	BaseOfLoader				; es，Loader 起始位置
	mov	es,	ax							; 
	mov	bx,	OffsetOfLoader				; bx：Loader 已读偏移
	mov	ax,	cx							; ax：读取文件内容扇区号，SectorBalance 过

While_Read_sector:
	push	ax							; ax：读取文件内容扇区号，SectorBalance 过
	push	bx							; bx：Loader 已读偏移

	mov	ah,	0eh							; 屏幕上输出1个.
	mov	al,	'.'
	mov	bl,	0fh
	int	10h

	pop	bx								; ax: BaseOfLoader, bx: ES:BX 偏移
	pop	ax
	mov	cl,	1							; 读取 1个扇区, 里面是文件内容
	call	Func_ReadOneSector

	pop	ax								; 起始簇（扇区号）		
	call	Func_GetFATEntry
	cmp	ax,	0fffh						; ax，此时是下一个簇，FAT1表的查询过程被封装了
	jz	While_Read_sector_end

	push	ax							; 存储下一个簇（扇区号）	
	mov	dx,	RootDirSectors
	add	ax,	dx
	add	ax,	SectorBalance				; 下一个簇对应的扇区号

	add	bx,	[BPB_BytesPerSec]				; es:bx 添加1个扇区偏移

	jmp	While_Read_sector

While_Read_sector_end:
	jmp	BaseOfLoader:OffsetOfLoader   	; 跳转到loader执行

; 软盘中读取 1 个扇区
; ES:BX 读取的扇区存储位置
; AX 	读取扇区起始位置
; CL	扇区个数
Func_ReadOneSector:
	push	bp
	mov	bp,	sp
	sub	esp,	2
	mov	byte	[bp - 2],	cl
	push	bx
	mov	bl,	[BPB_SecPerTrk]
	div	bl
	inc	ah
	mov	cl,	ah
	mov	dh,	al
	shr	al,	1
	mov	ch,	al
	and	dh,	1
	pop	bx
	mov	dl,	[BS_DrvNum]

Label_Go_On_Reading:
	mov	ah,	2
	mov	al,	byte	[bp - 2]
	int	13h
	jc	Label_Go_On_Reading
	add	esp,	2
	pop	bp
	ret

; 读取FAT表中的 FAT Entry。每一项12bit，会跨扇区存储。
; AX 根据扇区号获取下一个扇区号。扇区号也是索引号
Func_GetFATEntry:
	push	es
	push	bx
	push	ax
	mov	ax,	00
	mov	es,	ax
	pop	ax
	mov	byte	[Odd],	0
	mov	bx,	3
	mul	bx								; ax 扩大1.5倍，将会是 fat 表的地址起始索引。
	mov	bx,	2
	div	bx
	cmp	dx,	0							; 余数存储在 dx 中
	jz	Label_Even						; 偶数
	mov	byte	[Odd],	1				; 奇数

Label_Even:
	xor	dx,	dx							; 置零 dx
	mov	bx,	[BPB_BytesPerSec]			; 
	div	bx
	push	dx							; 当前表项的FAT表的偏移

	mov	bx,	8000h						; 读取到这里
	add	ax,	SectorNumOfFAT1Start		; 读取 FAT1 表，FAT1表有多个扇区
	mov	cl,	2
	call	Func_ReadOneSector			; 连续读取 2 个扇区
	
	pop	dx
	add	bx,	dx
	mov	ax,	[es:bx]						; 取下一个表项号
	cmp	byte	[Odd],	1				; 原表项的地址是奇数
	jnz	Label_Even_2
	shr	ax,	4							; 奇数时修复 ax， 12bit地址不对

Label_Even_2:
	and	ax,	0fffh
	pop	bx
	pop	es
	ret

; 临时变量，没有标签
RootDirSizeForLoop	dw	RootDirSectors
SectorNo			dw	0
Odd					db	0

; 永久变量
StartBootMessage: 	db "Booting"
NoLoaderMessage:	db	"ERROR:No LOADER Found"
LoaderFileName:		db	"LOADER  BIN",0			; 文件名 8B，扩展名 3B，中间的空格是用于填充不足8B的文件名的，它们是分开存储的

; 补充剩余空间
	times	510 - ($ - $$)	db	0           	; $ 当前位置，$$ 段起始地址，510 减去代码段得到剩余空间
	dw	0xaa55