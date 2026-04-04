// Disable Cripple-AMD CPU dispatcher in Intel Math Kernel Library
// https://en.wikipedia.org/wiki/Math_Kernel_Library#Performance
// compile with `gcc -shared -fPIC -o bogusintel.so bogusintel.c`
// LD_PRELOAD=bogusintel.so yourprogram

int mkl_serv_intel_cpu_true() {
	return 1;
}

typedef int (*fakeintel_fptr)(void);

fakeintel_fptr mkl_serv_get_cpu_true() {
	return &mkl_serv_intel_cpu_true;
}
