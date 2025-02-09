;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/src/parseargs.scm                   */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Fri Nov 12 13:32:52 2004                          */
;*    Last change :  Fri Jun  3 11:42:42 2022 (serrano)                */
;*    Copyright   :  2004-22 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Hop command line parsing                                         */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module hop_parseargs

   (include "libraries.sch")

   (import  hop_param
	    hop_init)

   (export  (parse-args::pair-nil ::pair)
	    (hello-world)))

;*---------------------------------------------------------------------*/
;*    ecmascript-support ...                                           */
;*---------------------------------------------------------------------*/
(define ecmascript-es6
   '(es6-let: es6-const: es6-arrow-function: es6-default-value:
     es6-rest-argument:))

(define ecmascript-es2017
   (append ecmascript-es6 '(es2017-async:)))
      
;*---------------------------------------------------------------------*/
;*    parse-args ...                                                   */
;*---------------------------------------------------------------------*/
(define (parse-args args)

   ;; defaults
   (let ((loadp #t)
	 (mimep #t)
	 (autoloadp #t)
	 (p #f)
	 (ps #f)
	 (ep #unspecified)
	 (dp #unspecified)
	 (rc-file #f)
	 (mime-file #unspecified)
	 (libraries '())
	 (exprs '())
	 (exprsjs '())
	 (log-file #f)
	 (be #f)
	 (files '())
	 (killp #f)
	 (webdav #unspecified)
	 (zeroconf #unspecified)
	 (clear-cache #f)
	 (clear-so #f)
	 (setuser #f)
	 (clientc-source-map #f)
	 (clientc-arity-check #f)
	 (clientc-type-check #f)
	 (clientc-debug #f)
	 (clientc-compress #f)
	 (clientc-inlining #t)
	 (clientc-use-strict #t)
	 (sofile-dir #f)
	 (cache-dir #f)
	 (commonjs-export #t))
      
      (bigloo-debug-set! 0)

      (bind-exit (stop)
	 (args-parse (cdr args)
	    ;; Misc
	    (section "Misc")
	    ((("-h" "--help") (help "This message"))
	     (usage args-parse-usage)
	     (exit 0))
	    (("--options" (help "Display the Hop options and exit"))
	     (usage args-parse-usage)
	     (exit 0))
	    (("--version" (help "Print the version and exit"))
	     (print (hop-name) "-" (hop-version))
	     (exit 0))
	    (("--buildtag" (help "Print the buildtag and exit"))
	     (print (hop-build-tag))
	     (exit 0))
	    (("--default-so-dir" (help "Display default so dir"))
	     (print (dirname (hop-sofile-path "dummy.hop"))))
	    
	    ;; RC
	    (section "RC & Autoload")
	    (("-q" (help "Do not load an init file"))
	     (set! loadp #f))
	    (("-qmime" (help "Do not load any mime file"))
	     (set! mimep #f))
	    (("-qpreferences" (help "Do not load any user preferences file"))
	     (hop-load-preferences-set! #f))
	    (("--rc-file" ?file (help "Load alternate rc file"))
	     (set! rc-file file))
	    (("--rc-dir" ?dir (help "Set rc directory"))
	     (hop-rc-directory-set! dir)
	     (unless cache-dir
		(hop-cache-directory-set! (make-file-name dir "cache")))
	     (unless sofile-dir
		(hop-sofile-directory-set! (make-file-path dir "so"))))
	    (("--cache-dir" ?dir (help "Set cache directory"))
	     (set! cache-dir #t)
	     (hop-cache-directory-set! dir))
	    (("--icons-dir" ?dir (help "Set Hop icons directory"))
	     (hop-icons-directory-set! dir))
	    (("--no-cache" (help "Disable server caching"))
	     (hop-cache-enable-set! #f))
	    (("--clear-cache" (help "Clear all caches"))
	     (set! clear-cache #t))
	    (("--no-clear-cache" (help "Don't clear any cache"))
	     (hop-hss-clear-cache-set! #f)
	     (hop-clientc-clear-cache-set! #f))
	    (("--so-dir" ?dir (help (format "Set libs directory (~a)" (hop-sofile-directory))))
	     (set! sofile-dir #t)
	     (hop-sofile-directory-set! dir))
	    (("--clear-so" (help "Clear sofiles directory"))
	     (set! clear-so #t))
	    (("--no-clear-so" (help "Don't clear libs"))
	     (set! clear-so #f))
	    (("--no-so" (help "Disable loading pre-compiled file"))
	     (hop-sofile-enable-set! #f))
	    (("--so-policy" ?policy (help "Sofile compile policy [none, aot, nte, nte1, nte+]"))
	     (hop-sofile-compile-policy-set! (string->symbol policy)))
	    (("--sofile-policy" ?policy (help "Deprecated, use \"--so-policy\" instead"))
	     (hop-sofile-compile-policy-set! (string->symbol policy)))
	    (("--so-target" ?loc
		(help
		   (format "Location for generated so file [sodir, src] [~s]"
		      (hop-sofile-compile-target))))
	     (hop-sofile-compile-target-set! (string->symbol loc)))
	    
	    (("--autoload" (help "Enable autoload (default)"))
	     (set! autoloadp #t))
	    (("--no-autoload" (help "Disable autoload"))
	     (set! autoloadp #f))
	    (("--add-autoload-dir" ?dir (help "Add autoload directory"))
	     (hop-autoload-directory-add! dir))
	    (("--autoload-dir" ?dir (help "Set autoload directory"))
	     (hop-autoload-directories-set! (list dir)))
	    (("--mime-type" ?file (help "Load aternate user mime-type file"))
	     (set! mime-file file))
	    (("--preload-service" ?svc (help "Preload service"))
	     (hop-preload-services-set! (cons svc (hop-preload-services))))
	    
	    ;; Verbosity and logs
	    (section "Verbosity & Logging")
	    (("-v?level" (help "Increase/set verbosity level (-v0 crystal silence)"))
	     (if (string=? level "")
		 (hop-verbose-set! (+fx 1 (hop-verbose)))
		 (hop-verbose-set! (string->integer level))))
	    (("-g?level" (help "Set debug level (do not use in production)"))
	     (cond
		((string=? level "")
		 (hop-sofile-enable-set! #f)
		 (set! clientc-source-map #t)
		 (hop-clientc-debug-unbound-set! 1)
		 (set! clientc-debug #t)
		 (set! clientc-arity-check #t)
		 (set! clientc-type-check #t)
		 (bigloo-debug-set! (+fx 1 (bigloo-debug))))
		((string=? level "clientc-debug")
		 (set! clientc-debug #t)
		 (set! clientc-inlining #f))
		((string=? level "no-clientc-debug")
		 (set! clientc-debug #t))
		((string=? level "clientc-arity-check")
		 (set! clientc-arity-check #t))
		((string=? level "no-clientc-arity-check")
		 (set! clientc-arity-check #f))
		((string=? level "clientc-type-check")
		 (set! clientc-type-check #t))
		((string=? level "no-clientc-type-check")
		 (set! clientc-type-check #f))
		((string=? level "clientc-use-strict")
		 (set! clientc-use-strict #t))
		((string=? level "no-clientc-use-strict")
		 (set! clientc-use-strict #f))
		((string=? level "clientc-inlining")
		 (set! clientc-inlining #t))
		((string=? level "no-clientc-inlining")
		 (set! clientc-inlining #f))
		((string=? level "clientc-debug-unbound")
		 (hop-clientc-debug-unbound-set! 1))
		((string=? level "no-clientc-debug-unbound")
		 (hop-clientc-debug-unbound-set! 0))
		((string=? level "clientc-source-map")
		 (set! clientc-source-map #t))
		((string=? level "no-clientc-source-map")
		 (set! clientc-source-map #f))
		((string=? level "module")
		 (bigloo-debug-module-set! 2))
		((string=? level "sofile")
		 (hop-sofile-enable-set! #f))
		((string=? level "0")
		 #f)
		(else
		 (hop-sofile-enable-set! #f)
		 (let ((l (string->integer level)))
		    (set! clientc-source-map #t)
		    (set! clientc-debug #t)
		    (set! clientc-inlining (<=fx l 2))
		    (set! clientc-arity-check #t)
		    (set! clientc-type-check #t)
		    (bigloo-debug-set! l)
		    (hop-clientc-debug-unbound-set! l)))))
	    (("--client-output" ?file (help "Client output port [stderr]"))
	     (if (string=? file "-")
		 (hop-client-output-port-set! (current-output-port))
		 (let ((p (open-output-file file)))
		    (if (output-port? p)
			(hop-client-output-port-set! p)
			(error "hop" "Cannot open client port" file)))))
	    (("--devel" (help "Enable devel mode"))
	     (set! clear-cache #t)
	     (hop-cache-enable-set! #f)
	     (hop-allow-redefine-service-set! #t)
	     (hop-force-reload-service-set! #t))
	    (("--time" (help "Report execution time"))
	     (hop-report-execution-time-set! #t))
	    (("-w?level" (help "Increase/set warning level (-w0 no warning)"))
	     (if (string=? level "")
		 (bigloo-warning-set! (+fx 1 (bigloo-warning)))
		 (bigloo-warning-set! (string->integer level))))
	    (("-s?level" (help "Increase/set security level (-s0 no security enforcement)"))
	     (if (string=? level "")
		 (hop-security-set! (+fx 1 (hop-security)))
		 (hop-security-set! (string->integer level)))
	     (cond
		((=fx (hop-security) 0)
		 (hop-allow-redefine-service-set! #t))
		((>=fx (hop-security) 2)
		 (hop-security-manager-set! 'tree))))
	    (("--no-color" (help "Disable colored traces"))
	     (bigloo-trace-color-set! #f))
	    (("--log-file" ?file (help "Use <FILE> as log file"))
	     (set! log-file file))
	    (("--capture-file" ?file (help "Use <FILE> as remote capture file"))
	     (hop-capture-port-set! (open-output-file file)))
	    (("--allow-service-override" (help "Allow service overriding (see -s)"))
	     (hop-security-set! 0))
	    
	    ;; Run
	    (section "Run")
	    ((("-p" "--http-port") ?port (help (format "Port number [~s]" p)))
	     (set! p (string->integer port)))
	    (("--https-port" ?port (help (format "Port number [~s]" ps)))
	     (set! ps (string->integer port)))
	    (("--listen-addr" ?addr (help "Server listen hostname or IP"))
	     (hop-server-listen-addr-set! addr))
	    (("--https" (help (format "Enable HTTPS")))
	     (hop-enable-https-set! #t))
	    (("--no-https" (help (format "Disable HTTPS")))
	     (hop-enable-https-set! #f))
	    (("--https-pkey" ?pem (help "HTTPS private key file"))
	     (hop-https-pkey-set! pem))
	    (("--https-cert" ?pem (help "HTTPS certificate file"))
	     (hop-https-cert-set! pem))
	    ((("-i" "--session-id") ?session (help "Set session identifier"))
	     (hop-session-set! (string->integer session)))
	    (("--no-job-restore" (help "Don't restore jobs"))
	     (hop-job-restore-set! #f))
	    ((("-e" "--eval") ?string (help "Evaluate Hop STRING"))
	     (set! exprs (cons string exprs)))
	    ((("-j" "--evaljs") ?string (help "Evaluate JavaScript STRING"))
	     (set! exprsjs (cons string exprsjs)))
	    (("--repl" (help "Start a repl"))
	     (hop-enable-repl-set! 'scm))
	    (("--repljs" (help "Start a JS repl"))
	     (hop-enable-repl-set! 'js))
	    (("--jobs" (help "Enable jobs management"))
	     (hop-enable-jobs-set! #t))
	    (("--no-jobs" (help "Disable jobs management"))
	     (hop-enable-jobs-set! #f))
	    ((("-z" "--zeroconf") (help "Enable zeroconf support"))
	     (set! zeroconf #t))
	    (("--no-zeroconf" (help "Disable zeroconf support (default)"))
	     (set! zeroconf #f))
	    ((("-d" "--webdav") (help "Enable webdav support"))
	     (set! webdav #t))
	    (("--no-webdav" (help "Disable webdav support"))
	     (set! webdav #f))
	    ((("-x" "--xml-backend")
	      ?ident
	      (help (format "Set XML backend [~s]"
		       (with-access::xml-backend (hop-xml-backend)
			     (id) id))))
	     (set! be ident))
	    (("--accept-kill" (help "Enable remote kill commands (see -k)"))
	     (hop-accept-kill-set! #t))
	    (("--no-accept-kill" (help "Forbidden remote kill commands"))
	     (hop-accept-kill-set! #f))
	    ((("-k" "--kill") (help "Kill the running local HOP and exit"))
	     (set! killp #t))
	    (("--user" ?user (help "Set Hop process owner"))
	     (set! setuser user))
	    (("--no-user" (help "Don't attempt to set the Hop process owner"))
	     (hop-user-set! #f))
	    (("--server" (help "Start the Web server (default)"))
	     (hop-run-server-set! #t))
	    (("--no-server" (help "Exit after loading command line files"))
	     (hop-port-set! -1)
	     (hop-ssl-port-set! -1)
	     (hop-run-server-set! #f)
	     (set! p #f))
	    (("--exepath" ?name (help "Set JavaScript executable path"))
	     (if (string=? name "*")
		 (hop-exepath-set! (executable-name))
		 (hop-exepath-set! name)))
	    (("--acknowledge" ?host (help "Acknowledge readiness"))
	     (hop-acknowledge-host-set! host))
	    
	    ;; Paths
	    (section "Paths")
	    ((("-I" "--path") ?path (help "Add <PATH> to hop load path"))
	     (hop-path-set! (cons path (hop-path)))
	     (nodejs-resolve-extend-path! (list path)))
	    ((("-L" "--library-path") ?path (help "Add <PATH> to hop library path"))
	     (bigloo-library-path-set! (cons path (bigloo-library-path))))
	    ((("-l" "--library") ?library (help "Preload additional <LIBRARY>"))
	     (set! libraries (cons library libraries )))

	    ;; JavaScript
	    (section "JavaScript")
	    (("--js" (help "Enable JavaScript (default)"))
	     (hop-javascript-set! #t))
	    (("--no-js" (help "Disable JavaScript"))
	     (hop-javascript-set! #f))
	    (("--js-return-as-exit" (help "Consider toplevel returns as exits"))
	     (nodejs-compiler-options-add! :return-as-exit #t)) 
	    (("--no-js-return-as-exit" (help "Do not consider toplevel returns as exits"))
	     (nodejs-compiler-options-add! :return-as-exit #f))
	    (("--js-es6" (help "Enable all EcmaScript 6 supports"))
	     (for-each (lambda (ext)
			  (nodejs-compiler-options-add! ext #t))
		ecmascript-es6))
	    (("--js-es2017" (help "Enable all EcmaScript 2017 supports"))
	     (for-each (lambda (ext)
			  (nodejs-compiler-options-add! ext #t))
		ecmascript-es6)
	     (for-each (lambda (ext)
			  (nodejs-compiler-options-add! ext #t))
		ecmascript-es2017))
	    (("--js-dsssl" (help "Enable DSSSL like JS services (deprecated)"))
	     (nodejs-compiler-options-add! :dsssl #t))
	    (("--js-option" ?opt ?val (help "Add JavaScript compilation option"))
	     (nodejs-compiler-options-add! (string->keyword opt)
		(cond
		   ((or (string=? val "true") (string=? val "#t")) #t)
		   ((or (string=? val "false") (string=? val "#f")) #f)
		   ((string->number val) => (lambda (val) val))
		   (else val))))
	    (("--js-modules-dir" ?dir
		(help (format "Set default node_modules dir [~a]"
			 (nodejs-modules-directory))))
	     (nodejs-modules-directory-set! dir))
	    (("--js-commonjs-export" (help "Automatic commonjs modules export"))
	     (set! commonjs-export #t))
	    (("--no-js-commonjs-export" (help "Automatic commonjs modules export"))
	     (set! commonjs-export #f))
	    (("--profile" (help "Profiling mode (see HOPTRACE)"))
	     (hop-profile-set! #t))
	    
	    ;; Internals
	    (section "Internals")
	    (("--configure" ?config (help "Report HOP configuration"))
	     (hop-configure config)
	     (exit 0))
	    (("--srfi" ?feature (help "Declare SRFI feature"))
	     (register-srfi! (string->symbol feature)))
	    (("--no-thread" (help "Disable multithreading (equiv. to \"--scheduler nothread\")"))
	     (hop-max-threads-set! 1)
	     (hop-enable-keep-alive-set! #f)
	     (hop-scheduling-set! 'nothread))
	    (("--max-threads" ?m (help "Maximum number of handling HTTP requests"))
	     (hop-max-threads-set! (string->integer m)))
	    (("--scheduler" ?ident (help (format "Set scheduling policy [~s] (see --help-scheduler)" (hop-scheduling))))
	     (hop-scheduling-set! (string->symbol ident)))
	    (("--help-scheduler" (help "Print available schedulers list"))
	     (with-output-to-port (current-error-port)
		(lambda ()
		   (print  "Schedulers:")
		   (print "  - queue (split threads but avoid useless switches)")
		   (print "  - nothread (single threaded execution)")
		   (print "  - one-to-one (one thread per request)")
		   (print "  - pool (one thread per request from a pool)")
		   (print "  - accept-many (as pool but an accept-many call)")))
	     (exit 0))
	    (("--javascript-version" ?version
		(help (format "JavaScript version to generate (default ~s)"
			 (hop-javascript-version))))
	     (hop-javascript-version-set! version))
	    (("--hopc" ?path (help (format "Hopc compiler [~s]" (hop-hopc))))
	     (hop-hopc-set! path))
	    (("--hopc-flags" ?flags (help (format "Hopc flags" (hop-hopc-flags))))
	     (hop-hopc-flags-set! flags))
	    (("-psn_?dummy")
	     ;; Macosx sends process serial numbers this way.
	     ;; just ignore it.
	     'do-nothing)
	    (("--" ?file (help "Ignore next arguments"))
	     (set! files (cons file files))
	     (stop #t))
	    (("-?dummy")
	     (args-parse-usage #f)
	     (exit 1))
	    (else
	     (set! files (cons else files)))))

      ;; http and https port
      (cond
	 ((and p ps)
	  (hop-port-set! p)
	  (hop-ssl-port-set! ps))
	 (p
	  (if (hop-enable-https)
	      (begin
		 (hop-port-set! -1)
		 (hop-ssl-port-set! p))
	      (hop-port-set! p)))
	 (ps
	  (hop-port-set! -1)
	  (hop-ssl-port-set! ps)))
      
      ;; Hop version
      (hop-verb 1 "Hop " (hop-color 1 "v" (hop-version)) "\n")

      ;; kill
      (when killp
	 (hop-verb 2 "Kill HOP process " (key-filepath p) "...\n")
	 (let ((key (hop-process-key-read p)))
	    (if (string? key)
		(http :port p :path (format "/hop/shutdown/kill?key=~a" key))
		(error "hop-kill" "Cannot find process key" (key-filepath p)))
	    (exit 0)))

      ;; open the server socket before switching to a different process owner
      (when (>=fx (hop-port) 0)
	 (hop-server-socket-set! (init-server-socket! (hop-port) #f))
	 (hop-port-set! (socket-port-number (hop-server-socket))))
      
      (when (>=fx (hop-ssl-port) 0)
	 (hop-server-ssl-socket-set! (init-server-socket! (hop-ssl-port) #t))
	 (hop-ssl-port-set! (socket-port-number (hop-server-ssl-socket))))
      
      ;; set the hop process owner
      (when setuser
	 (hop-user-set! setuser)
	 (set-hop-owner! setuser))

      ;; log
      (when log-file
	 (let ((p (append-output-file log-file)))
	    (unless p
	       (error "hop" "Cannot open log file" log-file))
	    (hop-log-file-set! p)))
      
      ;; mime types
      (when mimep
	 (load-mime-types (hop-mime-types-file))
	 (cond
	    ((string? mime-file)
	     (load-mime-types mime-file))
	    ((getenv "HOME")
	     =>
	     (lambda (p)
		(load-mime-types (make-file-name p ".mime.types"))))))
      
      ;; clear sofiles
      (when clear-so
	 (let ((dir (dirname (hop-sofile-path "dummy.so"))))
	    (delete-path dir)))
      
      ;; clear all caches
      (when clear-cache
	 (for-each (lambda (cache)
		      (when (directory? cache)
			 (hop-verb 1 "deleting cache directory \""
			    (hop-color 4 cache "") "\"\n")
			 (delete-path cache)))
	    (list (make-cache-name)
	       (hop-sofile-directory)
	       (hop-cache-directory))))

      ;; create cache directory
      (when (hop-cache-enable)
	 (let ((cache (make-cache-name)))
	    (unless (directory? cache)
	       (make-directories cache))))
      
      ;; weblets path
      (hop-autoload-directory-add!
	 (make-file-name (hop-rc-directory) "weblets"))

      ;; commonjs modules
      (nodejs-compiler-options-add! :commonjs-export commonjs-export)
      
      ;; init hss, scm compilers, and services
      (init-hss-compiler! (hop-default-port))
      
      (init-hopscheme! :reader (lambda (p v) (hop-read p))
	 :tmp-dir (os-tmp)
	 :share (hop-share-directory)
	 :verbose (hop-verbose)
	 :eval (lambda (e)
		  (let* ((ev (eval e))
			 (op (open-output-string)))
		     (obj->javascript-attr ev op)
		     (close-output-port op)))
	 :hop-compile (lambda (obj op compile ctx)
			 (hop->javascript obj op compile #f ctx))
	 :hop-register hop-register-value
	 :hop-library-path (hop-library-path)
	 :features `(hop
		       hop-client
		       ,(string->symbol (format "hop-~a" (hop-branch)))
		       ,(string->symbol (format "hop-~a" (hop-version))))
	 :javascript-version (hop-javascript-version)
	 :expanders `(labels match-case
			   (define-tag . ,hop-client-define-tag)
			(define-xml-compound . ,hop-client-define-xml-compound))
	 :source-map clientc-source-map
	 :arity-check clientc-arity-check
	 :type-check clientc-type-check
	 :debug clientc-debug
	 :compress clientc-compress
	 :inlining clientc-inlining
	 :module-use-strict clientc-use-strict
	 :function-use-strict clientc-use-strict)

      (init-clientc-compiler! :modulec hopscheme-compile-module
	 :expressionc hopscheme-compile-expression
	 :valuec hopscheme-compile-value
	 :macroe hopscheme-create-empty-macro-environment
	 :filec hopscheme-compile-file
	 :sexp->precompiled sexp->hopscheme
	 :precompiled->sexp hopscheme->sexp
	 :precompiled->JS-expression hopscheme->JS-expression
	 :precompiled->JS-statement hopscheme->JS-statement
	 :precompiled->JS-return hopscheme->JS-return
	 :precompiled-declared-variables hopscheme-declared
	 :precompiled-free-variables hopscheme-free
	 :filename-resolver hop-clientc-filename-resolver
	 :jsc nodejs-compile-client-file
	 :jsonc nodejs-compile-json
	 :htmlc nodejs-compile-html)

      (init-hop-services!)
      (init-hop-widgets!)

      ;; hoprc
      (if loadp
	  (hop-rc-loaded!
	     (or (parseargs-loadrc rc-file (hop-rc-file)) rc-file))
	  (add-user! "anonymous" 
	     :services '(home doc epassword wizard hz/list shutdown)
	     :directories (hop-path)
	     :preferences-filename #f))

      ;; webdav
      (when (boolean? webdav)
	 (hop-enable-webdav-set! webdav))
	 
      ;; zeroconf
      (when (boolean? zeroconf)
	 (hop-enable-zeroconf-set! zeroconf))
	 
      ;; default backend
      (when (string? be) (hop-xml-backend-set! (string->symbol be)))
      
      (when autoloadp (install-autoload-weblets! (hop-autoload-directories)))
      
      (for-each (lambda (l) (eval `(library-load ',l))) libraries)
      
      ;; write the process key
      (hop-process-key-write (hop-process-key) (hop-default-port))
      (register-exit-function! (lambda (ret)
				  (hop-process-key-delete (hop-default-port))
				  ret))

      (values (reverse files) (reverse! exprs) (reverse! exprsjs))))

;*---------------------------------------------------------------------*/
;*    set-hop-owner! ...                                               */
;*---------------------------------------------------------------------*/
(define (set-hop-owner! user)

   (define (err)
      (error "hop"
	     "Hop is not allowed to be executed as `root'. Create a dedicated Hop user to run Hop on behalf of.\n"
	     "If you know what you are doing and want to run Hop with the
`root' permissions, edit the Hop configuration file and set the appropriate `hop-user' value."))

   (cond
      ((not (=fx (getuid) 0))
       #unspecified)
      ((not (pair? (getpwnam "root")))
       #unspecified)
      ((not user)
       #unspecified)
      ((string? user)
       (if (string=? user "root")
	   (error "hop" "Hop is executed as root (which is forbidden) and fails to switch to the dedicated HOP system user" user)
	   (let ((pw (getpwnam user)))
	      (if (pair? pw)
		  (let ((uid (caddr pw))
			(gid (cadddr pw)))
		     (unless (=fx (getuid) uid)
			(hop-verb 2 "  switch to user: "
			   (hop-color 2 "" user) " (" uid ":" gid ")\n")
			(setgid gid)
			(setuid uid)))
		  (error "hop" "Hop is executed as root (which is forbidden) and fails to switch to the dedicated HOP system user" user)))))
      (user
       (err))
      (else
       #unspecified)))

;*---------------------------------------------------------------------*/
;*    hello-world ...                                                  */
;*---------------------------------------------------------------------*/
(define (hello-world)
   ;; ports and various configuration
   (when (>=fx (hop-port) 0)
      (hop-verb 1
	 "  http: "
	 (hop-color 2 "" (hop-port)) "\n"))
   (when (>=fx (hop-ssl-port) 0)
      (hop-verb 1
	 (format "  https (~a): " (hop-https-protocol))
	 (hop-color 2 "" (hop-ssl-port)) "\n"))
   ;; host
   (hop-verb 1
      "  hostname: " (hop-color 2 "" (hop-server-hostname)) "\n")
   (hop-verb 1
      "  hostip: " (hop-color 2 "" (hop-server-hostip)) "\n")
   ;; security
   (hop-verb 2
      "  security: "
      (with-access::security-manager (hop-security-manager) (name)
	 (hop-color 2 "" name))
      " [" (hop-security) "]\n")
   (hop-verb 3 "  session: " (hop-color 2 "" (hop-session)) "\n")
   (hop-verb 3 "  backend: " (hop-color 2 "" (hop-backend)) "\n")
   (hop-verb 3 "  scheduler: "
      (hop-color 2 ""
	 (cond-expand
	    (enable-threads (hop-scheduling))
	    (else "single-threaded")))
      "\n"))

;*---------------------------------------------------------------------*/
;*    usage ...                                                        */
;*---------------------------------------------------------------------*/
(define (usage args-parse-usage)
   (print "Hop v" (hop-version))
   (print "usage: hop [options] ...")
   (print "       hop [options] file.hop|file.hz|file.js ...")
   (args-parse-usage #f)
   (newline)
   (print "Shell Variables:")
   (print "   - HOPHZREPOSITORY: repository of hz files")
   (print "   - HOPTRACE: hop internal trace [HOPTRACE=\"key1, key2, ...\"]")
   (print "      j2s:info, j2s:type, j2s:utype, j2s:hint, j2s:usage, j2s:key")
   (print "      j2s:dump, nodejs:compile, hopscript:cache, hopscript:hint")
   (print "      j2s:scope")
   (print "   - HOPVERBOSE: an integer")
   (print "   - HOPCFLAGS: hopc compilation flags")
   (print "   - NODE_DEBUG: nodejs internal debugging [NODE_DEBUG=key]")
   (print "   - NODE_PATH: nodejs require path")
   (newline)
   (print "Runtime Command file:")
   (print "   - rc-dir: " (hop-rc-directory))
   (print "   - rc-file: " (hop-rc-file)))

;*---------------------------------------------------------------------*/
;*    parseargs-loadrc ...                                             */
;*---------------------------------------------------------------------*/
(define (parseargs-loadrc rc-file default)
   (if (string? rc-file)
       (let ((suf (suffix rc-file)))
	  (cond
	     ((member suf '("hop" "scm"))
	      (hop-load-rc rc-file)
	      rc-file)
	     ((member suf '("js"))
	      rc-file)))
       (let ((path (make-file-name (hop-rc-directory) default)))
	  (if (file-exists? path)
	      (hop-load-rc path)
	      (let ((jspath (string-append (prefix path) ".js")))
		 (if (file-exists? jspath)
		     jspath
		     (let ((def (make-file-name (hop-etc-directory) default)))
			(hop-load-rc def))))))))

;*---------------------------------------------------------------------*/
;*    key-filename ...                                                 */
;*---------------------------------------------------------------------*/
(define (key-filename port)
   (format ".process-key.~a" port))

;*---------------------------------------------------------------------*/
;*    key-filepath ...                                                 */
;*---------------------------------------------------------------------*/
(define (key-filepath port)
   (make-file-name (hop-rc-directory) (key-filename port)))

;*---------------------------------------------------------------------*/
;*    hop-process-key-write ...                                        */
;*    -------------------------------------------------------------    */
;*    Write the HOP process for other Hop processes.                   */
;*---------------------------------------------------------------------*/
(define (hop-process-key-write key port)
   (let ((dir (hop-rc-directory)))
      (when (directory? dir)
	 (let ((path (make-file-name dir (key-filename port))))
	    (hop-verb 3 "  key process file: " (hop-color 4 "" path) "\n")
	    (when (file-exists? path) (delete-file path))
	    (with-output-to-file path (lambda () (display key)))
	    (chmod path #o600)))))

;*---------------------------------------------------------------------*/
;*    hop-process-key-read ...                                         */
;*---------------------------------------------------------------------*/
(define (hop-process-key-read port)
   (let ((dir (hop-rc-directory)))
      (when (directory? dir)
	 (let ((path (make-file-name dir (key-filename port))))
	    (when (file-exists? path)
	       (with-input-from-file path read-string))))))

;*---------------------------------------------------------------------*/
;*    hop-process-key-delete ...                                       */
;*---------------------------------------------------------------------*/
(define (hop-process-key-delete port)
   (let* ((dir (hop-rc-directory))
	  (path (make-file-name dir (key-filename port))))
      (when (file-exists? path) (delete-file path))))

;*---------------------------------------------------------------------*/
;*    hop-clientc-filename-resolver ...                                */
;*---------------------------------------------------------------------*/
(define (hop-clientc-filename-resolver name ctx module)
   (cond
      ((or (string-suffix? ".js" name) (not (string? ctx)))
       (when module
	  (nodejs-resolve name ctx module 'head)))
      (else
       (find-file/path name ctx))))
