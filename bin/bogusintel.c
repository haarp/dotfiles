// Disable Cripple-AMD CPU dispatcher in Intel Math Kernel Library
// https://en.wikipedia.org/wiki/Math_Kernel_Library#Performance
// compile with `gcc -shared -o bogusintel.so bogusintel.c`
// LD_PRELOAD=bogusintel.so yourprogram

int mkl_serv_intel_cpu_true() {
	return 1;
}
