(def! not (lambda (x) (if x #f #t)))

(def! caar (lambda (x) (car (car x))))

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
      (if (= 1 (count xs)) (car xs) `(let* (or_FIXME ~(car xs)) (if or_FIXME or_FIXME (or ~@(cdr xs))))))))

(def! cadr (lambda (x) (car (cdr x))))
(def! cdar (lambda (x) (cdr (car x))))
(def! cddr (lambda (x) (cdr (cdr x))))
(def! caaar (lambda (x) (car (car (car x)))))
(def! caadr (lambda (x) (car (car (cdr x)))))
(def! cadar (lambda (x) (car (cdr (car x)))))
(def! caddr (lambda (x) (car (cdr (cdr x)))))
(def! cdaar (lambda (x) (cdr (car (car x)))))
(def! cdadr (lambda (x) (cdr (car (cdr x)))))
(def! cddar (lambda (x) (cdr (cdr (car x)))))
(def! cdddr (lambda (x) (cdr (cdr (cdr x)))))
