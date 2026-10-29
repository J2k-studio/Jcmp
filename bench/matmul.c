#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <arm_neon.h>
static double now(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec*1e3 + t.tv_nsec/1e6; }
int main(void){
    int n = 128;
    float *a = malloc(n*n*4), *b = malloc(n*n*4), *c = calloc(n*n,4);
    double *da = malloc(n*n*8), *db = malloc(n*n*8), *dc = malloc(n*n*8);
    for (int i=0;i<n*n;i++){ a[i]=(i%7)*0.25f; b[i]=(i%5)*0.5f; da[i]=a[i]; db[i]=b[i]; }
    double flops = 2.0*n*n*n, t0, t1;
    t0 = now();
    for (int i=0;i<n;i++) for (int j=0;j<n;j++){ double s=0; for (int k=0;k<n;k++) s += da[i*n+k]*db[k*n+j]; dc[i*n+j]=s; }
    t1 = now(); printf("C double scalar  %.3f ms  %.3f GFLOPS  check %.3f\n", t1-t0, flops/(t1-t0)/1e6, dc[n*n-1]);
    t0 = now();
    for (int i=0;i<n;i++) for (int j=0;j<n;j++){ float s=0; for (int k=0;k<n;k++) s += a[i*n+k]*b[k*n+j]; c[i*n+j]=s; }
    t1 = now(); printf("C float scalar   %.3f ms  %.3f GFLOPS  check %.3f\n", t1-t0, flops/(t1-t0)/1e6, c[n*n-1]);
    for (int i=0;i<n*n;i++) c[i]=0;
    t0 = now();
    for (int i=0;i<n;i++) for (int k=0;k<n;k++){ float32x4_t av = vdupq_n_f32(a[i*n+k]); for (int j=0;j<n;j+=4){ float32x4_t bv = vld1q_f32(b+k*n+j), cv = vld1q_f32(c+i*n+j); cv = vfmaq_f32(cv, av, bv); vst1q_f32(c+i*n+j, cv);} }
    t1 = now(); printf("C neon intrinsics %.3f ms  %.3f GFLOPS  check %.3f\n", t1-t0, flops/(t1-t0)/1e6, c[n*n-1]);
    return 0;
}
