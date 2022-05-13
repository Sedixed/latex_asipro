; ASM file obtained from a LaTeX file

	const ax,beginning
	jmp ax

:div_err_str
@string "Erreur : Division par 0 impossible\n"

:div_err
	const ax,div_err_str
	callprintfs ax
	end

:beginning
; Stack preparation
	const bp,stack
	const sp,stack
	const ax,2
	sub sp,ax
; Reading the number -1
	const ax,-1
	push ax
; Affect a value to the variable p
	const ax,var:p
	pop bx
	storew bx,ax
; Reading the number 2
	const ax,2
	push ax
; Affect a value to the variable d
	const ax,var:d
	pop bx
	storew bx,ax
; Reading the variable named d
	const ax,var:d
	loadw bx,ax
	push bx
; Reading the number 0
	const ax,0
	push ax
; Begin of the "if" condition (0)
	pop ax
	const bx,0
	const cx,else_0
	cmp ax,bx
	jmpc cx
; True case of the "if" condition  (0)
; Reading the number 9
	const ax,9
	push ax
; Affect a value to the variable d
	const ax,var:d
	pop bx
	storew bx,ax
	const ax,end_if_0
	jmp ax
:else_0
; False case of the "if" condition (0)
; Reading the number 14
	const ax,14
	push ax
; Affect a value to the variable d
	const ax,var:d
	pop bx
	storew bx,ax
:end_if_0
; End of the loop/condition (0)
; Beginning of the "do while" loop  (1)
:while_1
; Reading the variable named d
	const ax,var:d
	loadw bx,ax
	push bx
; Reading the number 0
	const ax,0
	push ax
	pop ax
	const bx,0
	const cx,end_while_1
	cmp ax,bx
	jmpc cx
; Reading the variable named d
	const ax,var:d
	loadw bx,ax
	push bx
; Reading the number 1
	const ax,1
	push ax
; Substracting two expressions
	pop ax
	pop bx
	sub bx,ax
	push bx
; Affect a value to the variable d
	const ax,var:d
	pop bx
	storew bx,ax
	const ax,while_1
	jmp ax
:end_while_1
; End of the loop/condition (1)
; Reading the variable named d
	const ax,var:d
	loadw bx,ax
	push bx
; Reading the variable named p
	const ax,var:p
	loadw bx,ax
	push bx
; Substracting two expressions
	pop ax
	pop bx
	sub bx,ax
	push bx
; Affect a value to the variable bro
	const ax,var:bro
	pop bx
	storew bx,ax
	end

; Variable declarations

:var:bro
@int 0

:var:d
@int 0

:var:d
@int 0

:var:d
@int 0

:var:d
@int 0

:var:p
@int 0

;Stack zone
:stack
@int 0
