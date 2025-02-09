;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/hopscript/arraybufferview.scm       */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Wed Jun 18 07:29:16 2014                          */
;*    Last change :  Fri Nov 11 19:19:13 2022 (serrano)                */
;*    Copyright   :  2014-22 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Native Bigloo support of JavaScript ArrayBufferView              */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __hopscript_arraybufferview

   (library hop)

   (include "types.sch" "stringliteral.sch")
   
   (import __hopscript_types
	   __hopscript_arithmetic
	   __hopscript_object
	   __hopscript_function
	   __hopscript_property
	   __hopscript_error
	   __hopscript_private
	   __hopscript_public
	   __hopscript_lib
	   __hopscript_number
	   __hopscript_worker
	   __hopscript_arraybuffer
	   __hopscript_array)

   (export (js-init-arraybufferview! ::JsGlobalObject)
	   (js-typedarray-lengthu32 o::JsTypedArray %this #!optional cache)

	   (js-int8array-index-set! ::JsInt8Array ::uint32 ::int8)
	   (js-int8array-fixnum-set! ::JsInt8Array ::long ::int8)
	   (js-uint8array-index-set! ::JsUint8Array ::uint32 ::uint8)
	   (js-uint8array-fixnum-set! ::JsUint8Array ::long ::uint8)
	   (js-typedarray-slice ::JsTypedArray start end ::JsGlobalObject)))

;*---------------------------------------------------------------------*/
;*    &begin!                                                          */
;*---------------------------------------------------------------------*/
(define __js_strings (&begin!))

;*---------------------------------------------------------------------*/
;*    object-serializer ::JsArrayBuffer ...                            */
;*---------------------------------------------------------------------*/
(define (arraybufferview-serializer o::JsArrayBufferView)
   (with-access::JsArrayBufferView o (%data) %data))

(define-macro (arraybufferview-unserializer type bpe)
   `(lambda (o ctx)
       (if (isa? ctx JsGlobalObject)
	   (let ((this ctx))
	      (with-access::JsGlobalObject this (js-arraybuffer js-int8array)
		 (let ((abuf (instantiateJsArrayBuffer
				(mode (js-arraybuffer-default-mode))
				(__proto__ (js-get js-arraybuffer (& "prototype") this))
				(data o))))
		    (,(symbol-append 'instantiate type)
		     (mode (js-arraybuffer-default-mode))
		     (__proto__ (js-get js-int8array (& "prototype") this))
		     (%data o)
		     (bpe 1)
		     (length (u8vector-length o))
		     (byteoffset 0)
		     (buffer abuf)))))
	   (error ,(format "string->obj ::~a" type) "Not a JavaScript context" ctx))))

(register-class-serialization! JsInt8Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsInt8Array 1))
(register-class-serialization! JsUint8Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsUint8Array 1))

(register-class-serialization! JsInt16Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsInt16Array 2))
(register-class-serialization! JsUint16Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsUint16Array 2))

(register-class-serialization! JsInt32Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsInt32Array 4))
(register-class-serialization! JsUint32Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsUint32Array 4))

(register-class-serialization! JsBigInt64Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsBigInt64Array 8))
(register-class-serialization! JsBigUint64Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsBigUint64Array 8))

(register-class-serialization! JsFloat32Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsFloat32Array 4))

(register-class-serialization! JsFloat64Array
   arraybufferview-serializer
   (arraybufferview-unserializer JsFloat64Array 8))

(register-class-serialization! JsDataView
   arraybufferview-serializer
   (lambda (o ctx)
      (if (isa? ctx JsGlobalObject)
	  (let ((this ctx))
	     (with-access::JsGlobalObject this (js-arraybuffer js-int8array)
		(let ((abuf (instantiateJsArrayBuffer
			       (mode (js-arraybuffer-default-mode))
			       (__proto__ (js-get js-arraybuffer (& "prototype") this))
			       (data o))))
		   (instantiateJsDataView
		      (mode (js-dataview-default-mode))
		      (__proto__ (js-get js-int8array (& "prototype") this))
		      (%data o)
		      (byteoffset 0)
		      (buffer abuf)))))
	  (error "string->obj ::JsDataView" "Not a JavaScript context" ctx))))

;*---------------------------------------------------------------------*/
;*    js-donate ::JsDataView ...                                       */
;*---------------------------------------------------------------------*/
(define-method (js-donate obj::JsDataView worker %_this)
   (with-access::WorkerHopThread worker (%this)
      (with-access::JsGlobalObject %this (js-arraybuffer)
	 (with-access::JsDataView obj (%data buffer frozen byteoffset)
	    (let ((nbuffer (js-donate buffer worker %_this)))
	       (instantiateJsDataView
		  (mode (js-dataview-default-mode))
		  (__proto__ (js-get js-arraybuffer (& "prototype") %this))
		  (frozen frozen)
		  (buffer nbuffer)
		  (%data (with-access::JsArrayBuffer nbuffer (data) data))
		  (byteoffset byteoffset)))))))

;*---------------------------------------------------------------------*/
;*    js-donate ::JsTypedArray ...                                     */
;*---------------------------------------------------------------------*/
(define-method (js-donate obj::JsTypedArray worker %_this)
   (with-access::WorkerHopThread worker (%this)
      (with-access::JsGlobalObject %this (js-arraybuffer)
	 (with-access::JsTypedArray obj (%data buffer frozen byteoffset bpe length)
	    (let ((nbuffer (js-donate buffer worker %_this))
		  (obj (class-constructor (object-class obj))))
	       (with-access::JsTypedArray obj (frozen buffer
						 %data byteoffset bpe length)
		  (js-object-proto-set! obj
		     (js-get js-arraybuffer (& "prototype") %this))
 		  (set! frozen frozen)
		  (set! buffer nbuffer)
		  (set! %data (with-access::JsArrayBuffer nbuffer (data) data))
		  (set! byteoffset byteoffset)
		  (set! bpe bpe)
		  (set! length length)
		  obj))))))

;*---------------------------------------------------------------------*/
;*    hop->javascript ::JsDataView ...                                 */
;*---------------------------------------------------------------------*/
(define-method (hop->javascript o::JsDataView op compile isexpr ctx)
   (with-access::JsDataView o (frozen byteoffset buffer)
      (display "hop_buffer( \"JsJsDataView\", " op)
      (display (if frozen "true" "false") op)
      (display ", " op)
      (display byteoffset op)
      (display ", " op)
      (hop->javascript buffer op compile isexpr ctx)
      (display ")" op)))

;*---------------------------------------------------------------------*/
;*    javascript-buffer->arraybufferview ...                           */
;*    -------------------------------------------------------------    */
;*    See __hopscript_arraybuffer                                      */
;*---------------------------------------------------------------------*/
(define (javascript-buffer->arraybufferview name args %this)
   (with-access::JsArrayBuffer (caddr args) (data)
      (let ((buf (instantiateJsDataView
		    (mode (js-dataview-default-mode))
		    (frozen (car args))
		    (byteoffset (fixnum->uint32 (cadr args)))
		    (buffer (caddr args))
		    (%data data))))
	 (js-put! buf (& "length") (u8vector-length data) #f %this)
	 buf)))

;*---------------------------------------------------------------------*/
;*    hop->javascript ::JsTypedArray ...                               */
;*---------------------------------------------------------------------*/
(define-method (hop->javascript o::JsTypedArray op compile isexpr ctx)
   (with-access::JsTypedArray o (frozen byteoffset length bpe buffer)
      (display "hop_buffer( \"" op)
      (display (class-name (object-class o)) op)
      (display "\", " op)
      (display (if frozen "true" "false") op)
      (display ", " op)
      (display byteoffset op)
      (display ", " op)
      (display length op)
      (display ", " op)
      (display bpe op)
      (display ", " op)
      (hop->javascript buffer op compile isexpr ctx)
      (display ")" op)))

;*---------------------------------------------------------------------*/
;*    js-typedarray-dup ...                                            */
;*---------------------------------------------------------------------*/
(define-generic (js-typedarray-dup o::JsTypedArray %this::JsGlobalObject))

(define-method (js-typedarray-dup o::JsInt8Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-int8array)
      (with-access::JsInt8Array o (length)
	 (js-new %this js-int8array (uint32->fixnum length)))))

(define-method (js-typedarray-dup o::JsUint8Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-uint8array)
      (with-access::JsUint8Array o (length)
	 (js-new %this js-uint8array (uint32->fixnum length)))))

(define-method (js-typedarray-dup o::JsInt16Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-int16array)
      (with-access::JsInt16Array o (length)
	 (js-new %this js-int16array (uint32->fixnum length)))))

(define-method (js-typedarray-dup o::JsUint16Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-uint16array)
      (with-access::JsUint16Array o (length)
	 (js-new %this js-uint16array (uint32->fixnum length)))))

(define-method (js-typedarray-dup o::JsInt32Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-int32array)
      (with-access::JsInt32Array o (length)
	 (js-new %this js-int32array (uint32->fixnum length)))))

(define-method (js-typedarray-dup o::JsUint32Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-uint32array)
      (with-access::JsUint32Array o (length)
	 (js-new %this js-uint32array (uint32->fixnum length)))))

(define-method (js-typedarray-dup o::JsBigInt64Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-bigint64array)
      (with-access::JsBigInt64Array o (length)
	 (js-new %this js-bigint64array (uint32->fixnum length)))))

(define-method (js-typedarray-dup o::JsBigUint64Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-biguint64array)
      (with-access::JsBigUint64Array o (length)
	 (js-new %this js-biguint64array (uint32->fixnum length)))))

(define-method (js-typedarray-dup o::JsFloat32Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-float32array)
      (with-access::JsFloat32Array o (length)
	 (js-new %this js-float32array (uint32->fixnum length)))))

(define-method (js-typedarray-dup o::JsFloat64Array %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-float64array)
      (with-access::JsFloat64Array o (length)
	 (js-new %this js-float64array (uint32->fixnum length)))))

;*---------------------------------------------------------------------*/
;*    js-typedarray-ref ::JsInt8Array ...                              */
;*---------------------------------------------------------------------*/
(define (js-i8array-ref buf::u8vector i::int)
   (int8->fixnum (uint8->int8 (u8vector-ref buf i))))

(define (js-i8array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (let ((val (js-tointeger v %this)))
      ($u8vector-set! buf i
	 (fixnum->int8 (if (flonum? val) (flonum->fixnum val) val)))))

(define-method (js-typedarray-ref o::JsInt8Array) js-i8array-ref)
(define-method (js-typedarray-set! o::JsInt8Array) js-i8array-set!)

(define (js-int8array-index-set! a::JsInt8Array i::uint32 v::int8)
   (with-access::JsInt8Array a (buffer length byteoffset bpe)
      (with-access::JsArrayBuffer buffer (data)
	 (let ((j (uint32->fixnum (+u32 byteoffset i))))
	    (when (<fx j (u8vector-length data))
	       ($u8vector-set! data j v))))))

(define (js-int8array-fixnum-set! a::JsInt8Array i::long v::int8)
   (when (>=fx i 0)
      (js-int8array-index-set! a (fixnum->uint32 i) v)))
   
(define (js-new-int8array::JsInt8Array l::uint32 %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-int8array js-arraybuffer)
      (let* ((b (instantiateJsArrayBuffer
		   (cmap (js-not-a-cmap))
		   (data (make-u8vector (uint32->fixnum l)))))
	     (o (instantiateJsInt8Array
		   (length l)
		   (bpe #u32:1)
		   (buffer b)
		   (cmap (js-not-a-cmap))
		   (byteoffset #u32:0))))
	 (js-object-mode-set! b (js-arraybuffer-default-mode))
	 (js-object-mode-set! o (js-typedarray-default-mode))
	 (with-access::JsFunction js-arraybuffer (prototype)
	    (js-object-proto-set! b prototype))
	 (with-access::JsFunction js-int8array (prototype)
	    (js-object-proto-set! o prototype))
	 (unless *optimize-length*
	    (js-put! b (& "length") (uint32->fixnum l) #f %this))
	 o)))

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsUint8Array ...                            */
;*---------------------------------------------------------------------*/
(define (js-u8array-ref  buf::u8vector i::int)
   (uint8->fixnum (u8vector-ref buf i)))

(define (js-u8array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (let ((val (js-tointeger v %this)))
      ($u8vector-set! buf i
	 (fixnum->uint8 (if (flonum? val) (flonum->fixnum val) val)))))

(define-method (js-typedarray-ref o::JsUint8Array) js-u8array-ref)
(define-method (js-typedarray-set! o::JsUint8Array) js-u8array-set!)

(define (js-uint8array-index-set! a::JsUint8Array i::uint32 v::uint8)
   (with-access::JsUint8Array a (buffer length byteoffset bpe)
      (with-access::JsArrayBuffer buffer (data)
	 (let ((j (uint32->fixnum (+u32 byteoffset i))))
	    (when (<fx j (u8vector-length data))
	       ($u8vector-set! data j v))))))

(define (js-uint8array-fixnum-set! a::JsUint8Array i::long v::uint8)
   (when (>=fx i 0)
      (js-uint8array-index-set! a (fixnum->uint32 i) v)))

(define (js-new-uint8array::JsUint8Array l::uint32 %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-uint8array js-arraybuffer)
      (let* ((b (instantiateJsArrayBuffer
		  (cmap (js-not-a-cmap))
		  (data (make-u8vector (uint32->fixnum l)))))
	    (o (instantiateJsUint8Array
		  (length l)
		  (bpe #u32:1)
		  (buffer b)
		  (cmap (js-not-a-cmap))
		  (byteoffset #u32:0))))
	 (js-object-mode-set! b (js-arraybuffer-default-mode))
	 (js-object-mode-set! o (js-typedarray-default-mode))
	 (with-access::JsFunction js-arraybuffer (prototype)
	    (js-object-proto-set! b prototype))
	 (with-access::JsFunction js-uint8array (prototype)
	    (js-object-proto-set! o prototype))
	 (unless *optimize-length*
	    (js-put! o (& "length") (uint32->fixnum l) #f %this))
	 o)))

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsUint8ClampedArray ...                     */
;*---------------------------------------------------------------------*/
(define (js-u8clampledarray-ref buf::u8vector i::int)
   (uint8->fixnum (u8vector-ref buf i)))

(define (js-u8clampledarray-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (let ((val (js-tointeger v %this)))
      (let ((n (if (flonum? val) (flonum->fixnum val) val)))
	 (cond
	    ((<fx n 0) ($u8vector-set! buf i 0))
	    ((>fx n 255) ($u8vector-set! buf i 255))
	    (else ($u8vector-set! buf i (fixnum->uint8 n)))))))

(define-method (js-typedarray-ref o::JsUint8ClampedArray)
   js-u8clampledarray-ref)

(define-method (js-typedarray-set! o::JsUint8ClampedArray)
   js-u8clampledarray-set!)

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsInt16Array ...                            */
;*---------------------------------------------------------------------*/
(define (js-i16array-ref buf::u8vector i::int)
   (int16->fixnum ($s16/u8vector-ref buf (*fx 2 i))))

(define (js-i16array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (let ((val (js-tointeger v %this)))
      ($s16/u8vector-set! buf (*fx 2 i)
	 (fixnum->int16 (if (flonum? val) (flonum->fixnum val) val)))))

(define-method (js-typedarray-ref o::JsInt16Array) js-i16array-ref)
(define-method (js-typedarray-set! o::JsInt16Array) js-i16array-set!)

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsUint16Array ...                           */
;*---------------------------------------------------------------------*/
(define (js-u16array-ref buf::u8vector i::int)
   (uint16->fixnum ($u16/u8vector-ref buf (*fx 2 i))))

(define (js-u16array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (let ((val (js-tointeger v %this)))
      ($u16/u8vector-set! buf (*fx 2 i)
	 (fixnum->uint16 (if (flonum? val) (flonum->fixnum val) val)))))

(define-method (js-typedarray-ref o::JsUint16Array) js-u16array-ref)
(define-method (js-typedarray-set! o::JsUint16Array) js-u16array-set!)

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsInt32Array ...                            */
;*---------------------------------------------------------------------*/
(define (js-i32array-ref buf::u8vector i::int)
   (cond-expand
      (bint61
       (int32->fixnum ($s32/u8vector-ref buf (*fx 4 i))))
      (else
       (let ((v::int32 ($s32/u8vector-ref buf (*fx 4 i))))
	  (if (or (>s32 v (bit-lshs32 #s32:1 28))
		  (<s32 v (negs32 (bit-lshs32 #s32:1 28))))
	      (fixnum->flonum (int32->fixnum v))
	      (int32->fixnum v))))))

(define (js-i32array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (let ((val (js-tointeger v %this)))
      ($s32/u8vector-set! buf (*fx 4 i)
	 (fixnum->int32 (if (flonum? val) (flonum->fixnum val) val)))))

(define-method (js-typedarray-ref o::JsInt32Array) js-i32array-ref)
(define-method (js-typedarray-set! o::JsInt32Array) js-i32array-set!)

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsUint32Array ...                           */
;*---------------------------------------------------------------------*/
(define (js-u32array-ref buf::u8vector i::int)
   (cond-expand
      (bint61
       (uint32->fixnum ($s32/u8vector-ref buf (*fx 4 i))))
      (else
       (let ((v::uint32 ($s32/u8vector-ref buf (*fx 4 i))))
	  (if (>u32 v (bit-lshu32 #u32:1 29))
	      (uint32->flonum ($s32/u8vector-ref buf (*fx 4 i)))
	      (uint32->fixnum ($s32/u8vector-ref buf (*fx 4 i))))))))

(define (js-u32array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (let ((val (js-tointeger v %this)))
      ($s32/u8vector-set! buf (*fx 4 i)
	 (if (flonum? val) (flonum->uint32 val) (fixnum->uint32 val)))))

(define-method (js-typedarray-ref o::JsUint32Array) js-u32array-ref)
(define-method (js-typedarray-set! o::JsUint32Array) js-u32array-set!)

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsBigInt64Array ...                         */
;*---------------------------------------------------------------------*/
(define (js-i64array-ref buf::u8vector i::int)
   (cond-expand
      (bigloo4.4b
       (llong->bignum (int64->llong ($s64/u8vector-ref buf (*fx 8 i)))))
      (else
       (int64->bignum ($s64/u8vector-ref buf (*fx 8 i))))))

(define (js-i64array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (if (bignum? v)
       (cond-expand
	  (bigloo4.4b
	   ($s64/u8vector-set! buf (*fx 8 i) (llong->int64 (bignum->llong v))))
	  (else
	   ($s64/u8vector-set! buf (*fx 8 i) (bignum->int64 v))))
       (js-raise-type-error %this "Cannot convert ~a to BigInt" v)))

(define-method (js-typedarray-ref o::JsBigInt64Array) js-i64array-ref)
(define-method (js-typedarray-set! o::JsBigInt64Array) js-i64array-set!)

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsBigUint64Array ...                        */
;*---------------------------------------------------------------------*/
(define (js-u64array-ref buf::u8vector i::int)
   (cond-expand
      (bigloo4.4b
       (llong->bignum (int64->llong ($s64/u8vector-ref buf (*fx 8 i)))))
      (else
       (uint64->bignum ($s64/u8vector-ref buf (*fx 8 i))))))

(define (js-u64array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (if (bignum? v)
       (cond-expand
	  (bigloo4.4b
	   ($s64/u8vector-set! buf (*fx 8 i) (llong->uint64 (bignum->llong v))))
	  (else
	   ($s64/u8vector-set! buf (*fx 8 i) (bignum->uint64 v))))
       (js-raise-type-error %this "Cannot convert ~a to BigInt" v)))

(define-method (js-typedarray-ref o::JsBigUint64Array) js-u64array-ref)
(define-method (js-typedarray-set! o::JsBigUint64Array) js-u64array-set!)

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsFloat32Array ...                          */
;*---------------------------------------------------------------------*/
(define (js-f32array-ref buf::u8vector i::int)
   ($f32/u8vector-ref buf (*fx 4 i)))

(define (js-f32array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (let ((val (js-tonumber v %this)))
      ($f32/u8vector-set! buf (*fx 4 i)
	 (if (fixnum? val) (fixnum->flonum val) val))))

(define-method (js-typedarray-ref o::JsFloat32Array) js-f32array-ref)
(define-method (js-typedarray-set! o::JsFloat32Array) js-f32array-set!)

;*---------------------------------------------------------------------*/
;*    js-typedarray-set! ::JsFloat64Array ...                          */
;*---------------------------------------------------------------------*/
(define (js-f64array-ref buf::u8vector i::int)
   ($f64/u8vector-ref buf (*fx 8 i)))

(define (js-f64array-set! buf::u8vector i::int v::obj %this::JsGlobalObject)
   (let ((val (js-tonumber v %this)))
      ($f64/u8vector-set! buf (*fx 8 i)
	 (if (fixnum? val) (fixnum->flonum val) val))))

(define-method (js-typedarray-ref o::JsFloat64Array) js-f64array-ref)
(define-method (js-typedarray-set! o::JsFloat64Array) js-f64array-set!)

;*---------------------------------------------------------------------*/
;*    js-init-arraybufferview! ...                                     */
;*---------------------------------------------------------------------*/
(define (js-init-arraybufferview! %this)
   (unless (vector? __js_strings) (set! __js_strings (&init!)))
   (with-access::JsGlobalObject %this (js-function js-object)
      (let ((proto (instantiateJsObject
		      (__proto__ (js-object-proto %this))
		      (elements ($create-vector 1)))))
	 (js-init-typedarray-prototype! proto %this)
	 
	 (with-access::JsGlobalObject %this (js-int8array)
	    (set! js-int8array
	       (js-init-typedarray! %this "Int8Array" 1 proto)))
	 (with-access::JsGlobalObject %this (js-uint8array)
	    (set! js-uint8array
	       (js-init-typedarray! %this "Uint8Array" 1 proto)))
	 (with-access::JsGlobalObject %this (js-uint8clampedarray)
	    (set! js-uint8clampedarray
	       (js-init-typedarray! %this "Uint8ClampedArray" 1 proto)))
	 (with-access::JsGlobalObject %this (js-int16array)
	    (set! js-int16array
	       (js-init-typedarray! %this "Int16Array" 2 proto)))
	 (with-access::JsGlobalObject %this (js-uint16array)
	    (set! js-uint16array
	       (js-init-typedarray! %this "Uint16Array" 2 proto)))
	 (with-access::JsGlobalObject %this (js-int32array)
	    (set! js-int32array
	       (js-init-typedarray! %this "Int32Array" 4 proto)))
	 (with-access::JsGlobalObject %this (js-uint32array)
	    (set! js-uint32array
	       (js-init-typedarray! %this "Uint32Array" 4 proto)))
	 (with-access::JsGlobalObject %this (js-bigint64array)
	    (set! js-bigint64array
	       (js-init-typedarray! %this "BigInt64Array" 8 proto)))
	 (with-access::JsGlobalObject %this (js-biguint64array)
	    (set! js-biguint64array
	       (js-init-typedarray! %this "BigUint64Array" 8 proto)))
	 (with-access::JsGlobalObject %this (js-float32array)
	    (set! js-float32array
	       (js-init-typedarray! %this "Float32Array" 4 proto)))
	 (with-access::JsGlobalObject %this (js-float64array)
	    (set! js-float64array
	       (js-init-typedarray! %this "Float64Array" 8 proto)))
	 (with-access::JsGlobalObject %this (js-dataview)
	    (set! js-dataview (js-init-dataview! %this))))))

;*---------------------------------------------------------------------*/
;*    js-init-typedarray-prototype! ...                                */
;*---------------------------------------------------------------------*/
(define (js-init-typedarray-prototype! proto %this)

   (define (js-typedarray-includes this::obj val idx)
      
      (define (startidx len idx)
	 (if (eq? idx (js-undefined))
	     #u32:0
	     (let ((i (js-toint32 idx %this)))
		(cond
		   ((>=s32 i 0) (int32->uint32 i))
		   ((>u32 (int32->uint32 (negs32 i)) len) #u32:0)
		   (else (-u32 len (int32->uint32 (negs32 i))))))))
      
      (if (isa? this JsTypedArray)
	  (when (js-number? val)
	     (with-access::JsTypedArray this (vref buffer bpe byteoffset)
		(let ((len (js-typedarray-lengthu32 this %this))
		      (vref (js-typedarray-ref this)))
		   (with-access::JsArrayBuffer buffer (data)
		      (let ((data data))
			 (let loop ((i (startidx len idx)))
			    (cond
			       ((>=u32 i len)
				#f)
			       ((= (vref data (uint32->fixnum (+u32 (/u32 byteoffset bpe) i))) val)
				#t)
			       (else
				#f))))))))
	  (js-raise-type-error %this "Object must be a TypedArray" this)))

   (define (js-typedarray-map this::obj proc thisarg)
      (if (isa? this JsTypedArray)
	  (with-access::JsTypedArray this (length (source %data))
	     (let ((v (js-typedarray-dup this %this))
		   (l (uint32->fixnum length))
		   (ref (js-typedarray-ref this))
		   (set (js-typedarray-set! this)))
		(with-access::JsTypedArray v ((target %data))
		   (let loop ((i 0))
		      (if (=fx i l)
			  v
			  (let ((val (ref source i)))
			     (set target i
				((@ js-call1-3 __hopscript_public)
				 %this proc thisarg val i this)
				%this)
			     (loop (+fx i 1))))))))
	  (js-raise-type-error %this "Object must be a TypedArray" this)))
	 
   (define (js-typedarray-tostring this::obj)
      (with-access::JsTypedArray this (vref buffer bpe byteoffset)
	 (with-access::JsArrayBuffer buffer (data)
	    (let ((len (js-typedarray-lengthu32 this %this))
		  (vref (js-typedarray-ref this)))
	       (if (=u32 len #u32:0)
		   ""
		   (let ((data data))
		      (let loop ((i #u32:1)
				 (s (js-string->jsstring
				       (number->string
					  (vref data (uint32->fixnum (/u32 byteoffset bpe)))))))
			 (if (=u32 i len)
			     s
			     (let ((v (vref data (uint32->fixnum (+u32 (/u32 byteoffset bpe) i)))))
				(loop (+u32 i #u32:1)
				   (js-jsstring-append s
				      (js-jsstring-append (& ",")
					 (js-string->jsstring
					    (number->string v))))))))))))))
   
   (js-bind! %this proto (& "includes")
      :value (js-make-function %this js-typedarray-includes
		(js-function-arity js-typedarray-includes)
		(js-function-info :name "includes" :len 1))
      :configurable #t
      :writable #t
      :enumerable #f)

   (js-bind! %this proto (& "map")
      :value (js-make-function %this js-typedarray-map
		(js-function-arity js-typedarray-map)
		(js-function-info :name "map" :len 1))
      :configurable #t
      :writable #t
      :enumerable #f)

   (for-each (lambda (id)
		(js-bind! %this proto (js-ascii-name->jsstring id)
		   :value (js-make-function %this (js-not-implemented id %this)
			     (js-function-arity 0 0)
			     (js-function-info :name id :len 1))
		   :configurable #t
		   :writable #t
		   :enumerable #f))
      '("copyWithin" "entries" "every" "fill" "filter" "find" "findIndex"
	"forEach" "indexOf" "join" "keys" "reduce" "reduceRight" "reverse"
	"set" "slice" "some" "sort" "subarray"
	"values" "@@iterator")))

;*---------------------------------------------------------------------*/
;*    js-init-typedarray! ...                                          */
;*---------------------------------------------------------------------*/
(define (js-init-typedarray! %this name::bstring bp::int proto)
   (with-access::JsGlobalObject %this (__proto__ js-function js-object)
      
      ;; builtin ArrayBufferview prototype
      (define js-typedarray-prototype
	 (instantiateJsObject
	    (__proto__ proto)
	    (elements ($create-vector 1))))
      
      (define (js-create-from-arraybuffer this::JsTypedArray
		 buf::JsArrayBuffer off::uint32 len::uint32)
	 (with-access::JsTypedArray this (buffer %data length byteoffset bpe)
	    (with-access::JsArrayBuffer buf (data)
	       (let ((vlen (u8vector-length data)))
		  (set! buffer buf)
		  (set! %data data)
		  (set! byteoffset off)
		  (set! length len)
		  ;; buffer
		  (js-bind! %this this (& "buffer")
		     :value buffer
		     :configurable #f
		     :writable #f
		     :enumerable #t
		     :hidden-class #t)
		  
		  ;; BYTES_PER_ELEMENT
		  (js-bind! %this this (& "BYTES_PER_ELEMENT")
		     :value (uint32->fixnum bpe)
		     :configurable #f
		     :writable #f
		     :enumerable #t
		     :hidden-class #t)
		  
		  ;; length
		  (js-bind! %this this (& "length")
		     :value (uint32->fixnum len)
		     :configurable #f
		     :writable #f
		     :enumerable #t
		     :hidden-class #t)
		  
		  ;; byteLength
		  (js-bind! %this this (& "byteLength")
		     :value (uint32->fixnum (*u32 bpe length))
		     :configurable #f
		     :writable #f
		     :enumerable #t
		     :hidden-class #t)
		  
		  ;; byteOffset
		  (js-bind! %this this (& "byteOffset")
		     :value (uint32->fixnum off)
		     :configurable #f
		     :writable #f
		     :enumerable #t
		     :hidden-class #t)
		  
		  ;; set
		  (js-bind! %this this (& "set")
		     :value (js-make-function %this js-set
			       (js-function-arity js-set)
			       (js-function-info :name "set" :len 2))
		     :configurable #t
		     :writable #t
		     :enumerable #t
		     :hidden-class #t)
		  
		  ;; get
		  (js-bind! %this this (& "get")
		     :value (js-make-function %this
			       (lambda (this num)
				  (js-get this num %this))
			       (js-function-arity 1 0)
			       (js-function-info :name "get" :len 1))
		     :configurable #t
		     :writable #t
		     :enumerable #t
		     :hidden-class #t)
		  
		  ;; subarray
		  (js-bind! %this this (& "subarray")
		     :value (js-make-function %this js-subarray
			       (js-function-arity js-subarray)
			       (js-function-info :name "subarray" :len 2))
		     :configurable #t
		     :writable #t
		     :enumerable #t
		     :hidden-class #t)))
	    this))
      
      (define (js-typedarray-construct this::JsTypedArray items)
	 (cond
	    ((null? items)
	     (js-create-from-arraybuffer this
		(js-new %this (js-get %this (& "ArrayBuffer") %this))
		#u32:0 #u32:0))
	    ((js-number? (car items))
	     (cond
		((< (car items) 0)
		 (js-raise-range-error %this
		    "ArrayBufferView size is not a small enough positive integer"
		    (car items)))
		((and (flonum? (car items))
		      (>=fl (*fl (fixnum->flonum bp) (car items))
			 1073741823.0))
		 (js-raise-range-error %this
		    "ArrayBufferView size is too large"
		    (car items)))
		((and (>fx bp 1) (>=fx (car items) (/fx 1073741823 bp)))
		 (js-raise-range-error %this
		    "ArrayBufferView size is too large"
		    (car items)))
		(else
		 (let ((len (js-touint32 (car items) %this)))
		    (js-create-from-arraybuffer this
		       (js-new %this (js-get %this (& "ArrayBuffer") %this)
			  (uint32->fixnum (*u32 (fixnum->uint32 bp) len)))
		       #u32:0 len)))))
	    ((isa? (car items) JsArrayBuffer)
	     (with-access::JsArrayBuffer (car items) (data)
		(let ((len (u8vector-length data)))
		   (cond
		      ((or (null? (cdr items)) (not (integer? (cadr items))))
		       (if (=fx (remainder len bp) 0)
			   (js-create-from-arraybuffer this
			      (car items)
			      #u32:0 (fixnum->uint32 len))
			   (js-raise-range-error %this
			      "Byte offset / length is not aligned ~a"
			      (car items))))
		      ((or (null? (cddr items))
			   (not (integer? (caddr items))))
		       (let ((off (->fixnum
				     (js-tointeger (cadr items) %this))))
			  (cond
			     ((not
				 (and (=fx (remainder off bp) 0)
				      (=fx (remainder len bp) 0)))
			      (js-raise-range-error %this
				 "Byte offset / lenght is not aligned ~a"
				 (cadr items)))
			     ((<fx off 0)
			      (js-raise-range-error %this
				 "Byte offset out of range ~a"
				 (cadr items)))
			     (else
			      (js-create-from-arraybuffer this
				 (car items)
				 (fixnum->uint32 off)
				 (fixnum->uint32
				    (-fx (/fx len bp) off)))))))
		      (else
		       (let ((off (->fixnum
				     (js-tointeger (cadr items) %this)))
			     (l (->fixnum
				   (js-tointeger (caddr items) %this))))
			  (cond
			     ((not (=fx (remainder off bp) 0))
			      (js-raise-range-error %this
				 "Byte offset / lenght is not aligned ~a"
				 (cadr items)))
			     ((or (>fx (*fx (-fx l off) bp) len) (<fx l 0))
			      (js-raise-range-error %this
				 "Length is out of range ~a"
				 l))
			     ((<fx off 0)
			      (js-raise-range-error %this
				 "Byte offset out of range ~a"
				 (cadr items)))
			     (else
			      (js-create-from-arraybuffer this
				 (car items)
				 (fixnum->uint32 off)
				 (fixnum->uint32 l))))))))))
	    ((or (js-array? (car items)) (isa? (car items) JsTypedArray))
	     (let ((len (js-get (car items) (& "length") %this)))
		(let* ((arr (js-typedarray-construct this (list len)))
		       (vset (js-typedarray-set! arr)))
		   (with-access::JsTypedArray arr (buffer)
		      (with-access::JsArrayBuffer buffer (data)
			 (let loop ((i 0))
			    (if (<fx i len)
				(let ((v (js-get (car items) i %this)))
				   (unless (eq? v (js-absent))
				      (vset data i v %this))
				   (loop (+fx i 1)))))))
		   arr)))
	    (else
	     (js-typedarray-construct this '()))))
      
      (define (%js-typedarray this . items)
	 (if (eq? (js-new-target-pop! %this) (js-undefined))
	     (js-typedarray-construct 
		(js-typedarray-alloc %this js-typedarray)
		items)
	     (js-typedarray-construct this items)))
      
      (define (js-typedarray-alloc %this constructor::JsFunction)
	 (with-access::JsGlobalObject %this (js-new-target)
	    (set! js-new-target constructor))
	 (let ((o (allocate-instance (string->symbol (string-append "Js" name)))))
	    (with-access::JsTypedArray o (cmap bpe elements)
	       (js-object-mode-set! o (js-typedarray-default-mode))
	       (js-object-mode-extensible-set! o #t)
	       (set! cmap (js-not-a-cmap))
	       (set! bpe (fixnum->uint32 bp))
	       (set! elements '#())
	       (js-object-proto-set! o
		  (js-get constructor (& "prototype") %this)))
	    o))
      
      (define js-typedarray
	 (js-make-function %this %js-typedarray
	    (js-function-arity %js-typedarray)
	    (js-function-info :name name :len 1)
	    :__proto__ (js-object-proto js-function)
	    :size 2
	    :prototype js-typedarray-prototype
	    :alloc js-typedarray-alloc))
      
      (define (js-set this::JsTypedArray array offset)
	 (let ((off (if (eq? offset (js-undefined))
			#u32:0
			(js-touint32 offset %this))))
	    (cond
	       ((isa? array JsTypedArray)
		(with-access::JsTypedArray this ((toff byteoffset)
						 (tlength length)
						 (tbpe bp)
						 (tbuffer buffer))
		   (with-access::JsArrayBuffer tbuffer ((target data))
		      (with-access::JsTypedArray array ((sbuffer buffer)
							(soff byteoffset)
							(slength length))
			 (with-access::JsArrayBuffer sbuffer ((source data))
			    (let ((tstart (+u32 (*u32 (fixnum->uint32 bp) off) toff)))
			       (cond
				  ((>=u32 tstart tlength)
				   (js-raise-range-error %this
				      "Offset out of range ~a"
				      tstart))
				  ((>u32 slength (+u32 tstart tlength))
				   (format
				      "Offset/length out of range ~a/~a ~~a"
				      offset slength))
				  (else
				   (u8vector-copy! target
				      (uint32->fixnum tstart)
				      source
				      (uint32->fixnum soff)
				      (uint32->fixnum
					 (-u32 (+u32 soff slength) 1)))))))))))
	       ((js-array? array)
		(with-access::JsTypedArray this ((toff byteoffset)
						 (tlength length)
						 (tbpe bp)
						 (tbuffer buffer))
		   (with-access::JsArrayBuffer tbuffer ((target data))
		      (let ((tstart (+u32 (*u32 (fixnum->uint32 bp) off) toff))
			    (slength (js-get array (& "length") %this)))
			 (cond
			    ((>=u32 tstart tlength)
			     (js-raise-range-error %this
				"Offset out of range ~a"
				tstart))
			    ((>fx slength
				(uint32->fixnum (+u32 tstart tlength)))
			     (format
				"Offset/length out of range ~a/~a ~~a"
				offset slength))
			    (else
			     (let ((ioff (uint32->fixnum off))
				   (vset (js-typedarray-set! this)))
				(let loop ((i 0))
				   (when (<fx i slength)
				      (let ((o (js-get array i %this)))
					 (unless (eq? o (js-absent))
					    (vset target (+fx i ioff) o %this))
					 (loop (+fx i 1))))))))))))
	       (else
		(js-undefined)))))
      
      (define (js-subarray this::JsTypedArray beg end)
	 (with-access::JsTypedArray this (byteoffset bpe length buffer)
	    (let ((beg (+u32 (/u32 byteoffset bpe) (js-touint32 beg %this))))
	       (cond
		  ((<u32 beg #u32:0) (set! beg #u32:0))
		  ((>u32 beg length) (set! beg (-u32 length bpe))))
	       (let ((len (if (eq? end (js-undefined))
			      length
			      (let ((l (js-touint32 end %this)))
				 (cond
				    ((>u32 l length) length)
				    ((<u32 l beg) 0)
				    (else (-u32 l beg)))))))
		  (%js-typedarray this buffer
		     (uint32->fixnum beg) (uint32->fixnum len))))))

      ;; from
      ;; https://262.ecma-international.org/6.0/#sec-%typedarray%.from
      (define (typedarray-from this::obj arr mapfn T)
	 ;; see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/from
	 ;; 1. Let C be the this value.
	 (let ((C this)
	       ;; 2. Let items be ToObject(arrayLike).
	       (items (js-toobject %this arr)))
	    ;; 3. ReturnIfAbrupt(items).
	    (when (or (eq? arr (js-undefined)) (eq? arr '()))
	       (js-raise-type-error %this
		  "from requires an array-like object - not null or undefined"
		  arr))
	    ;; 4. If mapfn is undefined, then let mapping be false.
	    ;; 5. a If IsCallable(mapfn) is false, throw a TypeError exception.
	    (when (and (not (eq? mapfn (js-undefined)))
		       (not (js-procedure? mapfn)))
	       (js-raise-type-error %this
		  "TypedArray.from: when provided, the second argument must be a function"
		  mapfn))
	    ;; 5. b. If thisArg was supplied, let T be thisArg;
	    ;; else let T be undefined.
	    ;;  10. Let lenValue be Get(items, "length").
	    ;; 11. Let len be ToLength(lenValue).
	    (let ((len (js-get-length items %this)))
	       ;; 13. If IsConstructor(C) is true, then
	       ;; 13. a. Let A be the result of calling the [[Construct]]
	       ;;     internal method of C with an argument list containing
	       ;;     the single item len.
	       ;; 14. a. Else, Let A be ArrayCreate(len).
	       (let ((A (if (js-function? C)
			    (js-toobject %this (js-new1 %this C len))
			    (%js-typedarray this len))))
		  ;; 16. Let k be 0.
		  ;; 17. Repeat, while k < len... (also steps a - h)
		  (let loop ((k 0))
		     (when (<fx k len)
			(let ((kvalue (js-get items k %this)))
			   (if (eq? mapfn (js-undefined))
			       (js-put! A k kvalue #f %this)
			       (let ((v (js-call2 %this mapfn T kvalue k)))
				  (js-put! A k v #f %this)))
			   (loop (+fx k 1)))))
		  (js-put-length! A len #f #f %this)
		  A))))
      
      (js-bind! %this js-typedarray (& "from")
	 :configurable #f :enumerable #f
	 :value (js-make-function %this typedarray-from
		   (js-function-arity typedarray-from)
		   (js-function-info :name "from" :len 0)
		   :prototype (js-undefined))
	 :hidden-class #t)
      
      (js-bind! %this js-typedarray (& "of")
	 :configurable #f :enumerable #f
	 :value (js-not-implemented "of" %this)
	 :hidden-class #t)
      
      ;; bind the Typedarray in the global object
      (js-bind! %this %this (js-string->name name)
	 :configurable #f :enumerable #f :value js-typedarray
	 :hidden-class #t)
      
      js-typedarray))
	 
;*---------------------------------------------------------------------*/
;*    js-properties-names ::JsTypedArray ...                           */
;*---------------------------------------------------------------------*/
(define-method (js-properties-names::vector obj::JsTypedArray enump %this)
   (with-access::JsTypedArray obj (length)
      (let ((len (uint32->fixnum length)))
	 (append! (map js-integer->jsstring (iota len))
	    (call-next-method)))))

;*---------------------------------------------------------------------*/
;*    js-ownkeys ::JsTypedArray ...                                    */
;*---------------------------------------------------------------------*/
(define-method (js-ownkeys obj::JsTypedArray %this)
   (js-vector->jsarray (js-properties-name obj #t %this) %this))

;*---------------------------------------------------------------------*/
;*    js-has-property ::JsTypedArray ...                               */
;*---------------------------------------------------------------------*/
(define-method (js-has-property o::JsTypedArray p %this)
   (with-access::JsTypedArray o (length)
      (let ((index::uint32 (js-toindex p)))
	 (if (js-isindex? index)
	     (if (<=u32 length index)
		 (call-next-method)
		 #t)
	     (call-next-method)))))

;*---------------------------------------------------------------------*/
;*    js-has-own-property ::JsTypedArray ...                           */
;*---------------------------------------------------------------------*/
(define-method (js-has-own-property o::JsTypedArray p %this::JsGlobalObject)
   (not (eq? (js-get-own-property o p %this) (js-undefined))))

;*---------------------------------------------------------------------*/
;*    js-get-own-property ::JsTypedArray ...                           */
;*---------------------------------------------------------------------*/
(define-method (js-get-own-property o::JsTypedArray p %this::JsGlobalObject)
   (with-access::JsTypedArray o (byteoffset bpe length buffer frozen)
      (let ((i::uint32 (js-toindex p)))
	 (cond
	    ((not (js-isindex? i))
	     (call-next-method))
	    ((<uint32 i length)
	     (let ((vref (js-typedarray-ref o)))
		(with-access::JsArrayBuffer buffer (data)
		   (instantiate::JsValueDescriptor
		      (name (js-toname p %this))
		      (value (vref data
				(uint32->fixnum (+u32 (/u32 byteoffset bpe) i))))
		      (enumerable #t)
		      (writable (not frozen))
		      (configurable (not frozen))))))
	    (else
	     (call-next-method))))))

;*---------------------------------------------------------------------*/
;*    js-get-own-property-descriptor ::JsTypedArray ...                */
;*---------------------------------------------------------------------*/
(define-method (js-get-own-property-descriptor o::JsTypedArray p %this::JsGlobalObject)
   (with-access::JsTypedArray o (byteoffset bpe length buffer frozen)
      (let ((i::uint32 (js-toindex p)))
	 (cond
	    ((not (js-isindex? i))
	     (call-next-method))
	    ((<uint32 i length)
	     (let ((vref (js-typedarray-ref o)))
		(with-access::JsArrayBuffer buffer (data)
		   (js-property-descriptor %this #t
		      :value (vref data
				(uint32->fixnum (+u32 (/u32 byteoffset bpe) i)))
		      :enumerable #t)
		   :writable (not frozen)
		   :configurable (not frozen))))
	    (else
	     (call-next-method))))))

;*---------------------------------------------------------------------*/
;*    js-get-typedarray ...                                            */
;*---------------------------------------------------------------------*/
(define (js-get-typedarray o::JsTypedArray p %this)
   (with-access::JsTypedArray o (buffer byteoffset length bpe)
      (let ((i::uint32 (js-toindex p)))
	 (when (and (js-isindex? i) (<uint32 i length))
	    (let ((vref (js-typedarray-ref o)))
	       (with-access::JsArrayBuffer buffer (data)
		  (vref data (uint32->fixnum (+u32 (/u32 byteoffset bpe) i)))))))))

;*---------------------------------------------------------------------*/
;*    *optimize-length* ...                                            */
;*    -------------------------------------------------------------    */
;*    It is difficult to optimize arraybufferview as they are used     */
;*    as the base class for JsFastBuffer that used non uint32          */
;*    length (only for detecting errors).                              */
;*---------------------------------------------------------------------*/
(define *optimize-length* #f)
   
;*---------------------------------------------------------------------*/
;*    js-get-property-value ::JsTypedArray ...                         */
;*    -------------------------------------------------------------    */
;*    This method is optional. It could be removed without changing    */
;*    the programs behaviors. It merely optimizes access to arrays.    */
;*---------------------------------------------------------------------*/
(define-method (js-get-property-value o::JsTypedArray base p %this)
   (if (js-jsstring? p)
       (if (and *optimize-length* (eq? p (& "length")))
	   (with-access::JsTypedArray o (length)
	      (if (=u32 length #u32:0)
		  (call-next-method)
		  (uint32->fixnum length)))
	   (call-next-method))
       (or (js-get-typedarray o p %this) (call-next-method))))

;*---------------------------------------------------------------------*/
;*    js-get ::JsTypedArray ...                                        */
;*---------------------------------------------------------------------*/
(define-method (js-get o::JsTypedArray p %this)
   (if (js-jsstring? p)
       (if (and *optimize-length* (eq? p (& "length")))
	   (with-access::JsTypedArray o (length)
	      (if (=u32 length #u32:0)
		  (call-next-method)
		  (uint32->fixnum length)))
	   (call-next-method))
       (or (js-get-typedarray o p %this) (call-next-method))))

;*---------------------------------------------------------------------*/
;*    js-get-length ::JsTypedArray ...                                 */
;*---------------------------------------------------------------------*/
(define-method (js-get-length o::JsTypedArray %this #!optional cache)
   (with-access::JsTypedArray o (length)
      (if (or (not *optimize-length*) (=u32 length #u32:0))
	  (call-next-method)
	  (uint32->fixnum length))))

;*---------------------------------------------------------------------*/
;*    js-typedarray-lengthu32 ...                                      */
;*---------------------------------------------------------------------*/
(define (js-typedarray-lengthu32 o::JsTypedArray %this #!optional cache)
   (with-access::JsTypedArray o (length)
      (if (or (not *optimize-length*) (=u32 length #u32:0))
	  (js-touint32
	     (if cache
		 (js-get-name/cache o (& "length") #f %this cache)
		 (js-get o (& "length") %this))
	     %this)
	  length)))

;*---------------------------------------------------------------------*/
;*    js-get-jsobject-name/cache-miss ::JsTypedArray ...               */
;*---------------------------------------------------------------------*/
(define-method (js-get-jsobject-name/cache-miss o::JsTypedArray p
		  throw::bool %this::JsGlobalObject
		  cache::JsPropertyCache
		  #!optional)
   (if (and *optimize-length* (eq? p (& "length")))
       (with-access::JsTypedArray o (length)
	  (if (=u32 length #u32:0)
	      (uint32->fixnum length)
	      (call-next-method)))
       (call-next-method)))

;*---------------------------------------------------------------------*/
;*    js-put! ::JsTypedArray ...                                       */
;*---------------------------------------------------------------------*/
(define-method (js-put! o::JsTypedArray p v throw %this)
   
   (define (js-put-array! o::JsTypedArray p::obj v)
      (cond
	 ((not (js-can-put o p %this))
	  ;; 1
	  (js-undefined))
	 ((and *optimize-length* (eq? p (& "length")))
	  ;; 1b, specific to TypedArray where length is not a true property
	  (with-access::JsTypedArray o (length buffer)
	     (when (eq? buffer (class-nil JsArrayBuffer))
		;; only correct length are optimized (for preserving
		;; bad argument errors)
		(if (and (> v 0) (< v (-fx (bit-lsh 1 31) 1)))
		    (set! length (fixnum->uint32 (->fixnum v)))
		    (begin
		       (set! length #u32:0)
		       (call-next-method))))
	     v))
	 (else
	  (let ((owndesc (js-get-own-property o p %this)))
	     ;; 2
	     (if (js-is-data-descriptor? owndesc)
		 ;; 3
		 (with-access::JsValueDescriptor owndesc ((valuedesc value))
		    (set! valuedesc v)
		    (js-define-own-property o p owndesc throw %this))
		 (let ((desc (js-get-property o p %this)))
		    ;; 4
		    (if (js-is-accessor-descriptor? desc)
			;; 5
			(with-access::JsAccessorDescriptor desc ((setter set))
			   (if (js-procedure? setter)
			       (js-call1 %this setter o v)
			       (js-undefined)))
			(let ((newdesc (instantiate::JsValueDescriptor
					  (name p)
					  (value v)
					  (writable #t)
					  (enumerable #t)
					  (configurable #t))))
			   ;; 6
			   (js-define-own-property o p newdesc throw %this)))))
	     v))))
   
   (with-access::JsTypedArray o (buffer length byteoffset bpe conv)
      (let ((i::uint32 (js-toindex p)))
	 (cond
	    ((not (js-isindex? i))
	     (js-put-array! o (js-toname p %this) v))
	    ((<u32 i length)
	     (let ((vset (js-typedarray-set! o)))
		(with-access::JsArrayBuffer buffer (data)
		   (vset data (uint32->fixnum (+u32 (/u32 byteoffset bpe) i))
		      v %this)))
	     v)
	    (else
	     (js-put-array! o (js-toname p %this) v))))))

;*---------------------------------------------------------------------*/
;*    js-delete! ::JsTypedArray ...                                    */
;*---------------------------------------------------------------------*/
(define-method (js-delete! o::JsTypedArray p throw %this)
   (with-access::JsTypedArray o (length)
      (let ((i::uint32 (js-toindex p)))
	 (cond
	    ((not (js-isindex? i))
	     (call-next-method))
	    ((<uint32 i length)
	     #t)
	    (else
	     (call-next-method))))))

;*---------------------------------------------------------------------*/
;*    js-init-dataview! ...                                            */
;*---------------------------------------------------------------------*/
(define (js-init-dataview! %this)
   (with-access::JsGlobalObject %this (js-function js-object)
      (with-access::JsFunction js-function ((js-function-prototype __proto__))

	 ;; host endianess
	 (define host-lendian
	    (eq? (bigloo-config 'endianess) 'little-endian))

	 (define buf (make-u8vector 8))
	 
	 ;; builtin DataView prototype
	 (define js-dataview-prototype
	    (instantiateJsObject
	       (__proto__ (js-object-proto %this))
	       (elements ($create-vector 1))))
	 
	 (define (js-create-from-arraybuffer this::JsDataView
		    buf::JsArrayBuffer off::uint32 len::uint32)
	    (with-access::JsDataView this (buffer %data byteoffset)
	       (with-access::JsArrayBuffer buf (data)
		  (let ((vlen (u8vector-length data)))
		     (set! buffer buf)
		     (set! %data data)
		     (set! byteoffset off)
		     ;; buffer
		     (js-bind! %this this (& "buffer")
			:value buffer
			:configurable #f
			:writable #f
			:enumerable #t
			:hidden-class #t)
		     
		     ;; byteLength
		     (js-bind! %this this (& "byteLength")
			:value vlen
			:configurable #f
			:writable #f
			:enumerable #t
			:hidden-class #t)
		     
		     ;; byteOffset
		     (js-bind! %this this (& "byteOffset")
			:value (uint32->fixnum off)
			:configurable #f
			:writable #f
			:enumerable #t
			:hidden-class #t)
		     
		     ;; Int8
		     (js-bind! %this this (& "getInt8")
			:value (js-make-function %this js-getInt8
				  (js-function-arity js-getInt8)
				  (js-function-info :name "getInt8" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setInt8")
			:value (js-make-function %this js-setInt8
				  (js-function-arity js-setInt8)
				  (js-function-info :name "setInt8" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ;; Uint8
		     (js-bind! %this this (& "getUint8")
			:value (js-make-function %this js-getUint8
				  (js-function-arity js-getUint8)
				  (js-function-info :name "getUint8" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setUint8")
			:value (js-make-function %this js-setUint8
				  (js-function-arity js-setUint8)
				  (js-function-info :name "setUint8" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ;; Int16
		     (js-bind! %this this (& "getInt16")
			:value (js-make-function %this js-getInt16
				  (js-function-arity js-getInt16)
				  (js-function-info :name "getInt16" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setInt16")
			:value (js-make-function %this js-setInt16
				  (js-function-arity js-setInt16)
				  (js-function-info :name "setInt16" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ;; Uint16
		     (js-bind! %this this (& "getUint16")
			:value (js-make-function %this js-getUint16
				  (js-function-arity js-getUint16)
				  (js-function-info :name "getUint16" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setUint16")
			:value (js-make-function %this js-setInt16
				  (js-function-arity js-setInt16)
				  (js-function-info :name "setUint16" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ;; Int32
		     (js-bind! %this this (& "getInt32")
			:value (js-make-function %this js-getInt32
				  (js-function-arity js-getInt32)
				  (js-function-info :name "getInt32" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setInt32")
			:value (js-make-function %this js-setInt32
				  (js-function-arity js-setInt32)
				  (js-function-info :name "setInt32" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ;; Uint32
		     (js-bind! %this this (& "getUint32")
			:value (js-make-function %this js-getUint32
				  (js-function-arity js-getUint32)
				  (js-function-info :name "getUint32" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setUint32")
			:value (js-make-function %this js-setInt32
				  (js-function-arity js-setInt32)
				  (js-function-info :name "setUint32" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ;; BigInt64
		     (js-bind! %this this (& "getBigInt64")
			:value (js-make-function %this js-getBigInt64
				  (js-function-arity js-getBigInt64)
				  (js-function-info :name "getBigInt64" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setBigInt64")
			:value (js-make-function %this js-setBigInt64
				  (js-function-arity js-setBigInt64)
				  (js-function-info :name "setBigInt64" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ;; BigUint64
		     (js-bind! %this this (& "getBigUint64")
			:value (js-make-function %this js-getBigUint64
				  (js-function-arity js-getBigUint64)
				  (js-function-info :name "getBigUint64" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setBigUint64")
			:value (js-make-function %this js-setBigInt64
				  (js-function-arity js-setBigInt64)
				  (js-function-info :name "setBigUint64" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ;; Float32
		     (js-bind! %this this (& "getFloat32")
			:value (js-make-function %this js-getFloat32
				  (js-function-arity js-getFloat32)
				  (js-function-info :name "getFloat32" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setFloat32")
			:value (js-make-function %this js-setFloat32
				  (js-function-arity js-setFloat32)
				  (js-function-info :name "setFloat32" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ;; Float64
		     (js-bind! %this this (& "getFloat64")
			:value (js-make-function %this js-getFloat64
				  (js-function-arity js-getFloat64)
				  (js-function-info :name "getFloat64" :len 2))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     (js-bind! %this this (& "setFloat64")
			:value (js-make-function %this js-setFloat64
				  (js-function-arity js-setFloat64)
				  (js-function-info :name "setFloat64" :len 3))
			:configurable #t
			:writable #t
			:enumerable #t
			:hidden-class #t)
		     
		     ))
	       this))
	 
	 (define (js-dataview-construct this::JsDataView items)
	    (cond
	       ((null? items)
		(js-raise-error %this "Wrong number of argument" 0))
	       ((isa? (car items) JsArrayBuffer)
		(with-access::JsArrayBuffer (car items) (data)
		   (let ((len (u8vector-length data)))
		      (cond
			 ((or (null? (cdr items)) (not (integer? (cadr items))))
			  (js-create-from-arraybuffer this
			     (car items)
			     #u32:0 (fixnum->uint32 len)))
			 ((or (null? (cddr items))
			      (not (integer? (caddr items))))
			  (let ((off (->fixnum
					(js-tointeger (cadr items) %this))))
			     (cond
				((<fx off 0)
				 (js-raise-range-error %this
				    "Byte offset out of range ~a"
				    (cadr items)))
				(else
				 (js-create-from-arraybuffer this
				    (car items)
				    (fixnum->uint32 off)
				    (fixnum->uint32 (-fx len off)))))))
			 (else
			  (let ((off (->fixnum
					(js-tointeger (cadr items) %this)))
				(l (->fixnum
				      (js-tointeger (caddr items) %this))))
			     (cond
				((or (>fx (-fx l off) len) (<fx l 0))
				 (js-raise-range-error %this
				    "Length is out of range ~a"
				    l))
				((<fx off 0)
				 (js-raise-range-error %this
				    "Byte offset out of range ~a"
				    (cadr items)))
				(else
				 (js-create-from-arraybuffer this
				    (car items)
				    (fixnum->uint32 off)
				    (fixnum->uint32 l))))))))))
	       (else
		(js-raise-type-error %this
		   "Object must be an ArrayBuffer" (car items)))))
	 
	 (define (%js-dataview this . items)
	    (with-access::JsGlobalObject %this (js-new-target)
	       (if (eq? js-new-target (js-undefined))
		   (js-dataview-construct 
		      (js-dataview-alloc %this js-dataview)
		      items)
		   (begin
		      (set! js-new-target (js-undefined))
		      (js-dataview-construct this items)))))
	 
	 (define (js-dataview-alloc %this constructor::JsFunction)
	    (with-access::JsGlobalObject %this (js-new-target)
	       (set! js-new-target constructor))
	    (instantiateJsDataView
	       (mode (js-dataview-default-mode))
	       (cmap (js-not-a-cmap))
	       (__proto__ (js-get constructor (& "prototype") %this))))
	 
	 (define js-dataview
	    (js-make-function %this %js-dataview
	       (js-function-arity %js-dataview)
	       (js-function-info :name "DataView" :len 1)
	       :__proto__ (js-object-proto js-function)
	       :prototype js-dataview-prototype
	       :alloc js-dataview-alloc))

	 (define (js-dataview-get this::JsDataView offset lendian get)
	    (let ((off (uint32->fixnum (js-touint32 offset %this))))
	       (with-access::JsDataView this (buffer %data)
		  (let ((len (u8vector-length %data)))
		     (cond
			((<fx off 0)
			 (js-get this (js-toname offset %this) %this))
			((>=fx off len)
			 (js-undefined))
			(else
			 (get %data off lendian)))))))

	 (define (js-dataview-set this::JsDataView offset value lendian set)
	    (let ((off (uint32->fixnum (js-touint32 offset %this))))
	       (with-access::JsDataView this (buffer %data)
		  (let ((len (u8vector-length %data)))
		     (cond
			((<fx off 0)
			 (js-get this (js-toname offset %this) %this))
			((>=fx off len)
			 (js-undefined))
			(else
			 (set %data off (->fixnum (js-tointeger value %this))
			    lendian)))))))

	 (define (js-getInt8 this::JsDataView offset)
	    (js-dataview-get this offset #t
	       (lambda (vec off _)
		  (int8->fixnum (uint8->int8 (u8vector-ref vec off))))))
	 
	 (define (js-setInt8 this::JsDataView offset value)
	    (js-dataview-set this offset value #t
	       (lambda (vec off value _)
		  (u8vector-set! vec off (int8->uint8 (fixnum->int8 value))))))
	 
	 (define (js-getUint8 this::JsDataView offset)
	    (js-dataview-get this offset #t
	       (lambda (vec off _)
		  (uint8->fixnum (u8vector-ref vec off)))))
	 
	 (define (js-setUint8 this::JsDataView offset value)
	    (js-dataview-set this offset value #t
	       (lambda (vec off value _)
		  (u8vector-set! vec off (fixnum->uint8 value)))))

	 (define (js-get16 this::JsDataView offset lendian add)
	    (js-dataview-get this offset (js-totest lendian)
	       (lambda (vec off lendian)
		  (let ((b0 (u8vector-ref vec off))
			(b1 (u8vector-ref vec (+fx off 1))))
		     (if lendian (add b1 b0) (add b0 b1))))))
	 
	 (define (js-getInt16 this::JsDataView offset lendian)
	    (define (add b0 b1)
	       (+fx (bit-lsh (int8->fixnum (uint8->int8 b0)) 8)
		  (uint8->fixnum b1)))
	    (js-get16 this offset lendian add))
	  
	 (define (js-getUint16 this::JsDataView offset lendian)
	    (define (add b0 b1)
	       (+fx (bit-lsh (uint8->fixnum b0) 8) (uint8->fixnum b1)))
	    (js-get16 this offset lendian add))
	 
	 (define (js-setInt16 this::JsDataView offset value lendian)
	    (js-dataview-set this offset value (js-totest lendian)
	       (lambda (vec off value lendian)
		  (if (eq? host-lendian lendian)
		      ($s16/u8vector-set! vec off (fixnum->int16 value))
		      (let ((b0 (bit-and (bit-rsh value 8) #xff))
			    (b1 (bit-and value #xff)))
			 (if lendian
			     (begin
				(u8vector-set! vec off b1)
				(u8vector-set! vec (+fx off 1) b0))
			     (begin
				(u8vector-set! vec off b0)
				(u8vector-set! vec (+fx off 1) b1))))))))
	 
	 (define (js-get32 this::JsDataView offset lendian add)
	    (js-dataview-get this offset (js-totest lendian)
	       (lambda (vec off lendian)
		  (let ((b0 (u8vector-ref vec off))
			(b1 (u8vector-ref vec (+fx off 1)))
			(b2 (u8vector-ref vec (+fx off 2)))
			(b3 (u8vector-ref vec (+fx off 3))))
		     (if lendian (add b3 b2 b1 b0) (add b0 b1 b2 b3))))))
	 
	 (define (js-getInt32 this::JsDataView offset lendian)
	    (define (add b0 b1 b2 b3)
	       (+fx (bit-lsh (int8->fixnum (uint8->int8 b0)) 24)
		  (+fx (bit-lsh (uint8->fixnum b1) 16)
		     (+fx (bit-lsh (uint8->fixnum b2) 8)
			(uint8->fixnum b3)))))
	    (js-get32 this offset lendian add))

	 (define (js-getUint32 this::JsDataView offset lendian)
	    (define (add b0 b1 b2 b3)
	       (+fx (bit-lsh (uint8->fixnum b0) 24)
		  (+fx (bit-lsh (uint8->fixnum b1) 16)
		     (+fx (bit-lsh (uint8->fixnum b2) 8)
			(uint8->fixnum b3)))))
	    (js-get32 this offset lendian add))
	 
	 (define (js-setInt32 this::JsDataView offset value lendian)
	    (js-dataview-set this offset value (js-totest lendian)
	       (lambda (vec off value lendian)
		  (if (eq? host-lendian lendian)
		      ($s32/u8vector-set! vec off (fixnum->int32 value))
		      (let ((b0 (bit-and (bit-rsh value 24) #xff))
			    (b1 (bit-and (bit-rsh value 16) #xff))
			    (b2 (bit-and (bit-rsh value 8) #xff))
			    (b3 (bit-and value #xff)))
			 (if lendian
			     (begin
				(u8vector-set! vec off b3)
				(u8vector-set! vec (+fx off 1) b2)
				(u8vector-set! vec (+fx off 2) b1)
				(u8vector-set! vec (+fx off 3) b0))
			     (begin
				(u8vector-set! vec off b0)
				(u8vector-set! vec (+fx off 1) b1)
				(u8vector-set! vec (+fx off 2) b2)
				(u8vector-set! vec (+fx off 3) b3))))))))

	 (define (js-get64 this::JsDataView offset lendian add)
	    (js-dataview-get this offset (js-totest lendian)
	       (lambda (vec off lendian)
		  (let ((b0 (u8vector-ref vec off))
			(b1 (u8vector-ref vec (+fx off 1)))
			(b2 (u8vector-ref vec (+fx off 2)))
			(b3 (u8vector-ref vec (+fx off 3)))
			(b4 (u8vector-ref vec (+fx off 4)))
			(b5 (u8vector-ref vec (+fx off 5)))
			(b6 (u8vector-ref vec (+fx off 6)))
			(b7 (u8vector-ref vec (+fx off 7))))
		     (if lendian
			 (add b7 b6 b5 b4 b3 b2 b1 b0)
			 (add b0 b1 b2 b3 b4 b5 b6 b7))))))
	 
	 (define (js-getBigInt64 this::JsDataView offset lendian)

	    (define (uint8->int64 n)
	       (fixnum->int64 (uint8->fixnum n)))
	    
	    (define (add b0 b1 b2 b3 b4 b5 b6 b7)
	       (+s64 (bit-lshs64 (uint8->int64 b0) 54)
		  (+s64 (bit-lshs64 (uint8->int64 b1) 48)
		     (+s64 (bit-lshs64 (uint8->int64 b2) 40)
			(+s64 (bit-lshs64 (uint8->int64 b3) 32)
			   (+s64 (bit-lshs64 (uint8->int64 b4) 24)
			      (+s64 (bit-lshs64 (uint8->int64 b5) 16)
				 (+s64 (bit-lshs64 (uint8->int64 b6) 8)
				    (uint8->int64 b7)))))))))

	    (cond-expand
	       (bigloo4.4b
		(llong->bignum (int64->llong (js-get64 this offset lendian add))))
	       (else
		(int64->bignum (js-get64 this offset lendian add)))))

	 (define (js-getBigUint64 this::JsDataView offset lendian)
	    
	    (define (uint8->uint64 n)
	       (fixnum->uint64 (uint8->fixnum n)))
	    
	    (define (add b0 b1 b2 b3 b4 b5 b6 b7)
	       (+u64 (bit-lshu64 (uint8->uint64 b0) 54)
		  (+u64 (bit-lshu64 (uint8->uint64 b1) 48)
		     (+u64 (bit-lshu64 (uint8->uint64 b2) 40)
			(+u64 (bit-lshu64 (uint8->uint64 b3) 32)
			   (+u64 (bit-lshu64 (uint8->uint64 b4) 24)
			      (+u64 (bit-lshu64 (uint8->uint64 b5) 16)
				 (+u64 (bit-lshu64 (uint8->uint64 b6) 8)
				    (uint8->uint64 b7)))))))))
	    
	    (cond-expand
	       (bigloo4.4b
		(llong->bignum (uint64->llong (js-get64 this offset lendian add))))
	       (else
		(uint64->bignum (js-get64 this offset lendian add)))))

	 (define (js-setBigInt64 this::JsDataView offset value lendian)

	    (define (bit-rsh64 v shift)
	       (int64->fixnum (bit-rshs64 v shift)))
	    
	    (let ((off (uint32->fixnum (js-touint32 offset %this))))
	       (with-access::JsDataView this (buffer %data)
		  (let ((len (u8vector-length %data)))
		     (cond
			((<fx off 0)
			 (js-get this (js-toname offset %this) %this))
			((>=fx off len)
			 (js-undefined))
			((not (bignum? value))
			 (js-raise-type-error %this
			    "Not a BigInt ~a" value))
			(else
			 (let ((v64 (cond-expand
				       (bigloo4.4b
					(llong->int64 (bignum->llong value)))
				       (else
					(bignum->int64 value))))
			       (vec %data)
			       (lendian (js-totest lendian)))
			    (if (eq? host-lendian lendian)
				($s64/u8vector-set! vec off v64)
				(let ((b0 (bit-and (bit-rsh64 v64 54) #xff))
				      (b1 (bit-and (bit-rsh64 v64 48) #xff))
				      (b2 (bit-and (bit-rsh64 v64 40) #xff))
				      (b3 (bit-and (bit-rsh64 v64 32) #xff))
				      (b4 (bit-and (bit-rsh64 v64 24) #xff))
				      (b5 (bit-and (bit-rsh64 v64 16) #xff))
				      (b6 (bit-and (bit-rsh64 v64 8) #xff))
				      (b7 (int64->fixnum (bit-ands64 v64 #xff))))
				   (if lendian
				       (begin
					  (u8vector-set! vec off b7)
					  (u8vector-set! vec (+fx off 1) b6)
					  (u8vector-set! vec (+fx off 2) b5)
					  (u8vector-set! vec (+fx off 3) b4)
					  (u8vector-set! vec (+fx off 4) b3)
					  (u8vector-set! vec (+fx off 5) b2)
					  (u8vector-set! vec (+fx off 6) b1)
					  (u8vector-set! vec (+fx off 7) b0))
				       (begin
					  (u8vector-set! vec off b0)
					  (u8vector-set! vec (+fx off 1) b1)
					  (u8vector-set! vec (+fx off 2) b2)
					  (u8vector-set! vec (+fx off 3) b3)
					  (u8vector-set! vec (+fx off 4) b4)
					  (u8vector-set! vec (+fx off 5) b5)
					  (u8vector-set! vec (+fx off 6) b6)
					  (u8vector-set! vec (+fx off 7) b7))))))))))))

	 (define (js-getFloat32 this::JsDataView offset lendian)
	    (with-access::JsDataView this (buffer %data)
	       (let ((len (u8vector-length %data))
		     (lendian (js-totest lendian)))
		  (cond
		     ((<fx offset 0)
		      (js-get this (js-toname offset %this) %this))
		     ((>=fx offset len)
		      (js-undefined))
		     ((eq? host-lendian lendian)
		      ($f32/u8vector-ref %data (->fixnum offset)))
		     (else
		      (u8vector-set! buf 0 (u8vector-ref %data (+fx offset 3)))
		      (u8vector-set! buf 1 (u8vector-ref %data (+fx offset 2)))
		      (u8vector-set! buf 2 (u8vector-ref %data (+fx offset 1)))
		      (u8vector-set! buf 3 (u8vector-ref %data (+fx offset 0)))
		      ($f32/u8vector-ref buf 0))))))

	 (define (js-setFloat32 this::JsDataView offset value lendian)
	    (with-access::JsDataView this (buffer %data)
	       (let* ((len (u8vector-length %data))
		      (lendian (js-totest lendian))
		      (value (js-tonumber value %this))
		      (v (if (flonum? value) value (fixnum->flonum value))))
		  (cond
		     ((<fx offset 0)
		      (js-get this (js-toname offset %this) %this))
		     ((>=fx offset len)
		      (js-undefined))
		     ((eq? host-lendian lendian)
		      ($f32/u8vector-set! %data (->fixnum offset) v))
		     (else
		      ($f32/u8vector-set! buf 0 v)
		      (u8vector-set! %data offset (u8vector-ref buf 3))
		      (u8vector-set! %data (+fx offset 1) (u8vector-ref buf 2))
		      (u8vector-set! %data (+fx offset 2) (u8vector-ref buf 1))
		      (u8vector-set! %data (+fx offset 3) (u8vector-ref buf 0)))))))
		      
	 (define (js-getFloat64 this::JsDataView offset lendian)
	    (with-access::JsDataView this (buffer %data)
	       (let ((len (u8vector-length %data))
		     (lendian (js-totest lendian))
		     (offset (js-touint32 offset %this)))
		  (cond
		     ((not (js-isindex? offset))
		      (js-raise-range-error %this "getFloat64: Index out of range" offset))
		     ((>=u32 offset (fixnum->uint32 len))
		      (js-undefined))
		     ((eq? host-lendian lendian)
		      ($f64/u8vector-ref %data (uint32->fixnum offset)))
		     (else
		      (let ((offset (uint32->fixnum offset)))
			 (u8vector-set! buf 0 (u8vector-ref %data (+fx offset 7)))
			 (u8vector-set! buf 1 (u8vector-ref %data (+fx offset 6)))
			 (u8vector-set! buf 2 (u8vector-ref %data (+fx offset 5)))
			 (u8vector-set! buf 3 (u8vector-ref %data (+fx offset 4)))
			 (u8vector-set! buf 4 (u8vector-ref %data (+fx offset 3)))
			 (u8vector-set! buf 5 (u8vector-ref %data (+fx offset 2)))
			 (u8vector-set! buf 6 (u8vector-ref %data (+fx offset 1)))
			 (u8vector-set! buf 7 (u8vector-ref %data (+fx offset 0)))
			 ($f64/u8vector-ref buf 0)))))))

	 (define (js-setFloat64 this::JsDataView offset value lendian)
	    (with-access::JsDataView this (buffer %data)
	       (let ((len (u8vector-length %data))
		     (lendian (js-totest lendian))
		     (value (js-tonumber value %this))
		     (v (if (flonum? value) value (fixnum->flonum value)))
		     (offset (js-touint32 offset %this)))
		  (cond
		     ((not (js-isindex? offset))
		      (js-raise-range-error %this "setFloat64: Index out of range" offset))
		     ((>=u32 offset (fixnum->uint32 len))
		      (js-undefined))
		     ((eq? host-lendian lendian)
		      ($f64/u8vector-set! %data (uint32->fixnum offset) v))
		     (else
		      ($f64/u8vector-set! buf 0 v)
		      (let ((offset (uint32->fixnum offset)))
			 (u8vector-set! %data (+fx offset 0) (u8vector-ref buf 7))
			 (u8vector-set! %data (+fx offset 1) (u8vector-ref buf 6))
			 (u8vector-set! %data (+fx offset 2) (u8vector-ref buf 5))
			 (u8vector-set! %data (+fx offset 3) (u8vector-ref buf 4))
			 (u8vector-set! %data (+fx offset 4) (u8vector-ref buf 3))
			 (u8vector-set! %data (+fx offset 5) (u8vector-ref buf 2))
			 (u8vector-set! %data (+fx offset 6) (u8vector-ref buf 1))
			 (u8vector-set! %data (+fx offset 7) (u8vector-ref buf 0))))))))
	 
	 ;; bind the Dataview in the global object
	 (js-bind! %this %this (& "DataView")
	    :configurable #f :enumerable #f :value js-dataview
	    :hidden-class #t)

	 js-dataview)))
	 
;*---------------------------------------------------------------------*/
;*    js-for-of ::JsTypedArray ...                                     */
;*---------------------------------------------------------------------*/
(define-method (js-for-of o::JsTypedArray proc close %this)
   (with-access::JsGlobalObject %this (js-symbol-iterator)
      (let ((fun (js-get o js-symbol-iterator %this)))
	 (if (js-procedure? fun)
	     (js-for-of-iterator (js-call0 %this fun o) o proc close %this)
	     (with-access::JsTypedArray o (length %data)
		(let ((vref (js-typedarray-ref o)))
		   (let loop ((i #u32:0))
		      (when (<u32 i length)
			 (proc (vref %data (uint32->fixnum i)) %this)
			 (loop (+u32 i 1))))))))))

;*---------------------------------------------------------------------*/
;*    js-not-implemented ...                                           */
;*---------------------------------------------------------------------*/
(define (js-not-implemented id %this)
   (lambda (js-not-implemented this::obj)
      (js-raise-type-error %this (format "Not implemented (~a)" id) this)))

;*---------------------------------------------------------------------*/
;*    js-typedarray-slice ...                                          */
;*---------------------------------------------------------------------*/
(define (js-typedarray-slice this start end %this)
   
   (define (vector-slice/vec! o val k::long final::long vec::vector)
      (js-vector->jsarray vec %this))

   (define (vector-slice! o val::vector k::long final::long)
      (let* ((len (fixnum->uint32 (-fx final k)))
	     (arr (js-array-construct-alloc/lengthu32 %this len)))
	 (with-access::JsArray arr (vec ilen length)
	    (vector-copy! vec 0 val k final)
	    (set! ilen len)
	    (set! length len)
	    arr)))
   
   (define (u8vector-slice! o val::u8vector k::long final::long)
      (let ((vec (make-vector (-fx final k) (js-absent))))
	 (let loop ((i k)
		    (j 0))
	    (if (=fx i final)
		(vector-slice/vec! o val k final vec)
		(begin
		   (vector-set! vec j
		      (uint8->fixnum (u8vector-ref val i)))
		   (loop (+fx i 1) (+fx j 1)))))))
   
   (define (string-slice! o val::bstring k::long final::long)
      (let ((vec ($create-vector (-fx final k))))
	 (let loop ((i k)
		    (j 0))
	    (if (=fx i final)
		(vector-slice/vec! o val k final vec)
		(begin
		   (vector-set! vec j
		      (char->integer (string-ref-ur val i)))
		   (loop (+fx i 1) (+fx j 1)))))))
   
   (define (array-slice! o k::obj final::obj)
      (let ((arr (js-array-construct/length %this (js-array-alloc  %this)
		    (- final k))))
	 (array-copy! o 0 arr k final)))

   (define (array-copy! o len::long arr k::obj final::obj)
      (let loop ((i len))
	 (cond
	    ((= k final)
	     (js-put-length! arr i #f #f %this)
	     arr)
	    ((eq? (js-get-property o (js-toname k %this) %this) (js-undefined))
	     (set! k (+ 1 k))
	     (loop (+fx i 1)))
	    (else
	     (js-put! arr i (js-get o k %this) #f %this)
	     (set! k (+ 1 k))
	     (loop (+fx i 1))))))
   
    (let* ((len (js-uint32-tointeger (js-get-lengthu32 this %this)))
	   (relstart (js-tointeger start %this))
	   (k (if (< relstart 0) (max (+ len relstart) 0) (min relstart len)))
	   (relend (if (eq? end (js-undefined)) len (js-tointeger end %this)))
	   (final (if (< relend 0) (max (+ len relend) 0) (min relend len))))
       (with-access::JsTypedArray this (%data byteoffset)
	  (cond
	     ((string? %data)
	      (let* ((offset (uint32->fixnum byteoffset))
		     (start (+fx offset (->fixnum k)))
		     (end (+fx offset final))
		     (vlen (string-length %data)))
		 (cond
		    ((<= end vlen)
		     (string-slice! this %data start end))
		    ((>fx vlen 0)
		     (let* ((arr (string-slice! this %data start vlen))
			    (vlen (->fixnum (js-get-length arr %this))))
			(array-copy! this vlen arr (- len vlen) end)))
		    (else
		     (array-slice! this start end)))))
	     ((u8vector? %data)
	      (let* ((offset (uint32->fixnum byteoffset))
		     (start (+fx offset (->fixnum k)))
		     (end (+fx offset final))
		     (vlen (u8vector-length %data)))
		 (cond
		    ((<= end vlen)
		     (u8vector-slice! this %data start end))
		    ((>fx vlen 0)
		     (let* ((arr (u8vector-slice! this %data start vlen))
			    (vlen (->fixnum (js-get-length arr %this))))
			(array-copy! this vlen arr (- len vlen) end)))
		    (else
		     (array-slice! this start end)))))
	     (else
	      (array-slice! this k final))))))

;*---------------------------------------------------------------------*/
;*    &end!                                                            */
;*---------------------------------------------------------------------*/
(&end!)
