;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/hopscript/promise.scm               */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Wed Aug 19 08:19:19 2015                          */
;*    Last change :  Fri Jan 13 13:41:49 2023 (serrano)                */
;*    Copyright   :  2015-23 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Native Bigloo support of JavaScript promises                     */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0/#25.4             */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __hopscript_promise
   
   (include "../nodejs/nodejs_debug.sch")
   
   (library hop)
   
   (include "types.sch" "stringliteral.sch")
   
   (import __hopscript_types
	   __hopscript_arithmetic
	   __hopscript_lib
	   __hopscript_object
	   __hopscript_function
	   __hopscript_property
	   __hopscript_private
	   __hopscript_public
	   __hopscript_regexp
	   __hopscript_array
	   __hopscript_error
	   __hopscript_worker)

   (export (js-init-promise! ::JsGlobalObject)
	   (js-promise-async ::JsPromise ::procedure)
	   (js-promise-resolve ::JsPromise ::obj)
	   (js-promise-reject ::JsPromise ::obj)
	   (js-promise-then-catch ::JsGlobalObject ::JsPromise proc fail np)))

;*---------------------------------------------------------------------*/
;*    &begin!                                                          */
;*---------------------------------------------------------------------*/
(define __js_strings (&begin!))

;*---------------------------------------------------------------------*/
;*    object-serializer ::JsPromise ...                                */
;*---------------------------------------------------------------------*/
(register-class-serialization! JsPromise
   (lambda (o)
      o)
   (lambda (o %this)
      o))

;*---------------------------------------------------------------------*/
;*    js-unresolved ...                                                */
;*---------------------------------------------------------------------*/
(define js-unresolved (cons #f #t))

;*---------------------------------------------------------------------*/
;*    js-donate ::JsPromise ...                                        */
;*---------------------------------------------------------------------*/
(define-method (js-donate obj::JsPromise worker::WorkerHopThread %this)
   (js-undefined))

;*---------------------------------------------------------------------*/
;*    scheme->response ::JsPromise ...                                 */
;*---------------------------------------------------------------------*/
(define-method (scheme->response obj::JsPromise req ctx)
   
   (define (async-proc k)
      (with-access::JsPromise obj (worker %this)
	 (js-worker-exec worker "async-proc" #t
	    (lambda ()
	       (with-access::WorkerHopThread worker (%this)
		  (js-promise-then-catch %this obj 
		     (js-make-procedure %this
			(lambda (this resp)
			   (js-promise-async obj
			      (lambda ()
				 (k (scheme->response resp req %this)))))
			2)
		     (js-make-procedure %this
			(lambda (this rej)
			   (let ((errobj (url-path-encode
					    (obj->string rej 'hop-client))))
			      (js-promise-async obj
				 (lambda ()
				    (k (instantiate::http-response-hop
					  (start-line "HTTP/1.1 500 Internal Server Error")
					  (backend (hop-xml-backend))
					  (content-type "application/x-hop")
					  (header `((Hop-Error: . ,errobj)))
					  (value rej)
					  (ctx %this)))))))
			2)
		     obj))))))
   
   (with-access::JsPromise obj (worker)
      (with-access::WorkerHopThread worker (%this)
	 (instantiate::http-response-async
	    (async async-proc)
	    (ctx %this)))))
		
;*---------------------------------------------------------------------*/
;*    js-init-promise! ...                                             */
;*---------------------------------------------------------------------*/
(define (js-init-promise! %this::JsGlobalObject)

   (define __string_execute_first!
      (unless (vector? __js_strings) (set! __js_strings (&init!))))
   

   (define (iterable-vector this iterable::vector)
      (vector-map!
	 (lambda (o) (if (isa? o JsPromise) o (promise-resolve this o)))
	 iterable))

   (define (iterable->vector this iterable)
      
      (define (err msg)
	 (with-access::JsGlobalObject %this (js-type-error)
	    (with-access::JsPromise this (worker)
	       (js-worker-push-thunk! worker "promise"
		  (lambda ()
		     (with-handler
			(lambda (e) e)
			(js-promise-reject this
			   (js-new %this js-type-error
			      (js-string->jsstring msg)))))))))
			      
      
      (with-access::JsGlobalObject %this (js-symbol-iterator)
	 (cond
	    ((js-array? iterable)
	     (iterable-vector this (jsarray->vector iterable %this)))
	    ((isa? iterable JsGenerator)
	     (let loop ((acc '()))
		(let ((next (js-get iterable (& "next") %this)))
		   (let* ((v (js-call0 %this next iterable))
			  (done (js-get v (& "done") %this))
			  (val (js-get v (& "value") %this)))
		      (if (eq? done #t)
			  (iterable-vector this 
			     (list->vector (reverse! acc)))
			  (loop (cons val acc)))))))
	    ((js-get iterable js-symbol-iterator %this)
	     =>
	     (lambda (iterator)
		(if (not (js-procedure? iterator))
		    (err "Promise.all is not a function")
		    (let ((it (js-call0 %this iterator iterable)))
		       (let loop ((acc '()))
			  (let ((next (js-get it (& "next") %this)))
			     (if (js-procedure? next)
				 (let* ((v (js-call0 %this next it))
					(done (js-get v (& "done") %this))
					(val (js-get v (& "value") %this)))
				    (if (eq? done #t)
					(iterable-vector this 
					   (list->vector (reverse! acc)))
					(loop (cons val acc))))
				 (err
				    (format "Iterator result ~a is not an object"
				       (js-tostring it %this))))))))))
	    (else
	     (err "Promise.all is not a function")))))
   
   ;; builtin prototype
   (define js-promise-prototype
      (instantiateJsPromise
	 (worker (js-undefined))
	 (%this %this)
	 (__proto__ (js-object-proto %this))))
   
   ;; http://www.ecma-international.org/ecma-262/6.0/#sec-promise-constructor
   ;; http://www.ecma-international.org/ecma-262/6.0/#25.4.3.1
   (define (js-promise-construct o executor)
      (cond
	 ((not (js-procedure? executor))
	  (js-raise-type-error %this "argument not a procedure ~a"
	     (typeof executor)))
	 ((not (isa? o JsPromise))
	  (js-raise-type-error %this "not a promise ~a"
	     (typeof o)))
	 (else
	  (with-access::JsPromise o (state resolver rejecter thens catches %name)
	     (unless %name
		(if (isa? executor JsProcedureInfo)
		    (set! %name
		       (string->symbol
			  (format "promise~a"
			     (js-function-loc executor))))
		    (set! %name (gensym 'promise))))
	     ;; promise .5
	     (set! state 'pending)
	     (set! thens '())
	     (set! catches '())
	     ;; promise .8
	     (multiple-value-bind (resolve reject)
		(js-create-resolving-functions o)
		(set! resolver resolve)
		(set! rejecter reject)
		;; promise .9
		(with-handler
		   (lambda (e)
		      ;; promise .10.a
		      (when (>=fx (bigloo-debug) 1)
			 (exception-notify e))
		      (js-call1 %this reject (js-undefined) e)
		      o)
		   (begin
		      (js-call2 %this executor (js-undefined) resolve reject)
		      ;; promise .11
		      o)))))))
   
   ;; promise allocation
   (define (js-promise-alloc::JsPromise %this constructor::JsFunction)
      (instantiateJsPromise
	 (worker (js-current-worker))
	 (%this %this)
	 (__proto__ (js-get constructor (& "prototype") %this))))
   
   (define (js-promise-alloc/name::JsPromise %this constructor::JsFunction name)
      (let ((promise (js-promise-alloc %this constructor)))
	 (with-access::JsPromise promise (%name)
	    (set! %name name)
	    promise)))
   
   ;; then, create a HopScript object
   (define js-promise
      (with-access::JsGlobalObject %this (js-function-prototype)
	 (js-make-function %this js-promise-construct
	    (js-function-arity js-promise-construct)
	    (js-function-info :name "Promise" :len 1)
	    :__proto__ js-function-prototype
	    :prototype js-promise-prototype
	    :size 7
	    :alloc js-promise-alloc)))

   ;; http://www.ecma-international.org/ecma-262/6.0/#sec-promise.all
   ;; http://www.ecma-international.org/ecma-262/6.0/25.4.4.1 
   (define (js-promise-all this iterable)
      (let* ((promise (js-promise-alloc/name %this js-promise "all"))
	     (it (iterable->vector promise iterable)))
	 (when (vector? it)
	    (let ((count (vector-length it)))
	       (if (=fx count 0)
		   (js-promise-resolve promise
		      (js-empty-vector->jsarray %this))
		   (let loop ((i (-fx count 1)))
		      (when (>=fx i 0)
			 (js-promise-then-catch %this (vector-ref it i)
			    (js-make-function %this
			       (lambda (this result)
				  (vector-set! it i result)
				  (set! count (-fx count 1))
				  (if (=fx count 0)
				      (promise-resolve promise
					 (js-vector->jsarray it %this))
				      js-unresolved))
			       (js-function-arity 1 0)
			       (js-function-info :name "onfullfilled" :len 1))
			    (js-make-function %this
			       (lambda (this reason)
				  (promise-reject promise reason))
			       (js-function-arity 1 0)
			       (js-function-info :name "onrejected" :len 1))
			    promise)
			 (loop (-fx i 1)))
		      it))))
	 promise))

   (js-bind! %this js-promise (& "all")
      :configurable #f :enumerable #f
      :value (js-make-function %this js-promise-all
		(js-function-arity js-promise-all)
		(js-function-info :name "all" :len 1))
      :hidden-class #t)
   
   ;; http://www.ecma-international.org/ecma-262/6.0/#sec-promise.race
   (define (js-promise-race this iterable)
      (let* ((promise (js-promise-alloc/name %this js-promise "race"))
	     (it (iterable->vector promise iterable)))
	 (when (vector? it)
	    (let ((len (vector-length it)))
	       (let loop ((i 0))
		  (when (<fx i len)
		     (js-promise-then-catch %this (vector-ref it i)
			(js-make-function %this
			   (lambda (this result)
			      (promise-resolve promise result))
			   (js-function-arity 1 0)
			   (js-function-info :name "onfullfilled" :len 1))
			(js-make-function %this
			   (lambda (this reason)
			      (promise-reject promise reason))
			   (js-function-arity 1 0)
			   (js-function-info :name "onrejected" :len 1))
			promise)
		     (loop (+fx i 1)))
		  it)))
	 promise))

   (js-bind! %this js-promise (& "race")
      :configurable #f :enumerable #f
      :value (js-make-function %this js-promise-race
		(js-function-arity js-promise-race)
		(js-function-info :name "race" :len 1))
      :hidden-class #t)
   
   ;; http://www.ecma-international.org/ecma-262/6.0/#sec-promise.reject
   ;; http://www.ecma-international.org/ecma-262/6.0/#25.4.4.4.4
   (define (promise-reject this val)
      (cond
	 ((not (js-object? this))
	  ;; .2
	  (js-raise-type-error %this "This not an object ~a" (typeof this)))
	 (else
	  ;; .3
	  (let ((promise (js-promise-alloc/name %this js-promise "reject")))
	     (with-handler
		(lambda (e) e)
		(js-promise-reject promise val))
	     promise))))
   
   (js-bind! %this js-promise (& "reject")
      :configurable #f :enumerable #f
      :value (js-make-function %this promise-reject
		(js-function-arity promise-reject)
		(js-function-info :name "reject" :len 1))
      :hidden-class #t)

   ;; http://www.ecma-international.org/ecma-262/6.0/#sec-promise.resolve
   ;; http://www.ecma-international.org/ecma-262/6.0/#25.4.4.4.5
   (define (promise-resolve this val)
      (cond
	 ((not (js-object? this))
	  ;; .2
	  (js-raise-type-error %this "This not an object ~a" (typeof this)))
	 ((and (isa? val JsPromise) (eq? (js-get val (& "constructor") %this) this))
	  ;; .3
	  val)
	 (else
	  ;; .4
	  (let ((promise (js-promise-alloc/name %this js-promise "resolve")))
	     (with-handler
		(lambda (e) e)
		(js-promise-resolve promise val))
	     promise))))
   
   (js-bind! %this js-promise (& "resolve")
      :configurable #f :enumerable #f
      :value (js-make-function %this promise-resolve
		(js-function-arity promise-resolve)
		(js-function-info :name "resolve" :len 1))
      :hidden-class #t)
   
   ;; prototype properties
   (init-builtin-promise-prototype! %this js-promise-prototype)

   (with-access::JsGlobalObject %this (js-symbol-species)
      (js-bind! %this js-promise js-symbol-species
	 :configurable #f :enumerable #f :writable #f
	 :get (js-make-function %this (lambda (o) js-promise)
		 (js-function-arity 0 0)
		 (js-function-info :name "@@species" :len 0))
	 :hidden-class #t))
   
   ;; bind Promise in the global object
   (js-bind! %this %this (& "Promise")
      :configurable #f :enumerable #f :value js-promise
      :hidden-class #t)

   ;; bind the promise object in the global environment
   (with-access::JsGlobalObject %this ((%js-promise js-promise))
      (set! %js-promise js-promise))
   
   js-promise)

;*---------------------------------------------------------------------*/
;*    js-promise-then-catch ...                                        */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0/#25.4.5.3         */
;*---------------------------------------------------------------------*/
(define (js-promise-then-catch %this::JsGlobalObject this::JsPromise proc fail np)
   (with-access::JsPromise this (thens catches state val worker %name)
      ;; .5 & .6
      (let ((fullfill (cons np (if (js-procedure? proc) proc 'identity)))
	    (reject (cons np (if (js-procedure? fail) fail 'thrower))))
	 (case state
	    ((pending)
	     ;; .7
	     (set! thens (cons fullfill thens))
	     (set! catches (cons reject catches)))
	    ((fullfilled)
	     ;; .8
	     (js-worker-push-thunk! worker "promise"
		(lambda ()
		   (js-promise-reaction-job fullfill val))))
	    ((rejected)
	     ;; .9
	     (js-worker-push-thunk! worker "promise"
		(lambda ()
		   (js-promise-reaction-job reject val)))))
	 ;; .10
	 np)))

;*---------------------------------------------------------------------*/
;*    init-builtin-promise-prototype! ...                              */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0/#25.4.4.2         */
;*---------------------------------------------------------------------*/
(define (init-builtin-promise-prototype! %this::JsGlobalObject obj)

   (define (then-catch this onfullfilled onrejected)
      ;; http://www.ecma-international.org/ecma-262/6.0/#25.4.5.3
      (if (not (isa? this JsPromise))
	  ;; .2
	  (js-raise-type-error %this "argument not a promise ~a"
	     (typeof this))
	  (with-access::JsPromise this (worker %this)
	     (let ((np (duplicate::JsPromise this
			  (thens '())
			  (catches '())
			  (resolver #f)
			  (rejecter #f)
			  (elements '#())
			  (state 'pending)
			  (%name "then-catch"))))
		(js-object-proto-set! np (js-object-proto this))
		(js-object-mode-set! np (js-object-default-mode))
		(js-promise-then-catch %this this onfullfilled onrejected np)))))
      
   ;; catch
   ;; http://www.ecma-international.org/ecma-262/6.0/#25.4.5.1
   (js-bind! %this obj (& "catch")
      :value (js-make-function %this
		(lambda (this fail)
		   (then-catch this
		      (js-make-procedure %this (lambda (this v) v) 2)
		      fail))
		(js-function-arity 1 0)
		(js-function-info :name "catch" :len 1))
      :enumerable #f
      :hidden-class #t)
   
   ;; then
   ;; http://www.ecma-international.org/ecma-262/6.0/#25.4.5.3
   (js-bind! %this obj (& "then")
      :value (js-make-function %this
		(lambda (this proc fail)
		   (then-catch this proc fail))
		(js-function-arity 2 0)
		(js-function-info :name "then" :len 2))
      :enumerable #f
      :hidden-class #t))

;*---------------------------------------------------------------------*/
;*    js-create-resolving-functions ...                                */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0/#25.4.1.3         */
;*---------------------------------------------------------------------*/
(define (js-create-resolving-functions o::JsPromise)
   (let ((resolved #f))
      (with-access::JsPromise o (%this)
	 (let ((resolve (js-make-function %this
			   (lambda (_ resolution)
			      (if resolved
				  (js-undefined)
				  (begin
				     (set! resolved #t)
				     (js-promise-resolve o resolution))))
			   (js-function-arity 1 0)
			   (js-function-info :name "resolve" :len 1)))
	       (reject (js-make-function %this
			  (lambda (_ reason)
			     (if resolved
				 (js-undefined)
				 (begin
				    (set! resolved #t)
				    (js-promise-reject o reason))))
			  (js-function-arity 1 0)
			  (js-function-info :name "reject" :len 1))))
	    (values resolve reject)))))

;*---------------------------------------------------------------------*/
;*    js-reject ...                                                    */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0/#25.4.1.7         */
;*---------------------------------------------------------------------*/
(define (js-reject o reason)
   (with-access::JsPromise o (state val worker thens catches %name %this)
      ;; reject .2
      (js-worker-push-thunk! worker "promise"
	 (lambda ()
	    (let ((reactions (reverse! catches)))
	       ;; reject .3, 4, 5, 6
	       (set! val reason) 
	       (set! thens '())
	       (set! catches '())
	       (set! state 'rejected)
	       ;; hopscript extension
	       (if (null? reactions)
		   (begin
		      (when (isa? reason &exception)
			 (exception-notify reason))
		      (with-access::JsGlobalObject %this ((gworker worker))
			 (if (eq? worker gworker)
			     (error "UnhandledPromiseRejection"
				(js-tostring reason %this)
				%name)
			     (warning "UnhandledPromiseRejectionWarning: "
				(js-tostring reason %this)
				" -- " %name)))
		      reason)
		   ;; reject .7
		   (js-promise-trigger-reactions worker reactions reason)))))))

;*---------------------------------------------------------------------*/
;*    js-fullfill ...                                                  */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0/#25.4.1.4         */
;*---------------------------------------------------------------------*/
(define (js-fullfill o::JsPromise result)
   (with-access::JsPromise o (state val worker thens catches)
      ;; fullfill .2
      (js-worker-push-thunk! worker "promise"
	 (lambda ()
	    (let ((reactions (reverse! thens)))
	       ;; fullfill .3, 4, 5, 6
	       (set! val result)
	       (set! thens '())
	       (set! catches '())
	       (set! state 'fullfilled)
	       ;; fullfill .7
	       (js-promise-trigger-reactions worker reactions result))))))

;*---------------------------------------------------------------------*/
;*    js-promise-trigger-reactions ...                                 */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0/#25.4.1.8         */
;*---------------------------------------------------------------------*/
(define (js-promise-trigger-reactions worker reactions argument)
   (for-each (lambda (reaction)
		(js-promise-reaction-job reaction argument))
      reactions)
   (js-undefined))

;*---------------------------------------------------------------------*/
;*    js-promise-reaction-job ...                                      */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0/#25.4.2.1         */
;*---------------------------------------------------------------------*/
(define (js-promise-reaction-job reaction argument)
   (let ((promise (car reaction))
	 (handler (cdr reaction)))
      (with-access::JsPromise promise (%this resolver rejecter)
	 (cond
	    ((eq? handler 'identity)
	     ;; .4
	     (if (js-procedure? resolver)
		 (js-call1 %this resolver (js-undefined) argument)
		 argument))
	    ((eq? handler 'thrower)
	     ;; .5
	     (js-promise-reject promise argument))
	    (else
	     (with-handler
		(lambda (e)
		   (js-promise-reject promise e))
		(let ((hresult (js-call1 %this handler (js-undefined) argument)))
		   (unless (eq? hresult js-unresolved)
		      (js-promise-resolve promise hresult)))))))))

;*---------------------------------------------------------------------*/
;*    js-promise-reject ...                                            */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0#25.4.1.3.1        */
;*---------------------------------------------------------------------*/
(define (js-promise-reject o::JsPromise reason)
   (with-access::JsPromise o (state)
      (when (eq? state 'pending)
	 (js-reject o reason))))
	   
;*---------------------------------------------------------------------*/
;*    js-promise-resolve ...                                           */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/6.0#25.4.1.3.2        */
;*---------------------------------------------------------------------*/
(define (js-promise-resolve o::JsPromise resolution)
   
   (define (resolve-thenable o::JsPromise thenable then)
      ;; http://www.ecma-international.org/ecma-262/6.0/#25.4.2.2
      (multiple-value-bind (resolve reject)
	 (js-create-resolving-functions o)
	 (with-access::JsPromise o (%this)
	    (with-handler
	       (lambda (e)
		  (js-call1 %this reject (js-undefined) e))
	       (js-call2 %this then thenable resolve reject)))))

   (with-access::JsPromise o (%this worker)
      (cond
	 ((eq? o resolution)
	  ;; resolve .6
	  (with-access::JsGlobalObject %this (js-type-error)
	     (js-reject o
		(js-new %this js-type-error
		   (js-string->jsstring "selfResolutionError")))))
	 ((not (js-object? resolution))
	  ;; resolve .7
	  (js-fullfill o resolution))
	 (else
	  ;; resolve .8
	  (with-handler
	     (lambda (e)
		;; resolve .9.a
		(js-reject o e))
	     (let ((then (js-get resolution (& "then") %this)))
		(if (not (js-procedure? then))
		    ;; resolve .11
		    (js-fullfill o resolution)
		    ;; resolve .12
		    (js-worker-push-thunk! worker "promise"
		       (lambda ()
			  (with-handler
			     exception-notify
			     (resolve-thenable o resolution then)))))))))))

;*---------------------------------------------------------------------*/
;*    js-promise-async ...                                             */
;*---------------------------------------------------------------------*/
(define (js-promise-async o::JsPromise thunk)
   (with-access::JsPromise o (worker)
      (js-worker-push-thunk! worker "async" thunk)))

;*---------------------------------------------------------------------*/
;*    &end!                                                            */
;*---------------------------------------------------------------------*/
(&end!)
