/* Simple program to drop disk caches in linux */

#include <stdio.h>

int main()
{
    FILE* f = fopen("/proc/sys/vm/drop_caches", "w");
    if (!f) {
        perror("Cannot open /proc/sys/vm/drop_caches");
        return -1;
    }
    fprintf(f, "3\n");
    fclose(f);

    return 0;
}
