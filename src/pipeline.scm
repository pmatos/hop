;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/src/pipeline.scm                    */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Thu Sep  4 09:28:11 2008                          */
;*    Last change :  Mon Oct 17 13:57:52 2022 (serrano)                */
;*    Copyright   :  2008-22 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    The pipeline into which requests transit.                        */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module hop_pipeline

   (library hop)

   (include "stage.sch")

   (cond-expand
      (enable-ssl (library ssl)))

   (import hop_scheduler
	   hop_param
	   hop_accept)

   (export (stage-request ::scheduler ::thread ::int ::socket ::obj ::symbol)))

;*---------------------------------------------------------------------*/
;*    *socket-mutex* ...                                               */
;*---------------------------------------------------------------------*/
(define *socket-mutex* (make-mutex "hop-sock"))

;*---------------------------------------------------------------------*/
;*    *keep-alive* ...                                                 */
;*---------------------------------------------------------------------*/
(define *keep-alive* 0)

;*---------------------------------------------------------------------*/
;*    keep-alive ...                                                   */
;*---------------------------------------------------------------------*/
(define (keep-alive)
   (synchronize *socket-mutex* *keep-alive*))

;*---------------------------------------------------------------------*/
;*    keep-alive-- ...                                                 */
;*---------------------------------------------------------------------*/
(define (keep-alive--)
   (synchronize *socket-mutex*
      (set! *keep-alive* (-fx *keep-alive* 1))))

;*---------------------------------------------------------------------*/
;*    keep-alive++ ...                                                 */
;*---------------------------------------------------------------------*/
(define (keep-alive++)
   (synchronize *socket-mutex*
      (set! *keep-alive* (+fx 1 *keep-alive*))))

;*---------------------------------------------------------------------*/
;*    with-time ...                                                    */
;*---------------------------------------------------------------------*/
(define-macro (with-time expr id msg)
   (let ((v (gensym)))
      `(if (hop-report-execution-time)
	   (multiple-value-bind (value real sys user)
	      (time (lambda () ,expr))
	      (hop-verb 1
			(hop-color ,id ,id (format " ~a.time " ,msg))
			" real: " real
			" sys: " sys
			" user: " user
			"\n")
	      value)
	   ,expr)))

;*---------------------------------------------------------------------*/
;*    stage-request ...                                                */
;*    -------------------------------------------------------------    */
;*    This stage is in charge of parsing the request. It produces a    */
;*    http-request.                                                    */
;*---------------------------------------------------------------------*/
(define (stage-request scd thread id sock timeout mode)
   
   ;; verbose function (only for log and debug)
   (define (http-connect-verb scd id sock req mode num)
      (with-access::http-request req (method scheme host port path header)
         (when (>=fx (hop-verbose) 1)
	    (hop-verb 4 (hop-color id id " CONNECT.header") ": "
	       path " " 
	       (with-output-to-string (lambda () (write header))) "\n")
	    (hop-verb 1 (if (isa? req http-proxy-request)
			    (hop-color req req
			       (if (eq? mode 'keep-alive)
				   (format " REQUEST.prox (+~a)" num)
				   " REQUEST.prox"))
			    (hop-color req req
			       (if (eq? mode 'keep-alive)
				   (format " REQUEST.serv (+~a)" num)
				   " REQUEST.serv")))
	       (if (>=fx (hop-verbose) 3)
		   (format " ~a~a: " thread (scheduler-stat scd))
		   ": ")
	       method " " scheme "://"
	       (if (>=fx (hop-verbose) 2)
		   (with-access::user (http-request-user req) (name)
		      (string-append name "@"))
		   "")
	       host ":"
	       port " "
	       (let ((s (string-for-read path)))
		  (if (and (=fx (hop-verbose) 1)
			   (>fx (string-length s) 80))
		      (string-append (substring s 0 80) "...")
		      s))
	       " "
	       (if (>=fx (hop-verbose) 2)
		   (with-access::http-request req (http) http)
		   "")
	       "\n"))))
   
   (let loop ((mode mode)
	      (timeout timeout)
	      (num 1))
      (with-stage-handler stage-request-error-handler (id sock mode)
	 ;; debug trace
	 (debug-thread-info-set! thread "connection established with ~a")
	 (let ((req (with-time (http-parse-request sock id timeout) id "CONNECT")))
	    ;; debug info
	    (with-access::http-request req (method path)
	       (debug-thread-info-set! thread
		  (format "request parsed for ~a, ~a ~a"
		     (if (>=fx (hop-verbose) 2)
			 (socket-hostname sock)
			 (socket-host-address sock))
		     method
		     path)))
	    (http-connect-verb scd id sock req mode num)
	    ;; decrement the keep-alive number (we have a valid connection)
	    (when (eq? mode 'keep-alive) (keep-alive--))
	    ;; start computing the answer
	    (let ((keep-alive-timeout (stage scd thread stage-response id req)))
	       (when (fixnum? keep-alive-timeout)
		  (loop 'keep-alive keep-alive-timeout (+fx num 1))))))))

;*---------------------------------------------------------------------*/
;*    stage-request-error-handler ...                                  */
;*---------------------------------------------------------------------*/
(define (stage-request-error-handler e id sock mode)

   ;; is the error raised of a timeout in a keep-alive connection?
   (define (keep-alive-ellapsed-error? e)
      (and (eq? mode 'keep-alive)
	   (or (isa? e &io-timeout-error)
	       (isa? e &io-connection-error)
	       (and (isa? e &io-parse-error)
		    (with-access::&io-parse-error e (obj)
		       (eof-object? obj))))))

   (if (keep-alive-ellapsed-error? e)
       ;; this is not a true error, just log
       (hop-verb 3 (hop-color id id " SHUTDOWN")
	  (cond
	     ((isa? e &io-timeout-error)
	      " (keep-alive, timeout ellapsed)")
	     ((and (isa? e &io-parse-error)
		   (with-access::&io-parse-error e (obj)
		      (eof-object? obj)))
	      " (keep-alive, connection reset by peer)")
	     (else
	      " (keep-alive, parse error)"))
	  "\n")
       ;; this one is a true error
       (begin
	  (when (isa? e &exception)
	     (hop-verb 1 (hop-color id id " ABORT: ")
		" " (trace-color 1 (typeof e))
		(if (>=fx (hop-verbose) 4)
		    (format "~a:~a"
		       (socket-hostname sock)
		       (socket-port-number sock))
		    "")
		"\n")
	     (cond
		((isa? e &hop-security-error)
		 (exception-notify e))
		((>fx (bigloo-debug) 0)
		 (hop-verb 1
		    (with-error-to-string
		       (lambda () (exception-notify e)))))))
	  (when (and (isa? e &io-unknown-host-error) (not (socket-down? sock)))
	     (with-handler
		(lambda (e)
		   ;; this error handler is invoked when the attempt to
		   ;; notify the previous error to the client fails
		   (when (isa? e &error) (exception-notify e))
		   #unspecified)
		;; we will try to answer the error to the client
		(unless (isa? e &io-sigpipe-error)
		   (let* ((req (instantiate::http-request
				  (socket sock)))
			  (resp ((or (hop-http-request-error) http-error)
				 e req)))
		      (http-response resp req sock)))))))

   ;; decrement the keep-alive number
   (when (eq? mode 'keep-alive) (keep-alive--))
   ;; abort this request
   (if (isa? e &io-connection-error)
       (socket-close sock)
       (socket-shutdown sock))
   ;; ignore the error
   #unspecified)

;*---------------------------------------------------------------------*/
;*    http-response-static? ...                                        */
;*---------------------------------------------------------------------*/
(define (http-response-static? resp)
   (or (isa? resp http-response-file)
       (isa? resp http-response-string)
       (isa? resp http-response-abort)))

;*---------------------------------------------------------------------*/
;*    stage-response ...                                               */
;*    -------------------------------------------------------------    */
;*    This stage is in charge of building a response to the received   */
;*    request.                                                         */
;*---------------------------------------------------------------------*/
(define (stage-response scd thread id req)
   (hop-verb 3 (hop-color id id " RESPONSE") (format " ~a" thread) "\n")
   (with-stage-handler response-error-handler (scd req)
      (let ((resp (with-time (request->response req thread) id "RESPONSE")))
	 (with-access::http-request req (method scheme host port path)
	    (debug-thread-info-set! thread
	       (format "~a ~a://~a:~a~a... -> ~a"
		  method scheme host
		  port path (typeof resp))))
	 (let ((proc (cond
			((http-response-static? resp) stage-static-answer)
			((isa? resp http-response-async) stage-async-answer)
			(else stage-dynamic-answer))))
	    (stage scd thread proc id req resp)))))

;*---------------------------------------------------------------------*/
;*    write-circle ...                                                 */
;*---------------------------------------------------------------------*/
(define (my-write-circle o #!optional (port::output-port (current-output-port)))
   (circle-write/display o port #f))

;*---------------------------------------------------------------------*/
;*    for ...                                                          */
;*---------------------------------------------------------------------*/
(define-macro (for range . body)
   (let ((for (gensym 'for))
	 (stop (gensym 'stop)))
      `(let ((,stop ,(caddr range)))
	  (let ,for ((,(car range) ,(cadr range)))
	       (when (<fx ,(car range) ,stop)
		  ,@body
		  (,for (+fx ,(car range) 1)))))))

;*---------------------------------------------------------------------*/
;*    write/display ...                                                */
;*    -------------------------------------------------------------    */
;*    As we can't be sure that this module is initialized before       */
;*    used (for example when an error occurs during module             */
;*    intialization process), we can't use symbol to set               */
;*    flag. So is flag is equal to #t it means that                    */
;*    `write-display' is used to display and if flags is equal         */
;*    to #f it writes.                                                 */
;*---------------------------------------------------------------------*/
(define (circle-write/display obj port flag)
   (let* ((cache         '())
          (cache-count   0)
          (next-cardinal (let ((serial -1))
			    (lambda ()
			       (set! serial (+fx 1 serial))
			       serial))))

      (define (cache-lookup obj)
	 (cond
	    ((hashtable? cache)
	     (hashtable-get cache obj))
	    (else
	     (assq obj cache))))

      (define v
	 (list->vector
	    (map (lambda (i) (make-string i #\space)) (iota 100))))
      
      (define (margin l)
	 (if (>=fx l (vector-length v))
	     (make-string l #\space)
	     (vector-ref v l)))
      
      ;; first stage: register object components
      (define (register obj l)
	 (tprint (margin l) "register obj="
	    (if (or (number? obj)
		    (symbol? obj)
		    (string? obj)
		    (ucs2-string? obj)
		    (date? obj)
		    (cnst? obj)
		    (null? obj)
		    (class? obj))
		obj
		(typeof obj)))
	 ;; do not register objects unique by their nature
	 (unless (or (number? obj)
		     (symbol? obj)
		     (string? obj)
		     (ucs2-string? obj)
		     (date? obj)
		     (cnst? obj)
		     (null? obj)
		     (class? obj))
	    (let ((match (cache-lookup obj)))
	       (if match
		   (set-cdr! match #t)
		   (let ((entry (cons obj #f)))
		      (cond ((hashtable? cache)
			     (hashtable-put! cache obj entry))
			    ((>fx cache-count 64)
			     (let ((h (create-hashtable
					 :eqtest eq?
					 :bucket-expansion 2.0)))
				(for-each (lambda (cell)
					     (hashtable-put! h (car cell) cell))
				   cache)
				(set! cache h)
				(set! cache-count -1)
				(hashtable-put! cache obj entry)))
			    (else
			     (set! cache (cons entry cache))
			     (set! cache-count (+fx cache-count 1))))
		      (cond
			 ((pair? obj)
			  (register (car obj) (+fx l 1))
			  (register (cdr obj) (+fx l 1)))
			 ((vector? obj)
			  (for (i 0 (vector-length obj))
			     (register (vector-ref obj i) (+fx l 1))))
			 ((struct? obj)
			  (for (i 0 (struct-length obj))
			     (register (struct-ref obj i) (+fx l 1))))
			 ((object? obj)
			  (tprint (margin l) "REG OBJ " (typeof obj))
			  (let* ((klass (object-class obj))
				 (fields (class-all-fields klass)))
			     (for (i 0 (vector-length fields))
				(let* ((f (vector-ref fields i))
				       (gv (class-field-accessor f)))
				   (tprint (margin l) "  FIELD= "
				      (class-field-name f))
				   (register (gv obj) (+fx l 1))))))
			 ((cell? obj)
			  (register (cell-ref obj) (+fx l 1)))))))))

      (define (putchar ch)
	 ($display-char ch port))

      (define (space)
	 (putchar #\space))

      (define (sharp)
	 (putchar #\#))
      
      ;; do register the value
      (tprint ">>> REG " (typeof obj))
      (register obj 0)
      (tprint "<<< REG " (typeof obj))
      
      ;; do output 
      (let output-component ((obj obj))
	 (tprint "OUT obj="
	    (if (or (number? obj)
		    (symbol? obj)
		    (string? obj)
		    (ucs2-string? obj)
		    (date? obj)
		    (cnst? obj)
		    (null? obj)
		    (class? obj))
		obj
		(typeof obj)))
	 (let loop-matched ((obj obj)
			    (match (cache-lookup obj)))
	    (if match
                (let ((value (cdr match)))
                   (cond
		      ((fixnum? value)
		       ;; emit reference like #0#
		       (sharp)
		       (output-component value)
		       (sharp))
		      (value
		       ;;; emit target as #0=<the object>
		       (let ((serial (next-cardinal)))
			  (set-cdr! match serial)
			  (sharp)
			  (output-component serial)
			  (putchar #\=)
			  ;; emit object itself
			  (loop-matched obj #f)))
		      (else
		       ;; object referenced just once, just emit it
		       (loop-matched obj #f))))
		(cond
		   ;; fixnum display
		   ((fixnum? obj)
		    ($display-fixnum obj port))
		   ;; char display
		   ((char? obj)
		    (if flag
			($display-char obj port)
			($write-char obj port)))
		   ;; symbol display
		   ((symbol? obj)
		    (if flag
			(display-symbol obj port)
			(write-symbol obj port)))
		   ;; string display
		   ((string? obj)
		    (if flag
			(display-string obj port)
			(write-string (string-for-read obj) port)))
		   ;; pair display
		   ((pair? obj)
		    (putchar #\()
		    (let loop ((l obj))
		       (output-component (car l))
		       (let ((rest (cdr l)))
			  (if (null? rest)
			      (putchar #\))
			      (let ((match (cache-lookup rest)))
				 (if (or (not (pair? rest))
					 (and match (cdr match)))
				     (begin
					(display-string " . " port)
					(loop-matched rest match)
					(putchar #\)))
				     (begin
					(space)
					(loop rest))))))))
		   ;; classes
		   ((class? obj)
		    (display obj port))
		   ;; vector display
		   ((vector? obj)
		    (sharp)
		    (let ((tag (vector-tag obj)))
		       (if (>fx tag 0)
			   (if (<fx tag 100)
			       (begin
				  (if (>fx tag 10) (putchar #\0))
				  (putchar #\0))
			       (write tag port))))
		    (let ((len (vector-length obj)))
		       (putchar #\()
		       (let loop ((i 0))
			  (if (not (=fx i len))
			      (begin
				 (output-component (vector-ref obj i))
				 (let ((next (+fx 1 i)))
				    (if (not (=fx next len))
					(space))
				    (loop (+fx 1 i))))))
		       (putchar #\))))
		   ;; struct display
		   ((struct? obj)
		    (display-string #"#{" port)
		    (write (struct-key obj) port)
		    (space)
		    (let ((len (struct-length obj)))
		       (let loop ((i 0))
			  (if (not (=fx i len))
			      (begin
				 (output-component (struct-ref obj i))
				 (let ((next (+fx 1 i)))
				    (if (not (=fx next len))
					(space))
				    (loop (+fx 1 i)))))))
		    (putchar #\}))
		   ;; cell display
		   ((cell? obj)
		    (display-string #"#<cell:" port)
		    (output-component (cell-ref obj))
		    (display-string #">" port))
		   ;; object display
		   ((object? obj)
		    (object-print obj port (lambda (x . p)
					      (output-component x))))
		   ;; ucs2 string display
		   ((ucs2-string? obj)
		    (if flag
			(display-ucs2string obj port)
			(write-ucs2string obj port)))
		   ;; ucs2 display
		   ((ucs2? obj)
		    (if flag
			($display-ucs2 obj port)
			($write-ucs2 obj port)))
		   ;; flonum display
		   ((flonum? obj)
		    (display-flonum obj port))
		   ;; date
		   ((date? obj)
		    (if flag
			(display obj port)
			(write obj port)))
		   ;; mutex
		   ((mutex? obj)
		    (display-string "#<mutex:" port)
		    (display (mutex-name obj) port)
		    (display-string ">" port))
		   ;; condition variable
		   ((condition-variable? obj)
		    (display-string "#<condition-variable:" port)
		    (display (condition-variable-name obj) port)
		    (display-string ">" port))
		   ;; default displayer
		   (else
		    (write obj port)))))))
   #unspecified)

;*---------------------------------------------------------------------*/
;*    response-error-handler ...                                       */
;*---------------------------------------------------------------------*/
(define (response-error-handler e scd req)
   ;; notify the error
   (hop-verb 1 (hop-color req req " ERROR"))
   (hop-verb 2 (scheduler-stat scd))
   (hop-verb 1 ": "
      (trace-color 1 (call-with-output-string (lambda (p) (display e p))))
      "\n")
   ;; when the error is a response, we transmit it to the next stage
   ;; when the error is an exception, we create a response that it
   ;; then transmitted to the next stage
   (with-handler
      (lambda (e)
	 (exception-notify e)
	 ;; there is nothing we can do but aborting the request
	 (socket-shutdown (with-access::http-request req (socket) socket))
	 #unspecified)
      ;; try to send the error message
      (if (isa? e %http-response)
	  (with-access::http-request req (socket)
	     (http-response e req socket))
	  (begin
	     (exception-notify e)
	     (when (>=fx (bigloo-debug) 1)
		(with-access::http-request req (header)
		   (let ((stk (http-header-field header hop-debug-stack:)))
		      (when (string? stk)
			 (with-handler
			    (lambda (e) #f)
			    (let ((stk (hop-debug-exception-stack
					  (string->obj (url-decode stk)))))
			       (when (pair? stk)
				  (display-trace-stack stk
				     (current-error-port)
				     (if (isa? e &exception)
					 (with-access::&exception e (stack)
					    (+fx 1 (length stack)))
					 1)))))))))
	     ;; generate a legal response for the next stage (although
	     ;; this response denotes the error).
	     (let ((resp ((or (hop-http-response-error) http-error) e req)))
		(with-access::http-request req (socket)
		   (http-response resp req socket)
		   ;; abort this request
		   (socket-shutdown socket)
		   'close))))))

;*---------------------------------------------------------------------*/
;*    stage-static-answer ...                                          */
;*---------------------------------------------------------------------*/
(define (stage-static-answer scd thread id req resp)
   (stage-exec scd thread id req resp))

;*---------------------------------------------------------------------*/
;*    stage-dynamic-answer ...                                         */
;*---------------------------------------------------------------------*/
(define (stage-dynamic-answer scd thread id req resp)
   (stage-exec scd thread id req resp))

;*---------------------------------------------------------------------*/
;*    stage-async-answer ...                                           */
;*---------------------------------------------------------------------*/
(define (stage-async-answer scd thread id req respa)
   (with-stage-handler exec-error-handler (scd req)
      (with-access::http-request req (socket method scheme port host path connection)
	 (socket-timeout-set! socket 0 0)
	 (socket-buffers-detach! socket)
	 (with-access::http-response-async respa (async)
	    (let ((mutex (make-mutex))
		  (condv (make-condition-variable)))
	       (let ((resps #f))
		  (synchronize mutex
		     (async
			(lambda (r)
			   (synchronize mutex
			      (set! resps r)
			      (condition-variable-broadcast! condv))))
		     (condition-variable-wait! condv mutex)
		     (socket-timeout-set! socket
			(hop-keep-alive-timeout) (hop-keep-alive-timeout))
		     (let ((tmt (with-handler
				   (lambda (e)
				      (exec-error-handler e scd req))
				   (stage-exec scd thread id req resps))))
			(if (integer? tmt)
			    (stage-request scd thread id socket tmt 'keep-alive)
			    (begin
			       (socket-shutdown socket)
			       #f)))))))
	 #f)))

;*---------------------------------------------------------------------*/
;*    stage-exec-verb ...                                              */
;*---------------------------------------------------------------------*/
(define (stage-exec-verb scd thread req resp connection mode)
   (hop-verb 3 (hop-color req req mode)
      (format " ~a" thread)
      " load=" (scheduler-load scd)
      (scheduler-stat scd)
      ": " (typeof resp) " "
      " [" (current-date) "] "
      (if (and (eq? connection 'keep-alive) (>=fx (hop-verbose) 4))
	  (format " keep-alive [open=~a/~a]"
	     (keep-alive)
	     (hop-keep-alive-threshold))
	  connection)
      "\n"))

;*---------------------------------------------------------------------*/
;*    stage-exec ...                                                   */
;*---------------------------------------------------------------------*/
(define (stage-exec scd thread id req resp)
   ;; log
   (if (isa? resp http-response-abort)
       (hop-verb 1 (hop-color req req " ABORT")
	  " user: "
	  (with-access::user (http-request-user req) (name) name) "\n")
       (hop-verb 3 (hop-color req req " EXEC")
	  " load: " (scheduler-load scd)
	  (scheduler-stat scd)
	  (format " ~a" thread)
	  ": " (typeof resp)
	  " " (with-access::user (http-request-user req) (name) name) "\n"))
   (with-stage-handler exec-error-handler (scd req)
      (with-access::http-request req (socket method scheme port host path)
	 (let ((conn (with-time (http-response resp req socket) id "EXEC")))
	    ;; debug
	    (debug-thread-info-set! thread
	       (format "~a ~a://~a:~a~a... -> ~a ~a"
		  method scheme host port path
		  (typeof resp) conn))
	    (case conn
	       ((keep-alive)
		(let ((load (scheduler-load scd)))
		   (cond
		      ((or (>=fx (keep-alive) (hop-keep-alive-threshold))
			   (=fx load 100))
		       (when (>=fx (hop-verbose) 3)
			  (stage-exec-verb scd thread req resp conn
			     " END"))
		       (socket-shutdown socket)
		       #f)
		      ((>=fx load 80)
		       (when (>=fx (hop-verbose) 3)
			  (stage-exec-verb scd thread req resp conn
			     " KEEP-ALIVE"))
		       (keep-alive++)
		       1)
		      (else
		       (when (>=fx (hop-verbose) 3)
			  (stage-exec-verb scd thread req resp conn
			     " KEEP-ALIVE"))
		       (keep-alive++)
		       (hop-keep-alive-timeout)))))
	       ((persistent)
		(when (>=fx (hop-verbose) 3)
		   (stage-exec-verb scd thread req resp conn
		      " PERSISTENT"))
		#f)
	       (else
		(when (>=fx (hop-verbose) 3)
		   (stage-exec-verb scd thread req resp conn " END"))
		(socket-shutdown socket)
		#f))))))

;*---------------------------------------------------------------------*/
;*    exec-error-handler ...                                           */
;*---------------------------------------------------------------------*/
(define (exec-error-handler e scd req)
   (with-access::http-request req (socket)
      ;; first, close the socket, anycase
      (socket-shutdown socket)
      (unless (isa? e &io-sigpipe-error)
	 ;; signal the error, when this is an error
	 (hop-verb 2 (hop-color req req " INTERRUPTED"))
	 (hop-verb 2 ": " req "\n")
	 ;; abort the request
	 (with-handler
	    (lambda (e2) #unspecified)
	    (begin
	       (exception-notify e)
	       (with-access::http-request req (header)
		  (let ((stk (http-header-field header hop-debug-stack:)))
		     (when (string? stk)
			(with-handler
			   (lambda (e) #f)
			   (let ((stk (hop-debug-exception-stack
					 (string->obj (url-decode stk)))))
			      (when (pair? stk)
				 (display-trace-stack stk
				    (current-error-port)
				    (if (isa? e &exception)
					(with-access::&exception e (stack)
					   (+fx 1 (length stack)))
					1))))))))
	       #f))
	 #unspecified)))

