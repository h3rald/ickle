(define not (lambda (x) (if x #f #t)))

(defmacro! cond
  (lambda (& xs)
    (if (> (count xs) 0)
      (list 'if (car xs)
        (if (> (count xs) 1) (nth xs 1)
    (throw "odd number of forms to cond"))
      (cons 'cond (cdr (cdr xs)))))))

(defmacro! or
  (lambda (& xs)
    (if (empty? xs) nil
      (if (equal? 1 (count xs)) (car xs) `(let* (or_FIXME ~(car xs)) (if or_FIXME or_FIXME (or ~@(cdr xs))))))))

(define caar (lambda (x) (car (car x))))
(define cadr (lambda (x) (car (cdr x))))
(define cdar (lambda (x) (cdr (car x))))
(define cddr (lambda (x) (cdr (cdr x))))

(define caaar (lambda (x) (car (car (car x)))))
(define caadr (lambda (x) (car (car (cdr x)))))
(define cadar (lambda (x) (car (cdr (car x)))))
(define caddr (lambda (x) (car (cdr (cdr x)))))
(define cdaar (lambda (x) (cdr (car (car x)))))
(define cdadr (lambda (x) (cdr (car (cdr x)))))
(define cddar (lambda (x) (cdr (cdr (car x)))))
(define cdddr (lambda (x) (cdr (cdr (cdr x)))))


(define caaaar (lambda (x) (car (car (car (car x))))))
(define cdaaar (lambda (x) (cdr (car (car (car x))))))
(define cadaar (lambda (x) (car (cdr (car (car x))))))
(define cddaar (lambda (x) (cdr (cdr (car (car x))))))
(define caadar (lambda (x) (car (car (cdr (car x))))))
(define cdadar (lambda (x) (cdr (car (cdr (car x))))))
(define caddar (lambda (x) (car (cdr (cdr (car x))))))
(define cdddar (lambda (x) (cdr (cdr (cdr (car x))))))
(define caaadr (lambda (x) (car (car (car (cdr x))))))
(define cdaadr (lambda (x) (cdr (car (car (cdr x))))))
(define cadadr (lambda (x) (car (cdr (car (cdr x))))))
(define cddadr (lambda (x) (cdr (cdr (car (cdr x))))))
(define caaddr (lambda (x) (car (car (cdr (cdr x))))))
(define cdaddr (lambda (x) (cdr (car (cdr (cdr x))))))
(define cadddr (lambda (x) (car (cdr (cdr (cdr x))))))
(define cddddr (lambda (x) (cdr (cdr (cdr (cdr x))))))
