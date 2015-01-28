;/*
;    FreeRTOS V8.0.1 - Copyright (C) 2014 Real Time Engineers Ltd.
;    All rights reserved
;	
;
;    ***************************************************************************
;     *                                                                       *
;     *    FreeRTOS tutorial books are available in pdf and paperback.        *
;     *    Complete, revised, and edited pdf reference manuals are also       *
;     *    available.                                                         *
;     *                                                                       *
;     *    Purchasing FreeRTOS documentation will not only help you, by       *
;     *    ensuring you get running as quickly as possible and with an        *
;     *    in-depth knowledge of how to use FreeRTOS, it will also help       *
;     *    the FreeRTOS project to continue with its mission of providing     *
;     *    professional grade, cross platform, de facto standard solutions    *
;     *    for microcontrollers - completely free of charge!                  *
;     *                                                                       *
;     *    >>> See http://www.FreeRTOS.org/Documentation for details. <<<     *
;     *                                                                       *
;     *    Thank you for using FreeRTOS, and thank you for your support!      *
;     *                                                                       *
;    ***************************************************************************
;
;
;    This file is part of the FreeRTOS distribution.
;
;    FreeRTOS is free software; you can redistribute it and/or modify it under
;    the terms of the GNU General Public License (version 2) as published by the
;    Free Software Foundation AND MODIFIED BY the FreeRTOS exception.
;    >>>NOTE<<< The modification to the GPL is included to allow you to
;    distribute a combined work that includes FreeRTOS without being obliged to
;    provide the source code for proprietary components outside of the FreeRTOS
;    kernel.  FreeRTOS is distributed in the hope that it will be useful, but
;    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;    or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
;    more details. You should have received a copy of the GNU General Public
;    License and the FreeRTOS license exception along with FreeRTOS; if not it
;    can be viewed here: http://www.freertos.org/a00114.html and also obtained
;    by writing to Richard Barry, contact details for whom are available on the
;    FreeRTOS WEB site.
;
;    1 tab == 4 spaces!
;
;    http://www.FreeRTOS.org - Documentation, latest information, license and
;    contact details.
;
;    http://www.SafeRTOS.com - A version that is certified for use in safety
;    critical systems.
;
;    http://www.OpenRTOS.com - Commercial support, development, porting,
;    licensing and training services.
;*/

	INCLUDE portmacro.inc

	IMPORT	vTaskSwitchContext
	IMPORT	xTaskIncrementTick

	EXPORT	vPortYieldProcessor
	EXPORT	vPortStartFirstTask
	EXPORT	vPreemptiveTick
	EXPORT	vPortYield


VICVECTADDR	EQU	0xFFFFF030
T0IR		EQU	0xE0004000
T0MATCHBIT	EQU	0x00000001

	ARM
	AREA	PORT_ASM, CODE, READONLY



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Starting the first task is done by just restoring the context 
; setup by pxPortInitialiseStack
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vPortStartFirstTask

	PRESERVE8

	portRESTORE_CONTEXT

vPortYield

	PRESERVE8

	SVC 0
	bx lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt service routine for the SWI interrupt.  The vector table is
; configured in the startup.s file.
;
; vPortYieldProcessor() is used to manually force a context switch.  The
; SWI interrupt is generated by a call to taskYIELD() or portYIELD().
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vPortYieldProcessor

	PRESERVE8

	; Within an IRQ ISR the link register has an offset from the true return 
	; address, but an SWI ISR does not.  Add the offset manually so the same 
	; ISR return code can be used in both cases.
	ADD	LR, LR, #4

	; Perform the context switch.
	portSAVE_CONTEXT					; Save current task context				
	LDR R0, =vTaskSwitchContext			; Get the address of the context switch function
	MOV LR, PC							; Store the return address
	BX	R0								; Call the contedxt switch function
	portRESTORE_CONTEXT					; restore the context of the selected task	



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt service routine for preemptive scheduler tick timer
; Only used if portUSE_PREEMPTION is set to 1 in portmacro.h
;
; Uses timer 0 of LPC21XX Family
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

vPreemptiveTick

	PRESERVE8

	portSAVE_CONTEXT					; Save the context of the current task.	

	LDR R0, =xTaskIncrementTick			; Increment the tick count.  
	MOV LR, PC							; This may make a delayed task ready
	BX R0								; to run.

	CMP R0, #0
	BEQ SkipContextSwitch
	LDR R0, =vTaskSwitchContext			; Find the highest priority task that 
	MOV LR, PC							; is ready to run.
	BX R0
SkipContextSwitch
	MOV R0, #T0MATCHBIT					; Clear the timer event
	LDR R1, =T0IR
	STR R0, [R1] 

	LDR	R0, =VICVECTADDR				; Acknowledge the interrupt	
	STR	R0,[R0]

	portRESTORE_CONTEXT					; Restore the context of the highest 
										; priority task that is ready to run.
	END

