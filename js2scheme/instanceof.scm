;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/js2scheme/instanceof.scm            */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Wed Jan 24 16:22:25 2018                          */
;*    Last change :  Sat Feb  5 15:48:50 2022 (serrano)                */
;*    Copyright   :  2018-22 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Cache instanceof tests.                                          */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __js2scheme_instanceof
   
   (include "ast.sch"
	    "usage.sch")
   
   (import __js2scheme_ast
	   __js2scheme_dump
	   __js2scheme_compile
	   __js2scheme_stage
	   __js2scheme_utils)
   
   (export j2s-instanceof-stage))

;*---------------------------------------------------------------------*/
;*    j2s-instanceof-stage ...                                         */
;*---------------------------------------------------------------------*/
(define j2s-instanceof-stage
   (instantiate::J2SStageProc
      (name "instanceof")
      (comment "Cache instanceof")
      (proc j2s-instanceof)
      (optional :optim-cinstanceof)))

;*---------------------------------------------------------------------*/
;*    j2s-instanceof ...                                               */
;*---------------------------------------------------------------------*/
(define (j2s-instanceof this::obj conf)
   (when (isa? this J2SProgram)
      (instanceof! this this conf))
   this)

;*---------------------------------------------------------------------*/
;*    instanceof! ::J2SNode ...                                        */
;*---------------------------------------------------------------------*/
(define-walk-method (instanceof! this::J2SNode prgm conf)
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    instanceof! ::J2SBinary ...                                      */
;*---------------------------------------------------------------------*/
(define-walk-method (instanceof! this::J2SBinary prgm conf)
   
   (define (get-cache prgm::J2SProgram)
      (with-access::J2SProgram prgm (pcache-size)
	 (let ((n pcache-size))
	    (set! pcache-size (+fx pcache-size 1))
	    n)))
   
   (define (immutable? expr)
      (when (isa? expr J2SRef)
	 (with-access::J2SRef expr (decl)
	    (or (decl-ronly? decl)
		(with-access::J2SProgram prgm (mode)
		   (and (not (decl-usage-has? decl '(assig)))
			(memq mode '(strict hopscript))))))))
   
   (define (object-instanceof/cache obj rhs be loc)
      (let ((cache (get-cache prgm))
	    (endloc (node-endloc rhs)))
	 (J2SIf (J2SCacheCheck 'instanceof cache (J2SUndefined) obj)
	    (J2SReturn #t (J2SBool #t) be)
	    (J2SIf (J2SCacheCheck '!instanceof cache (J2SUndefined) obj)
	       (J2SReturn #t (J2SBool #f) be)
	       (J2SIf (duplicate::J2SBinary this
			 (lhs (duplicate::J2SRef obj)))
		  (J2SBlock
		     (J2SStmtExpr (J2SCacheUpdate 'instanceof cache obj))
		     (J2SReturn #t (J2SBool #t) be))
		  (J2SBlock
		     (J2SStmtExpr (J2SCacheUpdate '!instanceof cache obj))
		     (J2SReturn #t (J2SBool #f) be)))))))
   
   (define (instanceof/cache expr lhs rhs be loc)
      (if (eq? (j2s-type lhs) 'object)
	  (object-instanceof/cache expr rhs be loc)
	  (J2SIf (J2SHopCall/type 'bool (J2SHopRef/rtype 'js-object? 'bool) expr)
	     (object-instanceof/cache expr rhs be loc)
	     (J2SReturn #t (J2SBool #f) be))))
   
   (define (instanceof-stmt lhs rhs be loc)
      (if (not (isa? lhs J2SRef))
	  (let* ((endloc (node-endloc this))
		 (id (gensym 'obj))
		 (t (j2s-type lhs))
		 (d (J2SLetOpt/vtype t '(get) id lhs)))
	     (J2SLetRecBlock #f (list d)
		(instanceof/cache (J2SRef d :type t) lhs rhs be loc)))
	  (instanceof/cache lhs lhs rhs be loc)))
   
   (with-access::J2SBinary this (op lhs rhs loc)
      (let ((ty (j2s-type lhs)))
	 (cond
	    ((and (not (type-object? ty)) (not (memq ty '(any unknown obj))))
	     (call-default-walker))
	    ((or (not (eq? op 'instanceof)) (not (immutable? rhs)))
	     (call-default-walker))
	    (else
	     (let* ((lbl '%instanceof)
		    (endloc (node-endloc this))
		    (be (J2SBindExit/type 'bool (gensym '%instanceof)
			   (J2SBlock))))
		(with-access::J2SBindExit be (stmt)
		   (set! stmt (instanceof-stmt lhs rhs be loc))
		   be)))))))
	  
