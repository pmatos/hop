;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/hopc/main.scm                       */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Fri Nov 12 13:30:13 2004                          */
;*    Last change :  Wed Jan  4 20:33:12 2023 (serrano)                */
;*    Copyright   :  2004-23 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    The HOPC entry point                                             */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module hopc

   (library scheme2js hopscheme js2scheme hop)

   (import  hopc_parseargs
	    hopc_param
	    hopc_driver)

   (with    hop_param)
   
   (eval    (library hop))

   (main    main))

;*---------------------------------------------------------------------*/
;*    main ...                                                         */
;*---------------------------------------------------------------------*/
(define (main args)
   ;; no debug by default
   (bigloo-warning-set! 1)
   (let ((trace (getenv "BIGLOOTRACE")))
      (bigloo-debug-set! (if (string? trace) 1 0)))
   ;; set the Hop cond-expand identification
   (register-srfi! 'hopc)
   (for-each register-eval-srfi! (hop-srfis))
   ;; set the library load path
   (bigloo-library-path-set! (hop-library-path))
   ;; define the Hop macros
   (hop-install-expanders!)
   ;; disable caching
   (hop-cache-enable-set! #f)
   ;; parse the command line
   (let ((exprs (parse-args args)))
      ;; access file
      (cond
	 ((string? (hopc-access-file))
	  (module-load-access-file (hopc-access-file)))
	 ((file-exists? ".afile")
	  (module-load-access-file ".afile")))
      ;; setup the client-side compiler
      (setup-client-compiler!)
      ;; setup the hop module resolvers
      (bigloo-module-resolver-set!
	 (make-hop-module-resolver (bigloo-module-resolver)))
      ;; evaluate the command line expressions
      (for-each (lambda (expr)
		   (with-input-from-string expr
		      (lambda ()
			 (let ((sexp (hopc-read (current-input-port))))
			    (with-handler
			       (lambda (e)
				  (if (isa? e &eval-warning)
				      (begin
					 (warning-notify e)
					 #unspecified)
				      (raise e)))
			       (eval sexp))))))
	 exprs)
      ;; start the compilation stage
      (with-handler
	 (lambda (e)
	    (exception-notify e)
	    (exit 1))
	 (if (hopc-jsheap)
	     ;; generate a js heap file from the source
	     (jsheap)
	     ;; compile the source file
	     (compile-sources)))))

