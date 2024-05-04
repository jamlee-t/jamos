; 实模式可用内存布局

    org 0x10000												; loader加载程序到这里, 64KB处
	jmp	Label_Start

%include	"./include/fat12.inc"

BaseOfStack 			equ 0x1000							; 栈底
BaseOfKernelFile		equ	0x0								; 内核运行时段地址
OffsetOfKernelFile		equ	0x100000						; 内核运行时段偏移

BaseTmpOfKernelAddr		equ	0x00							; 临时内核段地址
OffsetTmpOfKernelFile	equ	0x7E00							; BIOS的可用区域。0x7C00-0x7DFF，0x7E00-0x9FBFF 这里注意超过1M
MemoryStructBufferAddr	equ	0x7E00


; Flags
; +---------------+ 
; |3| 2|1|0       | 
; |G|DB|L|Reserved| 
; +---------------+ 
; G: 粒度标志，指示限制值所依据的尺寸单位。如果该位清零（0），则限制值是以1字节块（字节粒度）为单位。如果该位置1（1），则限制值是以4千字节块（页粒度）为单位。
; DB: 大小标志。如果该位清零（0），则描述符定义的是16位保护模式段。如果该位置1（1），则定义的是32位保护模式段。全局描述符表（GDT）可以同时包含16位和32位的选择子。
; L: 长模式代码标志。如果该位置1（1），则描述符定义的是64位代码段。当该位置1时，DB位应当总是清零。对于任何其他类型的段（包括其他代码类型或任何数据段），该位应当清零（0）。

; 代码或数据段 Access bytes
; +-----------------+
; |7|6-5|4|3| 2| 1|0|
; |P|DPL|S|E|DC|RW|A|
; +-----------------+
; P：存在位。允许条目引用一个有效的段。对于任何有效段，此位必须设置为1。
; DPL：描述符特权级字段。包含段的CPU特权级。0代表最高特权（内核级），3代表最低特权（用户应用程序）。
; S：描述符类型位。如果清零（0），则描述符定义的是系统段（如任务状态段）。如果置位（1），则定义的是代码或数据段。
; E：可执行位。如果清零（0），则描述符定义的是数据段。如果置位（1），则定义的是可从中执行代码的代码段。
; DC：方向位/一致位。
; 对于数据选择子：方向位。如果清零（0），段向上增长。如果置位（1），段向下增长，即偏移量必须大于界限。
; 对于代码选择子：一致位。
; 如果清零（0），则此段中的代码只能从DPL设置的环级别执行。
; 如果置位（1），则此段中的代码可以从相同或更低的特权级别执行。例如，环3中的代码可以通过远跳转到环2段中的一致性代码。DPL字段表示允许执行该段的最高特权级别。例如，环0中的代码不能远跳转到DPL为2的一致性代码段，而环2和环3中的代码可以。请注意，特权级别保持不变，即从环3远跳转到DPL为2的段后，仍处于环3。
; RW：可读位/可写位。
; 对于代码段：可读位。如果清零（0），则不允许对此段进行读取访问。如果置位（1），则允许读取访问。代码段永远不允许写入访问。
; 对于数据段：可写位。如果清零（0），则不允许对此段进行写入访问。如果置位（1），则允许写入访问。数据段总是允许读取访问。
; A：已访问位。CPU在访问段时会设置此位，除非事先已设置为1。这意味着如果GDT描述符存储在只读页面中且此位设置为0，尝试设置此位的CPU将触发页面错误。除非另有需要，最好将其设置为1。

; 系统段 Access bytes
; +------------+
; |7|6-5|4| 3-0|
; |P|DPL|S|Type|
; +------------+
; 对于系统段，比如那些定义任务状态段（Task State Segment）或局部描述符表（Local Descriptor Table）的段，访问字节（Access Byte）的格式略有不同，这是为了定义不同类型的系统段，而非区分代码段和数据段。
; 类型（Type）：系统段的类型。
; 在32位保护模式下可用的类型有：
; - 0x1：16位任务状态段（TSS，可用）
; - 0x2：局部描述符表（LDT）
; - 0x3：16位任务状态段（TSS，忙）
; - 0x9：32位任务状态段（TSS，可用）
; - 0xB：32位任务状态段（TSS，忙）
; 在长模式（Long Mode）下可用的类型包括：
; - 0x2：局部描述符表（LDT）
; - 0x9：64位任务状态段（TSS，可用）
; - 0xB：64位任务状态段（TSS，忙）


; LABEL_DESC_CODE32 代码段内容; 32 位，占用 64bit，即8B
; +---------+---------+---------+---------+ 
; |63     56|55     48|47     40|39     32| 
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼| 
; +---------+----+----+---------+---------- 
; |0000|0000|1100|1111|1001|1010|0000|0000| 
; +---------------------------------------+ 
;  ├-------┤ ├--┤ ├--┤ ├-------┤ ├--------┤ 
;   |         |    |    |         Base:16-23
;   |         |    |    Access Bytes        
;   |         |    Limit:16-19              
;   |         Flags                         
;   |                                       
;   Base:16-23                                                                                                          
;                                           
; +---------+---------+---------+---------+ 
; |31     24|23     16|15      8|7       0| 
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼| 
; +---------+---------+---------+---------- 
; |0000|0000|0000|0000|1111|1111|1111|1111| 
; +---------------------------------------+ 
;  ├-----------------┤ ├-----------------┤  
;      Base:0-15            Limit:0-15      

; acccess bytes
; +-----------------+
; |7|6-5|4|3| 2| 1|0|
; |P|DPL|S|E|DC|RW|A|
; |1| 00|1|1| 0| 1|1|
; +-----------------+
; 查表得：DPL 0 特权级，S 代码或者数据段，E 可执行，DC 仅允许相同DPL的代码段运行，RW 代码段可读，A 已访问段

; LABEL_DESC_DATA32 数段内容
; +---------+---------+---------+---------+ 
; |63     56|55     48|47     40|39     32| 
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼| 
; +---------+----+----+---------+---------- 
; |0000|0000|1100|1111|1001|0010|0000|0000| 
; +---------------------------------------+ 
;  ├-------┤ ├--┤ ├--┤ ├-------┤ ├--------┤ 
;   |         |    |    |         Base:16-23
;   |         |    |    Access Bytes        
;   |         |    Limit:16-19              
;   |         Flags                         
;   |                                       
;   Base:16-23                                                                                                          
;                                           
; +---------+---------+---------+---------+ 
; |31     24|23     16|15      8|7       0| 
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼| 
; +---------+---------+---------+---------- 
; |0000|0000|0000|0000|1111|1111|1111|1111| 
; +---------------------------------------+ 
;  ├-----------------┤ ├-----------------┤  
;      Base:0-15            Limit:0-15      

; acccess bytes
; +-----------------+
; |7|6-5|4|3| 2| 1|0|
; |P|DPL|S|E|DC|RW|A|
; |1| 00|1|0| 0| 1|1|
; +-----------------+
; 查表得：DPL 0 特权级，S 代码或者数据段，E 不可执行，DC 向上增长，RW 数据可写，A 已访问段


[SECTION gdt]
LABEL_GDT:			dd	0,0									; 0，这使得它既没有段基地址也没有段界限，因此是一个无效的段选择符。当程序错误地使用了一个未初始化或有意设置为0的段选择符时，处理器会引用这个NULL描述符，从而防止了对非法内存的访问。
LABEL_DESC_CODE32:	dd	0x0000FFFF,0x00CF9A00				; dd，dw，db 分别是 4、2、1 Byte
LABEL_DESC_DATA32:	dd	0x0000FFFF,0x00CF9200

; GDTR 寄存器内容
GdtLen				equ	$ - LABEL_GDT						; GDT 表的长度
GdtPtr				dw	GdtLen - 1							; GDT 的指针, 两行代码共同构成了GDTR（Global Descriptor Table Register）的内容，GDTR是一个6字节的寄存器，其中前16位（由dw指令定义的部分）是GDT的界限，后32位（由dd指令定义的部分）是GDT的基地址。
dd					LABEL_GDT								; 4 字节存储GDT表起始地址, 

SelectorCode32		equ	LABEL_DESC_CODE32 - LABEL_GDT		; Code32 索引
SelectorData32		equ	LABEL_DESC_DATA32 - LABEL_GDT		; Data32 索引


; 64 位，占用 128bit，即16B
; LABEL_DESC_DATA64 代码段内容
;
; 4. 保留使用                                       
; +---------+---------+---------+---------+    
; |127   120|119   112|111   104|103    96|    
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼|    
; +---------+---------+---------+----------    
; |0000|0000|0000|0000|0000|0000|0000|0000|    
; +---------------------------------------+    
; 
; 3. BASE: 32-63                                                                                      
; +---------+---------+---------+---------+    
; |95     88|87     80|79     72|71     64|    
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼|    
; +---------+---------+---------+----------    
; |0000|0000|0000|0000|0000|0000|0000|0000|    
; +---------------------------------------+    
;
; 2. 同保护模式                                            
; +---------+---------+---------+---------+ 
; |63     56|55     48|47     40|39     32| 
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼| 
; +---------+----+----+---------+---------- 
; |0000|0000|0010|0000|1001|1000|0000|0000| 
; +---------------------------------------+ 
;  ├-------┤ ├--┤ ├--┤ ├-------┤ ├--------┤ 
;   |         |    |    |         Base:16-23
;   |         |    |    Access Bytes        
;   |         |    Limit:16-19              
;   |         Flags                         
;   |                                       
;   Base:16-23                                                                                                          
; 
; 1. 同保护模式                                            
; +---------+---------+---------+---------+ 
; |31     24|23     16|15      8|7       0| 
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼| 
; +---------+---------+---------+---------- 
; |0000|0000|0000|0000|0000|0000|0000|0000| 
; +---------------------------------------+ 
;  ├-----------------┤ ├-----------------┤  
;      Base:0-15            Limit:0-15      

; 5. acccess bytes
; +-----------------+
; |7|6-5|4|3| 2| 1|0|
; |P|DPL|S|E|DC|RW|A|
; |1| 00|1|1| 0| 0|0|
; +-----------------+
; 查表得：DPL 0 特权级，S 代码或者数据段，E 可执行，DC 仅允许相同DPL的代码段运行，RW 数据不可读，A 已访问段


; 64 位，占用 128bit，即16B
; LABEL_DESC_CODE64 代码段内容
;
; 4. 保留使用                                       
; +---------+---------+---------+---------+    
; |127   120|119   112|111   104|103    96|    
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼|    
; +---------+---------+---------+----------    
; |0000|0000|0000|0000|0000|0000|0000|0000|    
; +---------------------------------------+    
; 
; 3. BASE: 32-63                                                                                      
; +---------+---------+---------+---------+    
; |95     88|87     80|79     72|71     64|    
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼|    
; +---------+---------+---------+----------    
; |0000|0000|0000|0000|0000|0000|0000|0000|    
; +---------------------------------------+    
;
; 2. 同保护模式。长模式标记为1                                          
; +---------+---------+---------+---------+ 
; |63     56|55     48|47     40|39     32| 
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼| 
; +---------+----+----+---------+---------- 
; |0000|0000|0010|0000|1001|0010|0000|0000| 
; +---------------------------------------+ 
;  ├-------┤ ├--┤ ├--┤ ├-------┤ ├--------┤ 
;   |         |    |    |         Base:16-23
;   |         |    |    Access Bytes        
;   |         |    Limit:16-19              
;   |         Flags                         
;   |                                       
;   Base:16-23                                                                                                          
; 
; 1. 同保护模式                                            
; +---------+---------+---------+---------+ 
; |31     24|23     16|15      8|7       0| 
; |▼       ▼|▼       ▼|▼       ▼|▼       ▼| 
; +---------+---------+---------+---------- 
; |0000|0000|0000|0000|0000|0000|0000|0000| 
; +---------------------------------------+ 
;  ├-----------------┤ ├-----------------┤  
;      Base:0-15            Limit:0-15      

; 5. acccess bytes
; +-----------------+
; |7|6-5|4|3| 2| 1|0|
; |P|DPL|S|E|DC|RW|A|
; |1| 00|1|0| 0| 1|0|
; +-----------------+
; 查表得：DPL 0 特权级，S 代码或者数据段，E 不可执行，DC 向上增长，RW 数据可读，A 已访问段


[SECTION gdt64]
LABEL_GDT64:		dq	0x0000000000000000
LABEL_DESC_CODE64:	dq	0x0020980000000000
LABEL_DESC_DATA64:	dq	0x0000920000000000

; GDTR 寄存器内容
GdtLen64			equ	$ - LABEL_GDT64
GdtPtr64			dw	GdtLen64 - 1
dd					LABEL_GDT64

SelectorCode64	equ	LABEL_DESC_CODE64 - LABEL_GDT64
SelectorData64	equ	LABEL_DESC_DATA64 - LABEL_GDT64


; 实模式代码
[SECTION .s16]
[BITS 16]
Label_Start: 
	mov	ax, cs							    ; 段寄存器初始化
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
	mov cx, 44								; length of string (ignoring attributes)
	mov dh, 0								; 行
	mov dl, 0								; 列
	mov bp, StartBootMessage				;
	int 10h									; 调用 BIOS 中断

; 开启 A20
	in al, 92h								; A20 打开方式有4种，这里使用A20快速门
	or al, 00000010b						; https://wiki.osdev.org/A20_Line#Fast_A20_Gate
	out	92h, al								; 写回

	cli										; 关闭中断
	db	0x66								; 使用32位宽时，加入前缀 0x66;
	lgdt [GdtPtr]							; 设置 GDTR寄存器，断点 1000:00c4

; big real model							; 写 eax 会被忽略高16位的, 若写 ax 会报错和cr0不匹配
	mov eax, cr0							;
	or eax, 1								; PE位置1
	mov cr0, eax							;

	mov ax, SelectorData32					; 数据段设置到 fs
	mov fs, ax

	mov eax, cr0							;
	and eax, 11111110b						; PE位置0
	mov cr0, eax							;

	sti

; 重置软盘
	xor	ah,	ah
	xor	dl,	dl
	int	13h

; 查找 kernel.bin
	mov	word	[SectorNo],	SectorNumOfRootDirStart

; 循环遍历扇区
Iterator_Root_Dir_Sectors:
	cmp	word	[RootDirSizeForLoop],	0
	jz	Func_NotFoundKernel								;目录扇区找寻完毕, 显示未找到 kernel.bin 的消息
	dec	word	[RootDirSizeForLoop]	
	mov	ax,	00h
	mov	es,	ax
	mov	bx,	8000h
	mov	ax,	[SectorNo]
	mov	cl,	1
	call	Func_ReadOneSector							; 读取1个扇区，扇区内容是目录
	mov	si,	KernelFileName
	mov	di,	8000h
	cld
	mov	dx,	10h
Iterator_Root_Dir_Sector:
	cmp	dx,	0
	jz	Iterator_Root_Dir_Sectors_Continue				; 下一个扇区
	dec	dx
	mov	cx,	11

Iterator_Cmp_FileName:
	cmp	cx,	0
	jz	Func_FoundKernel
	dec	cx
	lodsb	
	cmp	al,	byte	[es:di]
	jz	Iterator_Cmp_FileName_Continue					; 逐字符比较，继续比较
	jmp	Iterator_Cmp_FileName_Break						; 比较失败
Iterator_Cmp_FileName_Continue:
	inc	di
	jmp	Iterator_Cmp_FileName
Iterator_Cmp_FileName_Break:
	and	di,	0FFE0h
	add	di,	20h
	mov	si,	KernelFileName
	jmp	Iterator_Root_Dir_Sector						; 下一个目录项

Iterator_Root_Dir_Sectors_Continue:						; 下一个扇区
	add	word	[SectorNo],	1
	jmp	Iterator_Root_Dir_Sectors

; 屏幕显示: ERROR:No KERNEL Found
Func_NotFoundKernel:
	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0300h		;row 3
	mov	cx,	21
	push ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	KernelNotFoundMessage
	int	10h
	jmp	$

; found loader.bin name in root director struct
Func_FoundKernel:
	mov	ax,	RootDirSectors
	and	di,	0FFE0h
	add	di,	01Ah
	mov	cx,	word	[es:di]
	push cx
	add	cx,	ax
	add	cx,	SectorBalance
	mov	eax, BaseTmpOfKernelAddr					; BaseOfKernelFile
	mov	es,	eax
	mov	bx,	OffsetTmpOfKernelFile					; OffsetOfKernelFile
	mov	ax,	cx

Func_LoadKernelFile:
	push ax
	push bx
	mov	ah,	0Eh
	mov	al,	'.'
	mov	bl,	0Fh
	int	10h
	pop	bx
	pop	ax

	mov	cl,	1
	call Func_ReadOneSector
	pop	ax

	push cx
	push eax
	push fs
	push edi
	push ds
	push esi

	mov	cx,	200h
	mov	ax,	BaseOfKernelFile
	mov	fs,	ax
	mov	edi, dword [OffsetOfKernelFileCount]

	mov	ax,	BaseTmpOfKernelAddr
	mov	ds,	ax
	mov	esi, OffsetTmpOfKernelFile

FuncMovKernel:										; 加载一个扇区，移动一个扇区
	mov	al,	byte [ds:esi]
	mov	byte [fs:edi], al							; 移动到了 fs 段指定的位置，fs 是可以访问到1MB以上位置的，因为 Big Real Model
	inc	esi
	inc	edi
	loop FuncMovKernel

	mov	eax,	0x1000
	mov	ds,	eax
	mov	dword	[OffsetOfKernelFileCount],	edi
	pop	esi
	pop	ds
	pop	edi
	pop	fs
	pop	eax
	pop	cx

	call Func_GetFATEntry
	cmp	ax,	0FFFh
	jz	Func_KernelLoaded							; 扇区加载完毕，也移动完毕了
	push	ax
	mov	dx,	RootDirSectors
	add	ax,	dx
	add	ax,	SectorBalance

	jmp	Func_LoadKernelFile							; 继续加载新扇区

Func_KernelLoaded:									; 加载完毕
	mov	ax, 0B800h									; 显示字符的内存空间
	mov	gs, ax
	mov	ah, 0Fh										; 0000: 黑底    1111: 白字
	mov	al, 'L'
	mov	[gs:((80 * 1 + 0) * 2)], ax					; 屏幕第 2 行, 第 0 列。
	mov	al, 'O'
	mov	[gs:((80 * 1 + 1) * 2)], ax					; 屏幕第 2 行, 第 1 列。
	mov	al, 'A'
	mov	[gs:((80 * 1 + 2) * 2)], ax					; 屏幕第 2 行, 第 2 列。
	mov	al, 'D'
	mov	[gs:((80 * 1 + 3) * 2)], ax					; 屏幕第 2 行, 第 3 列。
	mov	al, 'E'
	mov	[gs:((80 * 1 + 4) * 2)], ax					; 屏幕第 2 行, 第 4 列。
	mov	al, 'D'
	mov	[gs:((80 * 1 + 5) * 2)], ax					; 屏幕第 2 行, 第 5 列。


Func_Stop_Floppy_Motor:								; 关闭软驱马达
	push	dx
	mov	dx,	03F2h
	mov	al,	0	
	out	dx,	al
	pop	dx

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 内存信息探测
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0200h		;row 2
	mov	cx,	24
	push ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartGetMemStructMessage
	int	10h													; 输出提示信息, 不影响主逻辑

	mov	ebx,	0
	mov	ax,	0x00
	mov	es,	ax
	mov	di,	MemoryStructBufferAddr	

Func_Get_Mem_Struct:
	mov	eax,	0x0E820
	mov	ecx,	20
	mov	edx,	0x534D4150
	int	15h
	jc	Func_Get_Mem_Fail
	add	di,	20

	cmp	ebx,	0
	jne	Func_Get_Mem_Struct
	jmp	Func_Get_Mem_OK

Func_Get_Mem_Fail:										; 打印失败的消息
	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0300h										;row 3
	mov	cx,	23
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetMemStructErrMessage
	int	10h
	jmp	$

Func_Get_Mem_OK:										; 打印成功的消息
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0300h										;row 6
	mov	cx,	29
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetMemStructOKMessage
	int	10h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; get SVGA information
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0400h		;row 8
	mov	cx,	23
	push ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartGetSVGAVBEInfoMessage
	int	10h												; 打印开始获取SVGA信息

	mov	ax,	0x00
	mov	es,	ax
	mov	di,	0x8000
	mov	ax,	4F00h
	int	10h

	cmp	ax,	004Fh
	jz	Func_SVGA_VBE_INFO_SUCCESS
	
Func_SVGA_VBE_INFO_FAIL:
	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0500h		;row 5
	mov	cx,	23
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAVBEInfoErrMessage
	int	10h
	jmp	$

Func_SVGA_VBE_INFO_SUCCESS:
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0500h											;row 5
	mov	cx,	29
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAVBEInfoOKMessage
	int	10h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; get SVGA Model information
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0600h											;row 6
	mov	cx,	24
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartGetSVGAModeInfoMessage
	int	10h													;打印获取SVGAModeInfo信息	

	mov	ax,	0x00
	mov	es,	ax
	mov	si,	0x800e

	mov	esi,	dword	[es:si]
	mov	edi,	0x8200

Func_SVGA_Mode_Info_Get:									; 需要多次调用
	mov	cx,	word	[es:esi]

; 显示获取的结果
	push ax
	mov	ax,	00h
	mov	al,	ch
	call	Label_DispAL
	mov	ax,	00h
	mov	al,	cl	
	call	Label_DispAL
	pop	ax

	cmp	cx,	0FFFFh
	jz Func_SVGA_Mode_Info_Finish

	mov	ax,	4F01h
	int	10h

	cmp	ax,	004Fh
	jnz	Func_SVGA_Mode_Info_FAIL	

	add	esi, 2
	add	edi, 0x100
	jmp	Func_SVGA_Mode_Info_Get

Func_SVGA_Mode_Info_FAIL:
	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0700h		;row 7
	mov	cx,	24
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAModeInfoErrMessage
	int	10h
	jmp	$

Func_SVGA_Mode_Info_Finish:
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0700h		;row 7
	mov	cx,	30
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAModeInfoOKMessage
	int	10h

; set the SVGA mode(VESA VBE)
	mov	ax,	4F02h
	mov	bx,	4180h							; mode : 0x180 or 0x143
	int 10h
	cmp	ax,	004Fh
	jz	Func_Set_SVGA_Success
	jmp $

Func_Set_SVGA_Success:
	cli
	db	0x66										; 打开PE位，进入保护模式
	lgdt [GdtPtr]
	mov	eax, cr0
	or	eax, 1										; CR.PE 置1
	mov	cr0, eax
	jmp	dword SelectorCode32:GO_TO_TMP_Protect


[SECTION .s32]
[BITS 32]
GO_TO_TMP_Protect:
; go to tmp long mode
	mov	ax,	0x10
	mov	ds,	ax
	mov	es,	ax
	mov	fs,	ax
	mov	ss,	ax
	mov	esp, 7E00h

	call support_long_mode
	test eax, eax
	jz	no_support


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 64位的临时页表
; 32位，未开启PAE时。1024 个页目录（PDE），每个目录项占用 4B。1024个页表（PTE），每个页表4KB。1024 * 1024 * 4KB = 4GB。逻辑地址 2^10,2^10,2^12次方，刚好对应这三部分。
; 32位，开启PAE时。
; 64位，48位寻址。2^9 * 2^9 * 2^9 * 2^9 * 2^12 总计48位。第一级目录PML4入口,每个项8B（64bit）。所以第一级页目录大小 2^9*8 = 2^12 = 4KB。
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; 临时页表映射了 8 MB的内存

	; PLM4 开始。[0x90000, 0x91000)
	mov	dword	[0x90000],	0x91007					; PLM4，第 0 项。0x91000是 PDE 基地址，0x007是标志位
	mov	dword	[0x90004],	0x00000					;
	mov	dword	[0x90800],	0x91007					; PLM4，第 9 项。0x91000是基地址，0x007是标志位
	mov	dword	[0x90804],	0x00000					;
	; PLM4 结束。0X1000 = 2^9 = 512B。可容纳 64 个 PLM4 项。

	; PDPTE 开始。[0x91000, 0x92000)
	mov	dword	[0x91000],	0x92007					; 第 0 项 PLM4 , 第 0 个 PDE 表。0x92000是PDE基地址，0x007是标志位
	mov	dword	[0x91004],	0x00000					;
	; 结束。

	; PDT 表开始。64地址中的 12 + 8 位直接在这寻址。
	mov	dword	[0x92000],	0x000083				; 1, 0x000000。2MB
	mov	dword	[0x92004],	0x000000

	mov	dword	[0x92008],	0x200083				; 2，0x200000。2MB
	mov	dword	[0x9200c],	0x000000

	mov	dword	[0x92010],	0x400083				; 3，0x200000。2MB
	mov	dword	[0x92014],	0x000000

	mov	dword	[0x92018],	0x600083				; 4，0x200000。2MB
	mov	dword	[0x9201c],	0x000000

	mov	dword	[0x92020],	0x800083				; 5，0x200000。2MB
	mov	dword	[0x92024],	0x000000

	mov	dword	[0x92028],	0xa00083				; 6，0x200000。2MB
	mov	dword	[0x9202c],	0x000000

	mov	dword	[0x92030],	0xc00083				; 7，0x200000。2MB
	mov	dword	[0x92034],	0x000000


; 1. 加载 64 位 GDT。通过指令前缀操作64位的 GDTR
	db	0x66
	lgdt	[GdtPtr64]
	mov	ax,	0x10
	mov	ds,	ax
	mov	es,	ax
	mov	fs,	ax
	mov	gs,	ax
	mov	ss,	ax
	mov	esp, 7E00h

; 2. 打开 CR4.PAE。4级页表必须开启
	mov	eax,	cr4
	bts	eax,	5
	mov	cr4,	eax

; 3. 设置页表目录入口地址
	mov	eax,	0x90000
	mov	cr3,	eax

; 4. 打开长模式
	mov	ecx,	0C0000080h		;IA32_EFER
	rdmsr

	bts	eax,	8
	wrmsr

; 5. 打开标记位：CR0.PE，进入保护模式，打开标记位 CR0.PG 开启分页
	mov	eax,	cr0
	bts	eax,	0
	bts	eax,	31
	mov	cr0,	eax

	jmp	SelectorCode64:OffsetOfKernelFile

; 检测是否支持长模式
support_long_mode:
	mov	eax,	0x80000000
	cpuid
	cmp	eax,	0x80000001
	setnb	al	
	jb	support_long_mode_done
	mov	eax,	0x80000001
	cpuid
	bt	edx,	29
	setc	al

support_long_mode_done:
	movzx	eax,	al
	ret

; no support
no_support:
	jmp	$

[SECTION .s16lib]
[BITS 16]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FAT12 磁盘工具函数
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

Func_GetFATEntry:
	push	es
	push	bx
	push	ax
	mov	ax,	00
	mov	es,	ax
	pop	ax
	mov	byte	[Odd],	0
	mov	bx,	3
	mul	bx
	mov	bx,	2
	div	bx
	cmp	dx,	0
	jz	Label_Even
	mov	byte	[Odd],	1
Label_Even:
	xor	dx,	dx
	mov	bx,	[BPB_BytesPerSec]
	div	bx
	push	dx
	mov	bx,	8000h
	add	ax,	SectorNumOfFAT1Start
	mov	cl,	2
	call	Func_ReadOneSector
	pop	dx
	add	bx,	dx
	mov	ax,	[es:bx]
	cmp	byte	[Odd],	1
	jnz	Label_Even_2
	shr	ax,	4
Label_Even_2:
	and	ax,	0FFFh
	pop	bx
	pop	es
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 其他工具函数
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Label_DispAL:
	push	ecx
	push	edx
	push	edi
	mov	edi, [DisplayPosition]
	mov	ah,	0Fh
	mov	dl,	al
	shr	al,	4
	mov	ecx,	2
.begin:
	and	al,	0Fh
	cmp	al,	9
	ja	.1
	add	al,	'0'
	jmp	.2
.1:
	sub	al,	0Ah
	add	al,	'A'
.2:
	mov	[gs:edi], ax
	add	edi, 2
	mov	al,	dl
	loop	.begin
	mov	[DisplayPosition],	edi
	pop	edi
	pop	edx
	pop	ecx
	
	ret


; 临时变量
RootDirSizeForLoop		dw	RootDirSectors
SectorNo				dw	0
Odd						db	0
OffsetOfKernelFileCount	dd	OffsetOfKernelFile
DisplayPosition			dd	0

; 全局变量
StartBootMessage: 	    		db	"Jamlee Loader Working, Let't us write kernel" ; 标签是当前文件偏移
KernelNotFoundMessage:			db	"ERROR:No KERNEL Found"
KernelFileName:					db	"KERNEL  BIN", 0
StartGetMemStructMessage:		db	"Start Get Memory Struct."
GetMemStructErrMessage:			db	"Get Memory Struct ERROR"
GetMemStructOKMessage:			db	"Get Memory Struct SUCCESSFUL!"

StartGetSVGAVBEInfoMessage:		db	"Start Get SVGA VBE Info"
GetSVGAVBEInfoErrMessage:		db	"Get SVGA VBE Info ERROR"
GetSVGAVBEInfoOKMessage:		db	"Get SVGA VBE Info SUCCESSFUL!"

StartGetSVGAModeInfoMessage:	db	"Start Get SVGA Mode Info"
GetSVGAModeInfoErrMessage:		db	"Get SVGA Mode Info ERROR"
GetSVGAModeInfoOKMessage:		db	"Get SVGA Mode Info SUCCESSFUL!"
