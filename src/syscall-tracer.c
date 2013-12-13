/* XXX this only works on x86_64 linux at the moment, but it shouldn't be too
 * much work to port it to other platforms - patches welcome! */
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ptrace.h>
#include <sys/syscall.h>
#include <sys/user.h>

int main(int argc, char *argv[])
{
    pid_t pid;

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <pid>\n", argv[0]);
        exit(1);
    }

    pid = (pid_t)atol(argv[1]);

    if (ptrace(PTRACE_ATTACH, pid, NULL, NULL)) {
        perror("attach");
        exit(1);
    }
    waitpid(pid, NULL, 0);
    if (ptrace(PTRACE_SETOPTIONS, pid, NULL, (void *)PTRACE_O_TRACESYSGOOD)) {
        perror("setoptions");
        exit(1);
    }
    for (;;) {
        intptr_t sig = 0;
        int waitstat;
        struct user_regs_struct regs;

        while (sig != (SIGTRAP | 0x80)) {
            if (ptrace(PTRACE_SYSCALL, pid, NULL, (void *)sig)) {
                perror("syscall entry");
                exit(1);
            }
            waitpid(pid, &waitstat, 0);
            sig = WSTOPSIG(waitstat);
        }

        if (ptrace(PTRACE_GETREGS, pid, NULL, (void *)&regs)) {
            perror("getregs");
            exit(1);
        }
        if (regs.orig_rax == SYS_read) {
            puts(".");
            fflush(stdout);
        }

        sig = 0;
        while (sig != (SIGTRAP | 0x80)) {
            if (ptrace(PTRACE_SYSCALL, pid, NULL, (void *)sig)) {
                perror("syscall exit");
                exit(1);
            }
            waitpid(pid, NULL, 0);
            sig = WSTOPSIG(waitstat);
        }
    }
}
