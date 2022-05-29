; ASM file obtained from a LaTeX file

	const ax,main
	jmp ax

:div_err_str
@string "Erreur : Division par 0 impossible\n"

:div_err
	const ax,div_err_str
	callprintfs ax
	end

:factorielle
; Get the n variable and push it in the top of the stack
	const ax,2
	const bx,1
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
; Reading the number 0
	const ax,0
; Push a temp variable on the stack
	push ax
; Comparison number of type "equals" (ID: 0)
	pop ax
	pop bx
	const cx,equals_0
	cmp ax,bx
	jmpc cx
; False case (ID: 0)
	const ax,0
	push ax
	const ax,end_equals_0
	jmp ax
; True case (ID: 0)
:equals_0
	const ax,1
	push ax
; End of comparison number of type "equals" (ID: 0)
:end_equals_0
; Begin of the "if" condition (ID: 1)
	pop ax
	const bx,0
	const cx,else_1
	cmp ax,bx
	jmpc cx
; True case of the "if" condition (ID: 1)
; Reading the number 1
	const ax,1
; Push a temp variable on the stack
	push ax
	pop ax
	ret
	const ax,end_if_1
	jmp ax
:else_1
; False case of the "if" condition (ID: 1)
:end_if_1
; End of the loop/condition (ID: 1)
; Get the n variable and push it in the top of the stack
	const ax,2
	const bx,1
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
; Get the n variable and push it in the top of the stack
	const ax,2
	const bx,2
	mul ax,bx
	cp bx,sp
	sub bx,ax
	loadw ax,bx
	push ax
; Reading the number 1
	const ax,1
; Push a temp variable on the stack
	push ax
; Substracting two expressions
	pop ax
	pop bx
	sub bx,ax
; Push a temp variable on the stack
	push bx
; Call the factorielle function
	const bx,factorielle
	call bx
; Pop the called function args
	pop dx
; Push the returned value on the stack
; Push a temp variable on the stack
	push ax
; Multiplying two expressions
	pop ax
	pop bx
	mul ax,bx
; Push a temp variable on the stack
	push ax
	pop ax
	ret

:main
; Stack initialisation
	const bp,stack
	const sp,stack
	const ax,2
	sub sp,ax
; Build parameters
	const ax,7
	push ax
; Call the factorielle function
	const ax,factorielle
	call ax
; Get the result and print it
	push ax
	cp ax,sp
	callprintfd ax
	end

; Stack zone
:stack
@int 0
