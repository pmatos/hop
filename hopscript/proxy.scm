;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/hopscript/proxy.scm                 */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Sun Dec  2 20:51:44 2018                          */
;*    Last change :  Mon Feb  7 08:10:11 2022 (serrano)                */
;*    Copyright   :  2018-22 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Native Bigloo support of JavaScript proxy objects.               */
;*    -------------------------------------------------------------    */
;*    https://developer.mozilla.org/en-US/docs/Web/JavaScript/         */
;*       Reference/Global_Objects/Proxy                                */ 
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __hopscript_proxy
   
   (include "../nodejs/nodejs_debug.sch")
   
   (library hop)
   
   (include "types.sch" "stringliteral.sch" "property.sch")
   
   (import __hopscript_types
	   __hopscript_arithmetic
	   __hopscript_lib
	   __hopscript_object
	   __hopscript_function
	   __hopscript_property
	   __hopscript_private
	   __hopscript_public
	   __hopscript_array
	   __hopscript_error
	   __hopscript_profile)
   
   (export (js-init-proxy! ::JsGlobalObject)
	   (js-proxy-target*::JsObject ::JsProxy)
	   (inline js-new-proxy ::JsGlobalObject ::obj ::obj)
	   (inline js-new-proxy/caches ::JsGlobalObject ::obj ::obj
	      ::JsPropertyCache ::JsPropertyCache ::JsPropertyCache)
	   (js-proxy-debug-name::bstring ::JsProxy ::JsGlobalObject)
	   (js-proxy-property-value ::JsObject ::JsProxy ::obj ::JsGlobalObject)
	   (js-get-proxy ::JsProxy prop ::JsGlobalObject)
	   (js-get-proxy-name/cache-miss ::JsObject
	      ::obj ::bool ::JsGlobalObject ::JsPropertyCache)
	   (js-put-proxy-name/cache-miss! ::JsObject ::JsStringLiteral
	      ::obj ::bool
	      ::JsGlobalObject
	      ::JsPropertyCache ::long ::bool)
	   (inline js-proxy-property-descriptor-index ::JsProxy ::obj)
	   (inline js-proxy-typeof ::JsProxy ::JsGlobalObject)
	   (js-call-proxy/cache-miss0 ::JsGlobalObject
	      ::JsProxy ::obj)
	   (js-call-proxy/cache-miss1 ::JsGlobalObject
	      ::JsProxy ::obj a0)
	   (js-call-proxy/cache-miss2 ::JsGlobalObject
	      ::JsProxy ::obj a0 a1)
	   (js-call-proxy/cache-miss3 ::JsGlobalObject
	      ::JsProxy ::obj a0 a1 a2)
	   (js-call-proxy/cache-miss4 ::JsGlobalObject
	      ::JsProxy ::obj a0 a1 a2 a3)
	   (js-call-proxy/cache-miss5 ::JsGlobalObject
	      ::JsProxy ::obj a0 a1 a2 a3 a4)
	   (js-call-proxy/cache-miss6 ::JsGlobalObject
	      ::JsProxy ::obj a0 a1 a2 a3 a4 a5)
	   (js-call-proxy/cache-miss7 ::JsGlobalObject
	      ::JsProxy ::obj a0 a1 a2 a3 a4 a5 a6)
	   (js-call-proxy/cache-miss8 ::JsGlobalObject
	      ::JsProxy ::obj a0 a1 a2 a3 a4 a5 a6 a7)
	   (js-call-proxy/cache-miss9 ::JsGlobalObject
	      ::JsProxy ::obj a0 a1 a2 a3 a4 a5 a6 a7 a8)
	   (js-call-proxy/cache-miss10 ::JsGlobalObject
	      ::JsProxy ::obj a0 a1 a2 a3 a4 a5 a6 a7 a8 a9)))

;*---------------------------------------------------------------------*/
;*    &begin!                                                          */
;*---------------------------------------------------------------------*/
(define __js_strings (&begin!))

;*---------------------------------------------------------------------*/
;*    js-debug-object ::JsProxy ...                                    */
;*---------------------------------------------------------------------*/
(define-method (js-debug-object obj::JsProxy #!optional (msg ""))
   (with-access::JsProxy obj (handler)
      (call-next-method)
      (fprint (current-error-port) ">>>>> target: ")
      (js-debug-object (js-proxy-target obj))
      (fprint (current-error-port) ">>>>> handler: ")
      (js-debug-object handler)))

;*---------------------------------------------------------------------*/
;*    js-proxy-target* ...                                             */
;*---------------------------------------------------------------------*/
(define (js-proxy-target* o)
   (let ((o (js-proxy-target o)))
      (if (js-proxy? o)
	  (js-proxy-target* o)
	  o)))

;*---------------------------------------------------------------------*/
;*    jsarray ...                                                      */
;*---------------------------------------------------------------------*/
(define-macro (jsarray %this . args)
   `(let ((a (js-array-construct-alloc-small-sans-init ,%this
		 ,(fixnum->uint32 (length args)))))
       (with-access::JsArray a (vec ilen length)
	  (let ((v vec))
	     ,@(map (lambda (i o)
		       `(vector-set! v ,i ,o))
		  (iota (length args)) args)
	     (set! ilen ,(fixnum->uint32 (length args)))
	     (set! length ,(fixnum->uint32 (length args)))
	     a))))

;*---------------------------------------------------------------------*/
;*    local caches                                                     */
;*---------------------------------------------------------------------*/
(define proxy-cmap
   ;; this cmap is shared by all proxy objects
   (js-make-jsconstructmap
      :methods '#(#f)
      :props '#()))

(define proxy-elements #f)

;*---------------------------------------------------------------------*/
;*    js-init-proxy! ...                                               */
;*---------------------------------------------------------------------*/
(define (js-init-proxy! %this::JsGlobalObject)
   
   (unless (vector? __js_strings) (set! __js_strings (&init!)))

   (unless proxy-elements
      (set! proxy-elements
	 (vector
	    (instantiate::JsWrapperDescriptor
	       (writable #t)
	       (configurable #t)
	       (enumerable #t)
	       (name (& "%%proxy"))
	       (%get js-proxy-property-value)
	       (%set js-proxy-property-value-set!))))
      ($js-init-jsalloc-proxy proxy-cmap proxy-elements (js-proxy-default-mode)))

   (with-access::JsGlobalObject %this (js-function-prototype js-proxy js-proxy-pcache)

      (define (js-proxy-alloc %this constructor::JsFunction)
	 (js-new-target-push! %this constructor)
	 ;; not used in optimized code, see below
	 ;; js-new-proxy and js-new-proxy/caches
	 (js-new-proxy %this '() (class-nil JsObject)))
	 
      (define (js-proxy-construct this::JsProxy t h)
	 (cond
	    ((not (js-object? h))
	     (js-raise-type-error %this
		"Cannot create proxy with a non-object as handler" this))
	    ((not (js-object? t))
	     (js-raise-type-error %this
		"Cannot create proxy with a non-object as target" this))
	    (else
	     (with-access::JsProxy this (handler id)
		(js-proxy-target-set! this t)
		(when (js-procedure? t)
		   ;; mark proxy targetting function to enable
		   ;; fast js-proxy-function? predicate (see types.scm)
		   (js-proxy-mode-function-set! this #t))
		(set! handler h))))
	 this)

      (define js-proxy-revoke
	 (js-make-function %this
	    (lambda (this)
	       (let ((prox (js-get this (& "proxy") %this)))
		  (if (js-proxy? prox)
		      (js-proxy-mode-revoked-set! prox #t)
		      (js-raise-type-error %this
			 "Not a Revocable proxy" this))))
	    (js-function-arity 0 0)
	    (js-function-info :name "revoke" :len 0)
	    :prototype '()))

      ;; create a HopScript object
      (define (%js-proxy this t h)
	 (cond
	    ((eq? (js-new-target-pop! %this) (js-undefined))
	     (js-raise-type-error %this "Constructor Proxy requires 'new'" this))
	    ((not (js-object? h))
	     (js-raise-type-error %this
		"Cannot create proxy with a non-object as handler" this))
	    ((not (js-object? t))
	     (js-raise-type-error %this
		"Cannot create proxy with a non-object as target" this))
	    (else
	     (with-access::JsProxy this (handler id)
		(js-proxy-target-set! this t)
		(when (js-procedure? t)
		   ;; mark proxy targetting function to enable
		   ;; fast js-proxy-function? predicate (see types.scm)
		   (js-proxy-mode-function-set! this #t))
		(set! handler h))))
	 this)

      ;; create a revokable proxy
      (define (%js-revocable this t h)
	 (js-plist->jsobject
	    `(:proxy ,(js-proxy-construct (js-proxy-alloc %this js-proxy) t h)
		:revoke ,js-proxy-revoke)
	    %this))

      (set! js-proxy
	 (js-make-function %this %js-proxy
	    (js-function-arity %js-proxy)
	    (js-function-info :name "Proxy" :len 2)
	    :__proto__ js-function-prototype
	    :prototype '()
	    :alloc js-proxy-alloc
	    :size 1))

      ;; WARNING!!! as there is no prototype, js-make-function will
      ;; have replaced alloc with  js-object-alloc-lazy
      (with-access::JsFunction js-proxy (alloc)
	 (set! alloc js-proxy-alloc))

      (set! js-proxy-pcache
	 ((@ js-make-pcache-table __hopscript_property) 3 "proxy"))
      
      (js-bind! %this js-proxy (& "revocable")
	 :writable #t :configurable #t :enumerable #f
	 :value (js-make-function %this %js-revocable
		   (js-function-arity %js-revocable)
		   (js-function-info :name "revocable" :len 2)
		   :__proto__ js-function-prototype
		   :prototype '())
	 :hidden-class #t)

      ;; bind Proxy in the global object
      (js-bind! %this %this (& "Proxy")
	 :writable #t :configurable #t :enumerable #f
	 :value js-proxy :hidden-class #t)
	 
      js-proxy))

;*---------------------------------------------------------------------*/
;*    js-new-proxy ...                                                 */
;*---------------------------------------------------------------------*/
(define-inline (js-new-proxy %this target handler)
   (let ((o ($js-make-jsproxy
	       target handler
	       (instantiate::JsPropertyCache)
	       (instantiate::JsPropertyCache)
	       (instantiate::JsPropertyCache)
	       (js-proxy-default-mode))))
      (when (js-procedure-proxy? target)
	 (js-proxy-mode-function-set! o #t))
      o))

;*---------------------------------------------------------------------*/
;*    js-new-proxy/caches ...                                          */
;*---------------------------------------------------------------------*/
(define-inline (js-new-proxy/caches %this target handler gcache scache acache)
   (let ((o ($js-make-jsproxy
	       target handler
	       gcache scache acache
	       (js-proxy-default-mode))))
      (when (js-procedure-proxy? target)
	 (js-proxy-mode-function-set! o #t))
      o))

;*---------------------------------------------------------------------*/
;*    js-proxy-debug-name ...                                          */
;*---------------------------------------------------------------------*/
(define (js-proxy-debug-name::bstring obj::JsProxy %this)
   (let ((target (js-proxy-target obj)))
      (if (js-function? target)
	  (js-function-debug-name target %this)
	  "proxy")))

;*---------------------------------------------------------------------*/
;*    js-proxy-property-descriptor-index ...                           */
;*    -------------------------------------------------------------    */
;*    Returns a fake generic property descriptor unique to the         */
;*    proxy object.                                                    */
;*---------------------------------------------------------------------*/
(define-inline (js-proxy-property-descriptor-index obj::JsProxy prop)
   0)

;*---------------------------------------------------------------------*/
;*    js-proxy-property-value ...                                      */
;*    -------------------------------------------------------------    */
;*    Although almost similar to JS-GET ::JsProxy, this code differs   */
;*    when no proxy GET handler is defined and then two different      */
;*    functions have to be used.                                       */
;*---------------------------------------------------------------------*/
(define (js-proxy-property-value obj proxy prop %this)
   
   (define (check target v)
      (cond
	 ((js-object-mode-plain? target)
	  v)
	 (else
	  (proxy-check-property-value target obj prop %this v (& "get")))))

   (with-access::JsProxy proxy (handler getcache)
      (proxy-check-revoked! proxy "get" %this)
      (let ((target (js-proxy-target proxy))
	    (get (js-get-jsobject-name/cache handler (& "get") #f %this
		    getcache -1 '(imap emap cmap pmap amap vtable))))
	 (cond
	    ((js-procedure? get)
	     (with-access::JsProcedure get (procedure)
		(check target 
		   (if (=fx (js-procedure-arity get) 3)
		       (procedure handler target prop)
		       (js-call3 %this get handler target prop obj)))))
	    ((eq? get (js-undefined))
	     ;; the difference with JS-GET is here...
	     (js-get-jsobject target obj prop %this))
	    ((js-proxy? get)
	     (check target
		(js-call3 %this get handler target prop obj)))
	    (else
	     (js-raise-type-error %this "not a function" get))))))

;*---------------------------------------------------------------------*/
;*    js-proxy-property-value-set! ...                                 */
;*---------------------------------------------------------------------*/
(define (js-proxy-property-value-set! obj v proxy prop %this)
   
   (define (check target v r)
      (cond
	 ((not (js-totest r))
	  (js-raise-type-error %this
	     "Proxy \"set\" returns false on property \"~a\""
	     prop))
	 ((js-object-mode-plain? target)
	  r)
	 (else
	  (proxy-check-property-value target obj prop %this v (& "set")))))

   (with-access::JsProxy proxy (handler setcache)
      (proxy-check-revoked! proxy "put" %this)
      (let ((target (js-proxy-target proxy))
	    (set (js-get-jsobject-name/cache handler (& "set") #f %this
		    setcache -1 '(imap emap cmap pmap amap vtable))))
	 (cond
	    ((js-procedure? set)
	     (check target v
		(js-call4 %this set handler target prop v obj)))
	    ((eq? set (js-undefined))
	     (if (eq? proxy obj)
		 (js-put/cache! target prop v #f %this)
		 (js-absent)))
	    ((js-proxy? set)
	     (check target v (js-call4 %this set handler target prop v obj)))
	    ((eq? proxy obj)
	     (js-put/cache! target prop v #f %this))
	    (else
	     (js-absent))))))

;*---------------------------------------------------------------------*/
;*    js-proxy-typeof ...                                              */
;*---------------------------------------------------------------------*/
(define-inline (js-proxy-typeof o::JsProxy %this::JsGlobalObject)
   (js-typeof (js-proxy-target o) %this))

;*---------------------------------------------------------------------*/
;*    js-jsproxy-get ...                                               */
;*    -------------------------------------------------------------    */
;*    This function is called when an inline cache is armed for        */
;*    proxy (amap cache hit) and when the proxy wrapper accesor        */
;*    is called (see property_expd.sch).                               */
;*---------------------------------------------------------------------*/
(define-inline (js-jsproxy-get proxy::JsProxy prop %this::JsGlobalObject)

   (define (check o target v)
      (if (js-object-mode-plain? target)
	  v
	  (proxy-check-property-value target o prop %this v (& "get"))))

   (with-access::JsProxy proxy (handler getcache)
      (proxy-check-revoked! proxy "get" %this)
      (let ((target (js-proxy-target proxy))
	    (get (js-get-jsobject-name/cache handler (& "get") #f %this
		    getcache -1 '(imap emap cmap pmap amap vtable))))
	 (cond
	    ((js-procedure? get)
	     (with-access::JsProcedure get (procedure)
		(check proxy target
		   (if (=fx (js-procedure-arity get) 3)
		       (procedure handler target prop)
		       (js-call3 %this get handler target prop proxy)))))
	    ((eq? get (js-undefined))
	     (js-get-jsobject target proxy (js-toname prop %this) %this))
	    ((js-proxy? get)
	     (check proxy target
		(js-call3 %this get handler target prop proxy)))
	    (else
	     (js-raise-type-error %this "not a function" get))))))

;*---------------------------------------------------------------------*/
;*    js-get-proxy ...                                                 */
;*---------------------------------------------------------------------*/
(define (js-get-proxy proxy::JsProxy prop %this::JsGlobalObject)
   (js-jsproxy-get proxy prop %this))

;*---------------------------------------------------------------------*/
;*    js-get ::JsProxy ...                                             */
;*    -------------------------------------------------------------    */
;*    See JS-PROXY-PROPERTY-VALUE.                                     */
;*---------------------------------------------------------------------*/
(define-method (js-get o::JsProxy prop %this::JsGlobalObject)
   (let ((name (js-toname prop %this)))
      (js-profile-log-get name -1)
      (js-jsproxy-get o name %this)))

;*---------------------------------------------------------------------*/
;*    js-get-proxy-name/cache-miss ...                                 */
;*    -------------------------------------------------------------    */
;*    The performance of cache misses only matters for proxy object.   */
;*    The purpose of this function is to favor them by eliminating the */
;*    cost of an expensive generic function dispatch.                  */
;*---------------------------------------------------------------------*/
(define (js-get-proxy-name/cache-miss o::JsObject
	   name::obj
	   throw::bool %this::JsGlobalObject
	   cache::JsPropertyCache)
   (if (js-proxy? o)
       (js-jsproxy-get o name %this)
       (with-access::JsPropertyCache cache (xmap pmap amap)
	  (with-access::JsObject o (cmap)
	     (let ((omap cmap))
		(cond
		   ((eq? omap pmap)
		    (let ((idx (js-pcache-pindex cache))
			  (own (js-pcache-owner cache)))
		       (cond-expand
			  (profile
			   (js-profile-log-cache cache :pmap #t)
			   (js-profile-log-index idx)))
		       (js-object-ref own idx)))
		   ((eq? omap amap)
		    (let* ((idx (js-pcache-aindex cache))
			   (own (js-pcache-owner cache)))
		       (let ((desc (js-object-ref own idx)))
			  (cond-expand
			     (profile
			      (js-profile-log-cache cache :amap #t)
			      (js-profile-log-index idx)))
			  (js-property-value o own name desc %this))))
		   ((eq? omap xmap)
		    (cond-expand
		       (profile (js-profile-log-cache cache :xmap #t)))
		    (js-undefined))
		   (else
		    (js-get-jsobject-name/cache-miss o name throw %this cache))))))))

;*---------------------------------------------------------------------*/
;*    js-get-jsobject-name/cache-miss ::JsProxy ...                    */
;*---------------------------------------------------------------------*/
(define-method (js-get-jsobject-name/cache-miss proxy::JsProxy
		  prop::obj
		  throw::bool %this::JsGlobalObject
		  cache::JsPropertyCache)
   (js-jsproxy-get proxy prop %this))

;*---------------------------------------------------------------------*/
;*    js-proxy-put! ...                                                */
;*---------------------------------------------------------------------*/
(define-inline (js-proxy-put! o::JsProxy prop::JsStringLiteral v::obj
		  throw %this::JsGlobalObject)
   (proxy-check-revoked! o "put" %this)
   (with-access::JsProxy o (handler setcache)
      (let ((target (js-proxy-target o))
	    (set (js-get-jsobject-name/cache handler (& "set") #f %this
		    setcache point '(imap emap cmap pmap amap vtable))))
	 (cond
	    ((and (js-procedure? set) (=fx (js-procedure-arity set) 4))
	     (unless (js-object-mode-plain? target)
		(proxy-check-property-value target target prop %this v (& "set")))
	     (with-access::JsFunction set (procedure)
		(procedure handler target prop v)))
	    ((js-procedure? set)
	     (unless (js-object-mode-plain? target)
		(proxy-check-property-value target target prop %this v (& "set")))
	     (js-call4 %this set handler target prop v o))
	    ((js-proxy? set)
	     (js-call4 %this set handler target prop v o))
	    (else
	     (js-put! target prop v throw %this))))))

;*---------------------------------------------------------------------*/
;*    js-put! ::JsProxy ...                                            */
;*---------------------------------------------------------------------*/
(define-method (js-put! o::JsProxy prop v throw %this::JsGlobalObject)
   (let ((name (js-toname prop %this)))
      (cond-expand (profile (js-profile-log-put name -1)))
      (js-proxy-put! o name v throw %this)))

;*---------------------------------------------------------------------*/
;*    js-put/cache! ::JsProxy ...                                      */
;*---------------------------------------------------------------------*/
(define-method (js-put/cache! o::JsProxy prop v::obj throw::bool %this
		  #!optional (point -1) (cspecs '()) (cachefun #t))
   
   (let ((name (js-toname prop %this)))
      (cond-expand (profile (js-profile-log-put name -1)))
      (js-proxy-put! o name v throw %this)))

;*---------------------------------------------------------------------*/
;*    js-put-proxy-name/cache-miss! ...                                */
;*---------------------------------------------------------------------*/
(define (js-put-proxy-name/cache-miss! o::JsObject
	   prop::JsStringLiteral v::obj throw::bool
	   %this::JsGlobalObject cache::JsPropertyCache
	   point::long cachefun::bool)
   (if (js-proxy? o)
       (js-proxy-put! o prop v throw %this)
       (js-put-jsobject-name/cache-miss! o prop v throw %this cache
	  point cachefun)))

;*---------------------------------------------------------------------*/
;*    js-put-jsobject-name/cache-miss! ::JsProxy ...                   */
;*---------------------------------------------------------------------*/
(define-method (js-put-jsobject-name/cache-miss! o::JsProxy
		  prop::JsStringLiteral v::obj throw::bool
		  %this::JsGlobalObject
		  cache::JsPropertyCache point cachefun)
   (js-proxy-put! o prop v throw %this))

;*---------------------------------------------------------------------*/
;*    js-delete! ::JsProxy ...                                         */
;*---------------------------------------------------------------------*/
(define-method (js-delete! o::JsProxy p throw %this)
   (proxy-check-revoked! o "delete" %this)
   (with-access::JsProxy o ( handler)
      (let ((target (js-proxy-target o))
	    (delete (js-get-jsobject handler handler (& "deleteProperty") %this)))
	 (if (or (js-procedure? delete) (js-proxy? delete))
	     (let ((r (js-call2 %this delete o target p)))
		(proxy-check-property-delete target p %this r))
	     (js-delete! target p throw %this)))))

;*---------------------------------------------------------------------*/
;*    js-has-property ::JsProxy ...                                    */
;*---------------------------------------------------------------------*/
(define-method (js-has-property o::JsProxy p::obj %this)
   (with-access::JsProxy o (handler)
      (let ((target (js-proxy-target o))
	    (has (js-get-jsobject handler handler (& "has") %this)))
	 (if (or (js-procedure? has) (js-proxy? has))
	     (let ((v (js-call2 %this has o target p)))
		(or v (proxy-check-property-has target p %this v)))
	     (js-has-property target p %this)))))

;*---------------------------------------------------------------------*/
;*    js-has-own-property ::JsProxy ...                                */
;*---------------------------------------------------------------------*/
(define-method (js-has-own-property o::JsProxy p::obj %this)
   (proxy-check-revoked! o "has" %this)
   (with-access::JsProxy o (handler)
      (let ((target (js-proxy-target o))
	    (has (js-get-jsobject handler handler (& "has") %this)))
	 (if (or (js-procedure? has) (js-proxy? has))
	     (js-call2 %this has o target p)
	     (js-has-own-property target p %this)))))

;*---------------------------------------------------------------------*/
;*    js-get-own-property ::JsProxy ...                                */
;*---------------------------------------------------------------------*/
(define-method (js-get-own-property o::JsProxy p::obj %this)
   (proxy-check-revoked! o "getOwn" %this)
   (with-access::JsProxy o (handler)
      (let ((target (js-proxy-target o))
	    (get (js-get-jsobject handler handler (& "getOwnPropertyDescriptor") %this)))
	 (if (or (js-procedure? get) (js-proxy? get))
	     (let ((desc (js-call2 %this get o target p)))
		(proxy-check-property-getown target p %this desc))
	     (js-get-own-property target p %this)))))

;*---------------------------------------------------------------------*/
;*    js-get-own-property-descriptor ::JsProxy ...                     */
;*---------------------------------------------------------------------*/
(define-method (js-get-own-property-descriptor o::JsProxy p::obj %this)
   (js-from-property-descriptor %this o (js-get-own-property o p %this) o))

;*---------------------------------------------------------------------*/
;*    js-for-in ::JsProxy ...                                          */
;*---------------------------------------------------------------------*/
(define-method (js-for-in o::JsProxy proc %this)
   (proxy-check-revoked! o "for..in" %this)
   (js-for-in (js-proxy-target o) proc %this))

;*---------------------------------------------------------------------*/
;*    js-define-own-property ::JsProxy ...                             */
;*---------------------------------------------------------------------*/
(define-method (js-define-own-property::bool o::JsProxy p
		  desc::JsPropertyDescriptor throw::bool %this)
   (proxy-check-revoked! o "defineProperty" %this)
   (with-access::JsProxy o (handler)
      (let ((target (js-proxy-target o))
	    (def (js-get-jsobject handler handler (& "defineProperty") %this)))
	 (cond
	    ((or (js-procedure? def) (js-proxy? def))
	     (let ((v (js-call3 %this def o target p
			 (js-from-property-descriptor %this p desc target))))
		(proxy-check-property-defprop target o p %this desc v)))
	    (else
	     (js-define-own-property target p desc throw %this))))))

;*---------------------------------------------------------------------*/
;*    js-getprototypeof ::JsProxy ...                                  */
;*---------------------------------------------------------------------*/
(define-method (js-getprototypeof o::JsProxy %this::JsGlobalObject msg::obj)
   (proxy-check-revoked! o "getPrototypeOf" %this)
   (with-access::JsProxy o (handler)
      (let ((target (js-proxy-target o))
	    (get (js-get-jsobject handler handler (& "getPrototypeOf") %this)))
	 (if (or (js-procedure? get) (js-proxy? get))
	     (let ((v (js-call1 %this get o target)))
		(proxy-check-property-getproto target o %this msg v))
	     (js-getprototypeof target %this msg)))))

;*---------------------------------------------------------------------*/
;*    js-setprototypeof ::JsProxy ...                                  */
;*---------------------------------------------------------------------*/
(define-method (js-setprototypeof o::JsProxy v %this::JsGlobalObject msg::obj)
   (proxy-check-revoked! o "setPrototypeOf" %this)
   (with-access::JsProxy o (handler)
      (let ((target (js-proxy-target o))
	    (set (js-get-jsobject handler handler (& "setPrototypeOf") %this)))
	 (if (or (js-procedure? set) (js-proxy? set))
	     (let ((r (js-call2 %this set o target v)))
		(proxy-check-property-setproto target o v %this msg r)
		o)
	     (js-setprototypeof target v %this msg)))))

;*---------------------------------------------------------------------*/
;*    js-extensible? ::JsProxy ...                                     */
;*---------------------------------------------------------------------*/
(define-method (js-extensible? o::JsProxy %this::JsGlobalObject)
   (proxy-check-revoked! o "isExtensible" %this)
   (with-access::JsProxy o (handler)
      (let ((target (js-proxy-target o))
	    (ise (js-get-jsobject handler handler (& "isExtensible") %this)))
	 (if (or (js-procedure? ise) (js-proxy? ise))
	     (let ((r (js-call1 %this ise o target)))
		(proxy-check-is-extensible target o %this r))
	     (js-extensible? target %this)))))

;*---------------------------------------------------------------------*/
;*    js-preventextensions ::JsProxy ...                               */
;*---------------------------------------------------------------------*/
(define-method (js-preventextensions o::JsProxy %this::JsGlobalObject)
   (proxy-check-revoked! o "preventExtensions" %this)
   (with-access::JsProxy o ( handler)
      (let ((target (js-proxy-target o))
	    (p (js-get-jsobject handler handler (& "preventExtensions") %this)))
	 (if (or (js-procedure? p) (js-proxy? p))
	     (let ((r (js-call1 %this p o target)))
		(proxy-check-preventext target o %this r))
	     (js-preventextensions target %this)))))

;*---------------------------------------------------------------------*/
;*    js-ownkeys ::JsProxy ...                                         */
;*---------------------------------------------------------------------*/
(define-method (js-ownkeys o::JsProxy %this::JsGlobalObject)
   (proxy-check-revoked! o "ownKeys" %this)
   (with-access::JsProxy o (handler)
      (let ((target (js-proxy-target o))
	    (ownk (js-get-jsobject handler handler (& "ownKeys") %this)))
	 (if (or (js-procedure? ownk) (js-proxy? ownk))
	     (let ((r (js-call1 %this ownk o target)))
		(proxy-check-ownkeys target o %this r))
	     (js-ownkeys target %this)))))

;*---------------------------------------------------------------------*/
;*    proxy-check-revoked! ...                                         */
;*---------------------------------------------------------------------*/
(define-inline (proxy-check-revoked! o::JsProxy action %this::JsGlobalObject)
   (when (js-proxy-mode-revoked? o)
      (js-raise-type-error %this
	 (format "Cannot perform ~s on a revoked proxy" action)
	 (js-string->jsstring (typeof o)))))

;*---------------------------------------------------------------------*/
;*    proxy-check-property-value ...                                   */
;*---------------------------------------------------------------------*/
(define (proxy-check-property-value target owner prop %this v get-or-set)
   (cond
      ((and (not (js-object-mapped? target))
	    (if (js-object-hashed? target)
		(with-access::JsObject target (elements)
		   (=fx (hashtable-size elements) 0))
		(=fx (js-object-length target) 0)))
       v)
      (else
       (let ((prop (js-get-own-property target prop %this)))
	  (if (eq? prop (js-undefined))
	      v
	      (with-access::JsPropertyDescriptor prop (configurable)
		 (cond
		    (configurable
		     v)
		    ((isa? prop JsValueDescriptor)
		     (with-access::JsValueDescriptor prop (writable value)
			(if (or writable (js-strict-equal? value v))
			    v
			    (js-raise-type-error %this
			       (format "Proxy \"~a\" inconsistency" get-or-set)
			       owner))))
		    ((isa? prop JsAccessorDescriptor)
		     (with-access::JsAccessorDescriptor prop (get set)
			(cond
			   ((and (eq? get (js-undefined))
				 (eq? get-or-set (& "get")))
			    (js-raise-type-error %this
			       "Proxy \"get\" inconsistency"
			       owner))
			   ((and (eq? set (js-undefined))
				 (eq? get-or-set (& "set")))
			    (js-raise-type-error %this
			       "Proxy \"set\" inconsistency"
			       owner))
			   (else
			    v))))
		    (else
		     v))))))))

;*---------------------------------------------------------------------*/
;*    proxy-check-property-has ...                                     */
;*---------------------------------------------------------------------*/
(define (proxy-check-property-has target prop %this v)
   (let ((prop (js-get-own-property target prop %this)))
      (if (eq? prop (js-undefined))
	  v
	  (with-access::JsPropertyDescriptor prop (configurable)
	     (if (and configurable (js-object-mode-extensible? target))
		 v
		 (js-raise-type-error %this "Proxy \"has\" inconsistency"
		    target))))))

;*---------------------------------------------------------------------*/
;*    proxy-check-property-delete ...                                  */
;*---------------------------------------------------------------------*/
(define (proxy-check-property-delete target prop %this r)
   (when r
      (let ((prop (js-get-own-property target prop %this)))
	 (unless (eq? prop (js-undefined))
	    (with-access::JsPropertyDescriptor prop (configurable)
	       (unless configurable
		  (js-raise-type-error %this "Proxy \"delete\" inconsistency"
		     target)))))))

;*---------------------------------------------------------------------*/
;*    proxy-check-property-getown ...                                  */
;*---------------------------------------------------------------------*/
(define (proxy-check-property-getown target prop %this desc)
   
   (define (err)
      (js-raise-type-error %this
	 "Proxy \"getOwnPropertyDescriptor\" inconsistency"
	 target))
   
   (cond
      ((eq? desc (js-undefined))
       (let ((prop (js-get-own-property target prop %this)))
	  (cond
	     ((not (eq? prop (js-undefined)))
	      (with-access::JsPropertyDescriptor prop (configurable)
		 (if (js-totest configurable)
		     (if (js-object-mode-extensible? target)
			 desc
			 (err))
		     (err))))
	     (else
	      (err)))))
      ((js-object-mode-extensible? target)
       (let ((conf (js-get desc (& "configurable") %this)))
	  (if (js-totest conf)
	      desc
	      (let ((prop (js-get-own-property target prop %this)))
		 (cond
		    ((eq? prop (js-undefined))
		     (err))
		    ((js-totest (js-get prop (& "configurable") %this))
		     (err))
		    (else
		     desc))))))
      (else
       (err))))

;*---------------------------------------------------------------------*/
;*    proxy-check-property-defprop ...                                 */
;*---------------------------------------------------------------------*/
(define (proxy-check-property-defprop target owner p %this desc v)
   (cond
      ((and (not (js-object-mode-extensible? target))
	    (eq? (js-get-own-property target p %this) (js-undefined)))
       (js-raise-type-error %this "Proxy \"defineProperty\" inconsistency"
	  target))
      ((and (eq? (js-get desc (& "configurable") %this) #f)
	    (let ((odesc (js-get-own-property target p %this)))
	       (and (not (eq? odesc (js-undefined)))
		    (not (eq? (js-get odesc (& "configurable") %this) #f)))))
       (js-raise-type-error %this "Proxy \"defineProperty\" inconsistency"
	  target))
      (else
       v)))

;*---------------------------------------------------------------------*/
;*    proxy-check-property-getproto ...                                */
;*---------------------------------------------------------------------*/
(define (proxy-check-property-getproto target owner %this msg v)
   (cond
      ((and (not (js-object-mode-extensible? target))
	    (not (eq? (js-getprototypeof target %this msg) v)))
       (js-raise-type-error %this "Proxy \"getPrototypeOf\" inconsistency"
	  target))
      (else
       v)))

;*---------------------------------------------------------------------*/
;*    proxy-check-property-setproto ...                                */
;*---------------------------------------------------------------------*/
(define (proxy-check-property-setproto target owner v %this msg r)
   (cond
      ((and (not (js-object-mode-extensible? target))
	    (not (eq? (js-getprototypeof target %this msg) v)))
       (js-raise-type-error %this "Proxy \"setPrototypeOf\" inconsistency"
	  target))
      (else
       r)))

;*---------------------------------------------------------------------*/
;*    proxy-check-is-extensible ...                                    */
;*---------------------------------------------------------------------*/
(define (proxy-check-is-extensible target o %this r)
   (if (eq? (js-extensible? target %this) r)
       r
       (js-raise-type-error %this "Proxy \"isExtensible\" inconsistency"
	  target)))

;*---------------------------------------------------------------------*/
;*    proxy-check-preventext ...                                       */
;*---------------------------------------------------------------------*/
(define (proxy-check-preventext target o %this r)
   (if (eq? r (js-extensible? target %this))
       (js-raise-type-error %this "Proxy \"preventExtensions\" inconsistency"
	  target)
       r))

;*---------------------------------------------------------------------*/
;*    proxy-check-ownkeys ...                                          */
;*---------------------------------------------------------------------*/
(define (proxy-check-ownkeys target o %this r)
   
   (define (err)
      (js-raise-type-error %this "Proxy \"ownKeys\" inconsistency"
	 target))
   
   (define (all-symbol-or-string? r)
      (js-for-of r
	 (lambda (el %this)
	    (unless (or (js-jsstring? el) (isa? el JsSymbol))
	       (err)))
	 #t %this)
      #f)
   
   (define (find-in? name vec)
      (let loop ((i (-fx (vector-length vec) 1)))
	 (cond
	    ((=fx i -1) #f)
	    ((js-jsstring=? (vector-ref vec i) name) #t)
	    (else (loop (-fx i 1))))))
   
   (define (same-list names r)
      (when (=uint32 (fixnum->uint32 (vector-length names))
	       (js-array-length r))
	 (js-for-of r
	    (lambda (el %this)
	       (unless (find-in? el names)
		  (err)))
	    #t %this)
	 r))
   
   (cond
      ((not (js-array? r))
       (err))
      ((all-symbol-or-string? r)
       (err))
      ((and (not (js-object-mapped? target))
	    (if (js-object-hashed? target)
		(with-access::JsObject target (elements)
		   (=fx (hashtable-size elements) 0))
		(=fx (js-object-length target) 0)))
       (if (js-extensible? target %this)
	   r
	   (same-list (js-properties-name target #t %this) r)))
      (else
       (let ((names (js-properties-name target #t %this))
	     (vec (jsarray->vector r %this)))
	  (let loop ((i (-fx (vector-length names) 1)))
	     (if (=fx i -1)
		 (if (js-extensible? target %this)
		     r
		     (same-list names r))
		 (let* ((name (vector-ref names i))
			(p (js-get-own-property target name %this)))
		    (if (eq? p (js-undefined))
			(loop (-fx i 1))
			(with-access::JsPropertyDescriptor p (configurable)
			   (cond
			      (configurable
			       (loop (-fx i 1)))
			      ((find-in? name vec)
			       (loop (-fx i 1)))
			      (else
			       (err))))))))))))

;*---------------------------------------------------------------------*/
;*    js-call-proxy/cache-miss ...                                     */
;*---------------------------------------------------------------------*/
(define-macro (gen-call-proxy/cache-miss %this fun this . args)
   `(with-access::JsProxy ,fun (handler applycache)
       (proxy-check-revoked! ,fun "apply" %this)
       (let ((target (js-proxy-target ,fun)))
	  (cond
	     ((and (not (js-procedure? target)) (not (js-proxy? target)))
	      (js-raise-type-error ,%this
		 ,(format "call~a: not a function ~~s" (length args))
		 target))
	     ((js-get-jsobject-name/cache handler (& "apply") #f %this
		 applycache -1 '(imap emap cmap pmap amap vtable))
	      =>
	      (lambda (xfun)
		 (cond
		    ((js-procedure? xfun)
		     (js-call3 %this xfun handler target
			,this (jsarray ,%this ,@args)))
		    (else
		     (,(string->symbol (format "js-call~a" (length args)))
		      ,%this target ,this ,@args)))))
	     (else
	      (,(string->symbol (format "js-call~a" (length args)))
	       ,%this target ,this ,@args))))))

(define (js-call-proxy/cache-miss0 %this proxy this)
   (gen-call-proxy/cache-miss %this proxy this))

(define (js-call-proxy/cache-miss1 %this proxy this a0)
   (gen-call-proxy/cache-miss %this proxy this a0))

(define (js-call-proxy/cache-miss2 %this proxy this a0 a1)
   (gen-call-proxy/cache-miss %this proxy this a0 a1))

(define (js-call-proxy/cache-miss3 %this proxy this a0 a1 a2)
   (gen-call-proxy/cache-miss %this proxy this a0 a1 a2))

(define (js-call-proxy/cache-miss4 %this proxy this a0 a1 a2 a3)
   (gen-call-proxy/cache-miss %this proxy this a0 a1 a2 a3))

(define (js-call-proxy/cache-miss5 %this proxy this a0 a1 a2 a3 a4)
   (gen-call-proxy/cache-miss %this proxy this a0 a1 a2 a3 a4))

(define (js-call-proxy/cache-miss6 %this proxy this a0 a1 a2 a3 a4 a5)
   (gen-call-proxy/cache-miss %this proxy this a0 a1 a2 a3 a4 a5))

(define (js-call-proxy/cache-miss7 %this proxy this a0 a1 a2 a3 a4 a5 a6)
   (gen-call-proxy/cache-miss %this proxy this a0 a1 a2 a3 a4 a5 a6))

(define (js-call-proxy/cache-miss8 %this proxy this a0 a1 a2 a3 a4 a5 a6 a7)
   (gen-call-proxy/cache-miss %this proxy this a0 a1 a2 a3 a4 a5 a6 a7))

(define (js-call-proxy/cache-miss9 %this proxy this a0 a1 a2 a3 a4 a5 a6 a7 a8)
   (gen-call-proxy/cache-miss %this proxy this a0 a1 a2 a3 a4 a5 a6 a7 a8))

(define (js-call-proxy/cache-miss10 %this proxy this a0 a1 a2 a3 a4 a5 a6 a7 a8 a9)
   (gen-call-proxy/cache-miss %this proxy this a0 a1 a2 a3 a4 a5 a6 a7 a8 a9))

;*---------------------------------------------------------------------*/
;*    &end!                                                            */
;*---------------------------------------------------------------------*/
(&end!)
