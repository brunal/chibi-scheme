
(define (char-alphabetic? ch) (char-set-contains? char-set:letter ch))
(define (char-lower-case? ch) (char-set-contains? char-set:lower-case ch))
(define (char-upper-case? ch) (char-set-contains? char-set:upper-case ch))
(define (char-numeric? ch) (char-set-contains? char-set:digit ch))
(define (char-whitespace? ch) (char-set-contains? char-set:whitespace ch))

(define (bsearch-kv vec n lo hi)
  (and (<= lo hi)
       (let* ((mid (+ lo (* (quotient (- hi lo) 4) 2)))
              (m (vector-ref vec mid)))
         (cond
          ((= n m)
           (integer->char (vector-ref vec (+ mid 1))))
          ((< n m)
           (bsearch-kv vec n lo (- mid 2)))
          (else
           (bsearch-kv vec n (+ mid 2) hi))))))

(define (char-downcase ch)
  (let ((n (char->integer ch)))
    (let lp ((ls char-downcase-offsets))
      (cond
       ((null? ls)
        (or (bsearch-kv char-downcase-map n 0
                        (- (vector-length char-downcase-map) 2))
            ch))
       ((iset-contains? (caar ls) n)
        (integer->char (+ n (cdar ls))))
       (else (lp (cdr ls)))))))

(define (char-upcase ch)
  (let ((n (char->integer ch)))
    (let lp ((ls char-downcase-offsets))
      (cond
       ((null? ls)
        (or (bsearch-kv char-upcase-map n 0
                        (- (vector-length char-upcase-map) 2))
            ch))
       ((iset-contains? (caar ls) (- n (cdar ls)))
        (integer->char (- n (cdar ls))))
       (else (lp (cdr ls)))))))

(define (char-foldcase ch)
  (or (bsearch-kv char-foldcase-map (char->integer ch) 0
                  (- (vector-length char-foldcase-map) 2))
      ch))

(define (char-cmp-ci op a ls)
  (let lp ((op op) (a (char->integer (char-foldcase a))) (ls ls))
    (if (null? ls)
        #t
        (let ((b (char->integer (char-downcase (car ls)))))
          (and (op a b) (lp op b (cdr ls)))))))

(define (char-ci=? a . ls) (char-cmp-ci = a ls))
(define (char-ci<? a . ls) (char-cmp-ci < a ls))
(define (char-ci>? a . ls) (char-cmp-ci > a ls))
(define (char-ci<=? a . ls) (char-cmp-ci <= a ls))
(define (char-ci>=? a . ls) (char-cmp-ci >= a ls))

(define (char-get-special-case ch off)
  (let ((i (char->integer ch)))
    (let lp ((a 0) (b (vector-length special-cases)))
      (let* ((mid (+ a (quotient (- b a) 2)))
             (vec (vector-ref special-cases mid))
             (val (vector-ref vec 0)))
        (cond ((< i val) (and (< mid b) (lp a mid)))
              ((> i val) (and (> mid a) (lp mid b)))
              (else
               (vector-ref vec (if (>= off (vector-length vec)) 1 off))))))))

(define (call-with-output-string proc)
  (let ((out (open-output-string)))
    (proc out)
    (get-output-string out)))

(define (string-down-or-fold-case str fold?)
  (call-with-output-string
    (lambda (out)
      (let ((in (open-input-string str)))
        (let lp ()
          (let ((ch (read-char in)))
            (cond
             ((not (eof-object? ch))
              (cond
               ((and (not fold?) (eqv? ch #\x03A3)) ;; sigma
                (let ((ch2 (peek-char in)))
                  (write-char
                   (if (or (eof-object? ch2)
                           (not (char-set-contains? char-set:letter ch2)))
                       #\x03C2
                       #\x03C3)
                   out)))
               ((char-get-special-case ch (if fold? 4 1))
                => (lambda (s) (write-string s out)))
               (else
                (write-char (if fold? (char-foldcase ch) (char-downcase ch))
                            out)))
              (lp)))))))))

(define (string-downcase str) (string-down-or-fold-case str #f))
(define (string-foldcase str) (string-down-or-fold-case str #t))

(define (string-upcase str)
  (call-with-output-string
    (lambda (out)
      (string-for-each
       (lambda (ch)
         (write-string (if (memv ch '(#\x03C2 #\x03C3))
                           #\x03A3
                           (or (char-get-special-case ch 3)
                               (char-upcase ch)))
                       out))
       str))))

(define (string-cmp-ci op a ls)
  (let lp ((op op) (a (string-foldcase a)) (ls ls))
    (if (null? ls)
        #t
        (let ((b (string-foldcase (car ls))))
          (and (op a b) (lp op b (cdr ls)))))))

(define (string-ci=? a . ls) (string-cmp-ci string=? a ls))
(define (string-ci<? a . ls) (string-cmp-ci string<? a ls))
(define (string-ci>? a . ls) (string-cmp-ci string>? a ls))
(define (string-ci<=? a . ls) (string-cmp-ci string<=? a ls))
(define (string-ci>=? a . ls) (string-cmp-ci string>=? a ls))
