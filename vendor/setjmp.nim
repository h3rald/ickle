when not(defined(ETJMP_H)): 
  const 
    SETJMP_H* = 1
  #
  #   jmp_buf:
  # offset	size	description
  #  0	16	call-saved registers (r2-r17)
  # 16	 2	frame pointer (r29:r28)
  # 18	 2	stack pointer (SPH:SPL)
  # 20	 1	status register (SREG)
  # 21	 2/3	return address (PC) (2 bytes used for <=128Kw flash)
  # 23/24 = total size
  # 
  when not defined(DOXYGEN): 
    const 
      JBLEN* = 23
    #typedef struct _jmp_buf { unsigned char _jb[_JBLEN]; } jmp_buf[1];
  #* \file 
  #* \defgroup setjmp <setjmp.h>: Non-local goto
  #    While the C language has the dreaded \c goto statement, it can only be
  #    used to jump to a label in the same (local) function.  In order to jump
  #    directly to another (non-local) function, the C library provides the
  #    setjmp() and longjmp() functions.  setjmp() and longjmp() are useful for
  #    dealing with errors and interrupts encountered in a low-level subroutine
  #    of a program.
  #    \note setjmp() and longjmp() make programs hard to understand and maintain.
  #    If possible, an alternative should be used.
  #    \note longjmp() can destroy changes made to global register
  #    variables (see \ref faq_regbind).
  #    For a very detailed discussion of setjmp()/longjmp(), see Chapter 7 of
  #    <em>Advanced Programming in the UNIX Environment</em>, by W. Richard
  #    Stevens.
  #    Example:
  #    \code
  #    #include <setjmp.h>
  #    jmp_buf env;
  #    int main (void)
  #    {
  #        if (setjmp (env))
  #        {
  #            ... handle error ...
  #        }
  #        while (1)
  #        {
  #           ... main processing loop which calls foo() some where ...
  #        }
  #    }
  #    ...
  #    void foo (void)
  #    {
  #        ... blah, blah, blah ...
  #        if (err)
  #        {
  #            longjmp (env, 1);
  #        }
  #    }
  #    \endcode 
  when not(defined(ATTR_NORETURN)): 
    const 
      ATTR_NORETURN* = attribute((noreturn))
  #* \ingroup setjmp
  #    \brief Save stack context for non-local goto.
  #    \code #include <setjmp.h>\endcode
  #    setjmp() saves the stack context/environment in \e __jmpb for later use by
  #    longjmp().  The stack context will be invalidated if the function which
  #    called setjmp() returns.
  #    \param __jmpb Variable of type \c jmp_buf which holds the stack
  #    information such that the environment can be restored.
  #    \returns setjmp() returns 0 if returning directly, and
  #    non-zero when returning from longjmp() using the saved context. 
  proc setjmp*(jmpb: jmp_buf): cint
  #* \ingroup setjmp
  #    \brief Non-local jump to a saved stack context.
  #    \code #include <setjmp.h>\endcode
  #    longjmp() restores the environment saved by the last call of setjmp() with
  #    the corresponding \e __jmpb argument.  After longjmp() is completed,
  #    program execution continues as if the corresponding call of setjmp() had
  #    just returned the value \e __ret.
  #    \note longjmp() cannot cause 0 to be returned.  If longjmp() is invoked
  #    with a second argument of 0, 1 will be returned instead.
  #    \param __jmpb Information saved by a previous call to setjmp().
  #    \param __ret  Value to return to the caller of setjmp().
  #    \returns This function never returns. 
  #extern void longjmp(jmp_buf __jmpb, int __ret) __ATTR_NORETURN__;
