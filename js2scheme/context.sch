;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/js2scheme/context.sch               */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Sun Apr 12 08:09:48 2020                          */
;*    Last change :  Thu Apr 14 07:17:42 2022 (serrano)                */
;*    Copyright   :  2020-22 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Scheme compilation context                                       */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    compiler-context ...                                             */
;*    -------------------------------------------------------------    */
;*    Scheme compilation context that accumulates informations about   */
;*    the compiled programs. These informations are used when          */
;*    generating the Scheme module (see scheme-program.scm).           */
;*---------------------------------------------------------------------*/
(define-struct context conf
   program
   %vectors
   array string regexp math map weakmap set weakset bigint
   object)

;*---------------------------------------------------------------------*/
;*    compiler-context ...                                             */
;*---------------------------------------------------------------------*/
(define (compiler-context conf)
   (let ((ctx (make-context #f)))
      (context-conf-set! ctx conf)
      (context-%vectors-set! ctx '())
      ctx))

;*---------------------------------------------------------------------*/
;*    new-compiler-context ...                                         */
;*---------------------------------------------------------------------*/
(define (new-compiler-context ctx . opts)
   ;; duplicate the old context
   (let ((nctx (make-context #f)))
      (let loop ((i (-fx (struct-length ctx) 1)))
	 (when (>=fx i 0)
	    (struct-set! nctx i (struct-ref ctx i))
	    (loop (-fx i 1))))
      (context-conf-set! nctx (append opts (context-conf ctx)))
      nctx))

;*---------------------------------------------------------------------*/
;*    compiler-context-set! ...                                        */
;*---------------------------------------------------------------------*/
(define (compiler-context-set! ctx . vals)
   ;; update the new fields
   (let loop ((vals vals))
      (when (pair? vals)
	 (case (car vals)
	    ((:program) (context-program-set! ctx (cadr vals)))
	    ((:array) (context-array-set! ctx (cadr vals)))
	    ((:string) (context-string-set! ctx (cadr vals)))
	    ((:regexp) (context-regexp-set! ctx (cadr vals)))
	    ((:math) (context-math-set! ctx (cadr vals)))
	    ((:map) (context-map-set! ctx (cadr vals)))
	    ((:weakmap) (context-weakmap-set! ctx (cadr vals)))
	    ((:set) (context-set-set! ctx (cadr vals)))
	    ((:weakset) (context-weakset-set! ctx (cadr vals)))
	    ((:bigint) (context-bigint-set! ctx (cadr vals)))
	    ((:object) (context-object-set! ctx (cadr vals)))
	    (else (error "compiler-context-set!" "unknown property" (car vals))))
	 (loop (cddr vals))))
   ctx)

;*---------------------------------------------------------------------*/
;*    context-get ...                                                  */
;*---------------------------------------------------------------------*/
(define (context-get ctx::struct key::keyword #!optional default)
   ;; when the new (12apr2020) version is stabilized, these checks
   ;; could be removed
   (case key
      ((:program) (error "context-get" "should use context-program" key))
      ((:array) (error "context-get" "should use context-array" key))
      ((:string) (error "context-get" "should use context-string" key))
      ((:regexp) (error "context-get" "should use context-regexp" key))
      ((:math) (error "context-get" "should use context-math" key))
      ((:object) (error "context-get" "should use context-object" key))
      ((:map) (error "context-get" "should use context-object" key))
      ((:weakmap) (error "context-get" "should use context-object" key))
      ((:set) (error "context-get" "should use context-object" key))
      ((:weakset) (error "context-get" "should use context-object" key))
      ((:bigint) (error "context-get" "should use context-object" key))
      (else (config-get (context-conf ctx) key default))))

