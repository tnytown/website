+++
title = "syscalling for fun and (no) profit"
date = 2021-02-28
[taxonomies]
tags = ["systems", "linux", "fish"]
+++

I recently had a (self-inflicted) problem in my [Operating Systems course](https://www-users.cs.umn.edu/~kauffman/4061/). To expose us to the wonders of programming in a Unix environment, we were tasked with building a rudimentary "shell". To make the assignment more interesting to my partner and I, we decided to avoid `libc` and use Linux system calls directly [^1].

<!-- more -->

### wait, what?

What does this even entail? On x86-64 Linux, the only platform this assignment needs to run on, it's easier than one would expect. Syscalls are distinguished by unique their *number* and the *arguments* they take. Linux syscalls are ABI-stable, which means that the behavior of any one syscall number is guaranteed to never change [^2]. To invoke a syscall, one needs to: 

1. store the desired syscall *number* in `rax`
2. pass a maximum of 6 *arguments* in registers  `rdi`, `rsi`, `rdx`, `r10`, `r8`, and `r9` 
3. use the `syscall` instruction.

Notice something familiar in step 2? That's the [System V x86-64 calling convention](https://wiki.osdev.org/System_V_ABI#Calling_Convention)! We pass arguments into syscalls the same way that we pass arguments into normal function calls. The only difference is that instead of calling the function via the `call` instruction, we have to denote the syscall number via `rax` and invoke the syscall with the `syscall` instruction.

## zero-cost abstractions

Manually writing out all the `syscall` invocations for the syscalls that we needed to use felt a bit tedious. Instead, I decided to write a few functions abstracting over the required inline assembly, with which I generated syscall wrappers.

### a false start

If you can play it slowly, you can play it quickly. I started small by implementing only one wrapper for a syscall with one argument. This was my initial attempt.

```c
int64_t syscall1(no, a1)
  register int64_t no asm("rax");
  register int64_t a1 asm("rdi");
{
  asm volatile("syscall" : "+r"(no) : "r"(a1) : "rcx", "r11", "memory");
  return no;
}
```

Through previous projects, I learnt about [some GCC-specific trickery that allows us to control register allocation](https://gcc.gnu.org/onlinedocs/gcc/Local-Register-Variables.html#Local-Register-Variables). However, I wasn't able to declare function arguments as such.

```c
static inline int64_t syscall1(register int64_t no asm("rax"), register int64_t a1 asm("rdx"))
```

The above is apparently NOT syntactically valid. To hack around that, I used [K&R style function declarations](https://en.wikipedia.org/wiki/C_(programming_language)#K&R_C). This compiles, but the `no` and `a1` arguments were not assigned to the registers I wanted them to be in.

{{ imgcap(src='Untitled.png' alt='screenshot of incorrect disassembly' cap='WTF?') }}

Looking back, this result was not a surprise. Being able to control register allocation for function arguments blatantly breaks calling convention and would make things impossible to link. Besides, K&R function declaration syntax is incredibly cursed, not to mention deprecated. The question remains: how should we write these wrappers?

### the kosher way

Trying to be cool and using *exotic compiler features* netted me a great deal of pain, so I just decided to do it "normally".

```c
int64_t syscall1(int64_t a1, int64_t no) {
  asm volatile("movq %0, %%rax\n\t"
               "syscall"
               : "+g"(no) // r/w: syscall number
               : "r"(a1)
               : "rcx", "r11", "memory");
  return no;
}
```

I decided to exploit the inherent similarity between the system call ABI and normal System V function calls. To ensure that the arguments are passed in the correct order, I moved the syscall number `no` argument to the end. In the event that there are more than 6 arguments in the wrapper [^3], the `no` argument overflows into memory. We `mov` the syscall number into `eax` where the kernel expects it, and likewise modify the register constraint for `no` to `+g` to reflect the possibility of it not being a register.

![screenshot of correct disassembly](Untitled%201.png)

As you can see, this one seemed to generate valid code. I then wrote `syscall2` through `syscall6` with the same pattern, then got to work on generating the real syscall wrappers.

## generating the syscall wrappers

Believe it or not, there is no central location which contains definitions for all the syscalls. Canonically, it is libc's responsibility to provide those wrappers. Their prototypes are split up across various arbitrarily named header files, with arguments and constants for those further split up into other header files. The best place to find prototypes and headers lies within the manpages, specifically section 2. Our task now is to parse those manpages and turn them into syscall definitions utilizing our assembly wrappers.

### into the belly of the beast

The Linux manpages are generated with `groff`, an archaic typesetter. Optimally, we want to "parse" the original `groff` markup to get the data we need. Fortunately, `man` provides a mechanism to get the path of the markup files from which it displays its output: the `-w` flag [^4]. Since this provides the path to gzipped markup, I had to `zcat` it to get the text. This yielded the following for `read(2)`:

```
<snip>
.TH READ 2 2018-02-02 "Linux" "Linux Programmer's Manual"
.SH NAME
read \- read from a file descriptor
.SH SYNOPSIS
.nf
.B #include <unistd.h>
.PP
.BI "ssize_t read(int " fd ", void *" buf ", size_t " count );
.fi
.SH DESCRIPTION
.BR read ()
attempts to read up to
.I count
bytes from file descriptor
.I fd
into the buffer starting at
.IR buf .
.PP
<snip>
```

While archaic and not as nice when compared to asciidoc, this is workable with some judicious `sed` and my hammer of choice, fish shell.

### `sed` to the rescue

`groff` seems to have some semblance of structure in the form of sections. We can pinpoint and preprocess specific sections to work on with this `sed` snippet.

```
/^\.SH SYNOPSIS/,/^\.SH.*/ {
/^\.SH/D             # delete section headers
s/"|;//g             # delete quotation marks, semis
s/^\.[A-Za-z]+ *//g  # delete preceding directives
s/\/\*.+\*\///g      # delete C89 comments
p                    # print
}
```

The function prototypes and `#include` directives usually reside in the synopsis section, so we match for that with `/^\.SH SYNOPSIS/,/^\.SH.*/`. This matches ranges of lines beginning with a `.SH SYNOPSIS` and ending with any arbitrary `.SH` command, which denotes the next header. We specify multiple commands in the body of the sed match to clean up `groff` markup cruft, leaving only the `#include` and prototype.

```
#include <unistd.h>

ssize_t read(int  fd , void * buf , size_t  count )
```

Now that we have the prototype, the next issue is generating the call to the `syscall` wrapper. The only real challenge here is extricating the variable names from their types. This is achievable with some `grep`.

```bash
$ echo 'ssize_t read(int  fd , void * buf , size_t  count )' | grep -oE '[0-9a-zA-Z_]+ *(,|\))'
fd ,
buf ,
count )
```

We still have some spurious tokens in there, but a quick pipe to `tr -d ',)'`  solves that problem. 

One more additional thing of interest is how we get the syscall number. Those are all defined in `sys/syscall.h` as macros, but where that file is located is entirely system-dependent. Luckily, we can make `gcc` do the work for us. The `-E -dM` flags, as [this StackOverflow answer](https://stackoverflow.com/a/2224357) helpfully points out, dumps a list of all the preprocessor macros that are defined. We can then use `sed`  with a capture group to grab the number.

```bash
$ echo '#include <sys/syscall.h>' | gcc -E -dM -x c - | sed -En "s/#define __NR_read +([0-9]+)/\1/p"
0
```

With the argument names and syscall number we can munge together a call to the appropriate `syscall` wrapper in our function declaration (which we derive from the prototype). We can then generate a halfway sane header file [^5]:

```c
// This file was generated by mklibsysc.
#ifndef LIBSYSC_H_
#define LIBSYSC_H_

#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>

// <snip: syscall0 ... syscall6>
//$syscalls=read,write,dup,dup2,exit_group

#define read libsysc_read
 __attribute__((noinline)) ssize_t libsysc_read(int  fd , void * buf , size_t  count ) { return syscall3 ( fd , buf , count , 0 ); }
#define write libsysc_write
 __attribute__((noinline)) ssize_t libsysc_write(int  fd , const void * buf , size_t  count ) { return syscall3 ( fd , buf , count , 1 ); }
#define dup libsysc_dup
 __attribute__((noinline)) int libsysc_dup(int  oldfd ) { return syscall1 ( oldfd , 32 ); }
#define dup2 libsysc_dup2
 __attribute__((noinline)) int libsysc_dup2(int  oldfd , int  newfd ) { return syscall2 ( oldfd , newfd , 33 ); }
#define exit_group libsysc_exit_group
 __attribute__((noinline)) void libsysc_exit_group(int  status ) { syscall1 ( status , 231 ); }
#endif // LIBSYSC_H_
```

This looks a bit ugly, but `clang-format` can fix it. Regardless, not bad for a shell script and some regex.

## trying it out

Now that we have all these syscall wrappers, it's time to write a program to test a few of them.

```c
#include "libsysc.h"

asm(".global _start\n\t"
    "_start:\n\t"
    "mov (%rsp), %edi\n\t"
    "leaq 8(%rsp), %rsi\n\t"
    "call main\n\t"
    "mov $0, %edi\n\t"
    "call libsysc_exit_group\n\t"
    "syscall");

int main(int argc, char *argv[]) {
  char buf[4];
  if (argc > 0)           // lol
    write(1, argv[0], 7); // ./a.out

  write(1, "\nName: ", 7);
  read(0, buf, 4);
  write(1, "hello ", 6);
  write(1, buf, 4);
  write(1, "!\n", 2);
}
```

That `asm` block at the beginning is some initialization code I stole [from StackOverflow](https://stackoverflow.com/a/16722942) to replace the stdlib's built-in `_start` function that calls main. Roughly speaking, `argc` and `argv` is handed to the program on the stack, which we have to cram into the registers that `main` expects them in.

Now it's time to compile and run.

```c
$ gcc -nostdlib -fno-stack-protector x.c 2>/dev/null && echo 'andrew' | ./a.out
./a.out
Name: hello andr!
```

🙂

### future work

I've learnt that programming without the standard library is painful [^6]. Later in the semester, we will build our own minimal vaguely POSIX-compliant libc atop of our syscall wrappers. Watch this space!

[^1]: ... which was the plan, until I didn't finish the syscall layer in time.

[^2]: On Linux anyways.

[^3]: `syscall6`, the wrapper for syscalls with 6 arguments, has 7 arguments in total due to the `no` argument.

[^4]: You can read all about it by running `man man`.

[^5]: `mklibsysc` only generates wrappers for syscalls specified in the input, which is why there are only 5 in the list.

[^7]: To be honest though, it's not that big of a downgrade when compared to libc.
