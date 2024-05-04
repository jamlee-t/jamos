.section .text

// 长模式运行。默认已有 10MB 的临时页表。

.globl _start

_start:
	mov	$0x10,	%ax							// 段选择子: 16位，0x000010 000, 在GDT中查询，index=2。是 loader.asm 设置的数据段。
	mov	%ax,	%ds
	mov	%ax,	%es
	mov	%ax,	%fs
	mov	%ax,	%ss
	mov	$0x7E00, %esp						// 栈指针指向 0x7e00

	// 立即重新设置 gdt，设置 idt
	lgdt	GDT_POINTER(%rip)				// 反汇编，lgdt 0x0(%rip), 0x0 指数据段
	lidt	IDT_POINTER(%rip)

	// 重新设置段选择子
	mov		$0x10,		%ax
	mov		%ax,		%ds
	mov		%ax,		%es
	mov		%ax,		%fs
	mov		%ax,		%gs
	mov		%ax,		%ss
	movq	$0x7E00,	%rsp

	// 页表基地址 0x101000 就是页表所在位置，页表使用了 .org 0x1000。
	movq	$0x101000,			%rax
	movq	%rax,				%cr3

	// pushq 选择子，pushq entry64 地址。gas 不支持远跳转。
	movq	switch_seg(%rip),	%rax
	pushq	$0x08
	pushq	%rax							// 从栈顶弹出地址			
	lretq									// l 是long的意思。也就是远返回需要切换段。

// lretq 跳转到这里执行
switch_seg:
	.quad	entry64

entry64:
	movq	$0x10,	%rax
	movq	%rax,	%ds
	movq	%rax,	%es
	movq	%rax,	%gs
	movq	%rax,	%ss
	movq	$0xffff800000007E00,	%rsp		/* rsp address */

	movq	go_to_kernel(%rip),	%rax		/* movq address */
	pushq	$0x08
	pushq	%rax
	lretq

go_to_kernel:
	.quad	Start_Kernel


/////////////////////////////////////////////////////////
//
// 内核设置的页表
//
/////////////////////////////////////////////////////////
.align 8

.org	0x1000
__PML4E:
	.quad	0x102007		// 0X102是指 0x102000,007是标志位
	.fill	255,8,0
	.quad	0x102007
	.fill	255,8,0

.org	0x2000
__PDPTE:
	.quad	0x103003
	.fill	511,8,0

.org	0x3000
__PDE:
	.quad	0x000083	
	.quad	0x200083
	.quad	0x400083
	.quad	0x600083
	.quad	0x800083
	.quad	0xe0000083		/*0x a00000*/
	.quad	0xe0200083
	.quad	0xe0400083
	.quad	0xe0600083		/*0x1000000*/
	.quad	0xe0800083
	.quad	0xe0a00083
	.quad	0xe0c00083
	.quad	0xe0e00083
	.fill	499,8,0


/////////////////////////////////////////////////////////
//
// 内核设置的 GDT 表
//
/////////////////////////////////////////////////////////
.section .data

.globl GDT_Table

GDT_Table:
	.quad	0x0000000000000000			/*0	NULL descriptor		       	00*/
	.quad	0x0020980000000000			/*1	KERNEL	Code	64-bit	Segment	08*/
	.quad	0x0000920000000000			/*2	KERNEL	Data	64-bit	Segment	10*/
	.quad	0x0020f80000000000			/*3	USER	Code	64-bit	Segment	18*/
	.quad	0x0000f20000000000			/*4	USER	Data	64-bit	Segment	20*/
	.quad	0x00cf9a000000ffff			/*5	KERNEL	Code	32-bit	Segment	28*/
	.quad	0x00cf92000000ffff			/*6	KERNEL	Data	32-bit	Segment	30*/
	.fill	10,8,0					/*8 ~ 9	TSS (jmp one segment <7>) in long-mode 128-bit 40*/
GDT_END:

GDT_POINTER:
GDT_LIMIT:	.word	GDT_END - GDT_Table - 1
GDT_BASE:	.quad	GDT_Table


/////////////////////////////////////////////////////////
//
// 内核设置的 IDT 表，全部置空
//
/////////////////////////////////////////////////////////
.globl IDT_Table

IDT_Table:
	.fill  512,8,0
IDT_END:

IDT_POINTER:
IDT_LIMIT:	.word	IDT_END - IDT_Table - 1
IDT_BASE:	.quad	IDT_Table

/////////////////////////////////////////////////////////
//
// 内核设置的 TSS 表
//
/////////////////////////////////////////////////////////
.globl	TSS64_Table

TSS64_Table:
	.fill  13,8,0
TSS64_END:

TSS64_POINTER:
TSS64_LIMIT:	.word	TSS64_END - TSS64_Table - 1
TSS64_BASE:	.quad	TSS64_Table

