(def! assert (fn* (a b)
  (if (= a b) 'SUCCESS 'FAILURE)))
