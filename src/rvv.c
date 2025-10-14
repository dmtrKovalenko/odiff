#include <stdint.h>
#include <stddef.h>

#if !__riscv_vector

/* unused stubs */
uint32_t odiffRVV(uint32_t *src1, uint32_t *src2, size_t n, float max_delta, uint32_t *diff, uint32_t diffcol) { return 0; }
double calculatePixelColorDeltaRVVForTest(uint32_t pixel_a, uint32_t pixel_b) { return 0; }

#else

/* See also: "Measuring perceived color difference using YIQ NTSC
 *            transmission color space in mobile applications" */
#define YIQ_Y_R_COEFF 0.29889531
#define YIQ_Y_G_COEFF 0.58662247
#define YIQ_Y_B_COEFF 0.11448223

#define YIQ_I_R_COEFF 0.59597799
#define YIQ_I_G_COEFF -0.27417610
#define YIQ_I_B_COEFF -0.32180189

#define YIQ_Q_R_COEFF 0.21147017
#define YIQ_Q_G_COEFF -0.52261711
#define YIQ_Q_B_COEFF 0.31114694

#define YIQ_Y_WEIGHT 0.5053
#define YIQ_I_WEIGHT 0.299
#define YIQ_Q_WEIGHT 0.1957

#if 0
/* simplifying the original equation  */
y = rgb2y(a) - rgb2y(b) = rgb2y(a - b);
i = rgb2i(a) - rgb2i(b) = rgb2i(a - b);
q = rgb2q(a) - rgb2q(b) = rgb2q(a - b);
return (YIQ_Y_WEIGHT * y * y) + (YIQ_I_WEIGHT * i * i) + (YIQ_Q_WEIGHT * q * q);

[r,g,b] = a-b;
y = ((r * YIQ_Y_R_COEFF) + (g * YIQ_Y_G_COEFF) + (b * YIQ_Y_B_COEFF)) * YIQ_Y_WEIGHT_SQRT;
i = ((r * YIQ_I_R_COEFF) + (g * YIQ_I_G_COEFF) + (b * YIQ_I_B_COEFF)) * YIQ_I_WEIGHT_SQRT;
q = ((r * YIQ_Q_R_COEFF) + (g * YIQ_Q_G_COEFF) + (b * YIQ_Q_B_COEFF)) * YIQ_Q_WEIGHT_SQRT;
return y*y + i*i + q*q;

return (r*C1 + g*C2 + b*C3)**2
      +(r*C4 + g*C5 + b*C6)**2
      +(r*C7 + g*C8 + b*C9)**2;

return r*C1*(r*C1 + g*2*C2 + b*2*C3) + (g*C2)**2 + b*C3*(g*2*C2 + b*C3)
     + r*C4*(r*C4 + g*2*C5 + b*2*C6) + (g*C5)**2 + b*C6*(g*2*C5 + b*C6)
     + r*C7*(r*C7 + g*2*C8 + b*2*C9) + (g*C8)**2 + b*C9*(g*2*C8 + b*C9);

return r*r*C1*C1 + r*g*2*C2*C1 + r*b*2*C3*C1 + (g*C2)**2 + b*g*2*C2*C3 + b*b*C3*C3
     + r*r*C4*C4 + r*g*2*C5*C4 + r*b*2*C6*C4 + (g*C5)**2 + b*g*2*C5*C6 + b*b*C6*C6
     + r*r*C7*C7 + r*g*2*C8*C7 + r*b*2*C9*C7 + (g*C8)**2 + b*g*2*C8*C9 + b*b*C9*C9;

return r*r * (C1*C1+C4*C4+C7*C7)
     + r*g*2*(C2*C1+C5*C4+C8*C7)
     + r*b*2*(C3*C1+C6*C4+C9*C7)
     + g*g * (C2*C2+C5*C5+C8*C8)
     + b*g*2*(C2*C3+C5*C6+C8*C9)
     + b*b * (C3*C3+C6*C6+C9*C9);

// 24 -> 18 -> 15 -> 12 instructions
return r*(r*Y1 + g*Y2 + b*Y3) + g*(g*Y4 + b*Y5) + b*b*Y6;
#endif

#define YIQ_Y_WEIGHT_SQRT 0.7108445681019163
#define YIQ_I_WEIGHT_SQRT 0.5468089245796927
#define YIQ_Q_WEIGHT_SQRT 0.4423799272118933

#define C1 (YIQ_Y_R_COEFF*YIQ_Y_WEIGHT_SQRT)
#define C2 (YIQ_Y_G_COEFF*YIQ_Y_WEIGHT_SQRT)
#define C3 (YIQ_Y_B_COEFF*YIQ_Y_WEIGHT_SQRT)
#define C4 (YIQ_I_R_COEFF*YIQ_I_WEIGHT_SQRT)
#define C5 (YIQ_I_G_COEFF*YIQ_I_WEIGHT_SQRT)
#define C6 (YIQ_I_B_COEFF*YIQ_I_WEIGHT_SQRT)
#define C7 (YIQ_Q_R_COEFF*YIQ_Q_WEIGHT_SQRT)
#define C8 (YIQ_Q_G_COEFF*YIQ_Q_WEIGHT_SQRT)
#define C9 (YIQ_Q_B_COEFF*YIQ_Q_WEIGHT_SQRT)

#define Y1 (  (C1*C1+C4*C4+C7*C7)) /*  0.160096 */
#define Y2 (2*(C2*C1+C5*C4+C8*C7)) /*  0.036226 */
#define Y3 (2*(C3*C1+C6*C4+C9*C7)) /* -0.054354 */
#define Y4 (  (C2*C2+C5*C5+C8*C8)) /*  0.249815 */
#define Y5 (2*(C2*C3+C5*C6+C8*C9)) /*  0.056986 */
#define Y6 (  (C3*C3+C6*C6+C9*C9)) /*  0.056532 */

#include <riscv_vector.h>

static inline vfloat32m4_t
rvv_yiq_diff(vuint8m1x4_t v4, vuint8m1x4_t y4, size_t vl)
{
	vfloat32m4_t vr = __riscv_vfwcvt_f(__riscv_vzext_vf2(__riscv_vget_u8m1(v4, 0), vl), vl);
	vfloat32m4_t vg = __riscv_vfwcvt_f(__riscv_vzext_vf2(__riscv_vget_u8m1(v4, 1), vl), vl);
	vfloat32m4_t vb = __riscv_vfwcvt_f(__riscv_vzext_vf2(__riscv_vget_u8m1(v4, 2), vl), vl);
	vfloat32m4_t va = __riscv_vfwcvt_f(__riscv_vzext_vf2(__riscv_vget_u8m1(v4, 3), vl), vl);
	vfloat32m4_t yr = __riscv_vfwcvt_f(__riscv_vzext_vf2(__riscv_vget_u8m1(y4, 0), vl), vl);
	vfloat32m4_t yg = __riscv_vfwcvt_f(__riscv_vzext_vf2(__riscv_vget_u8m1(y4, 1), vl), vl);
	vfloat32m4_t yb = __riscv_vfwcvt_f(__riscv_vzext_vf2(__riscv_vget_u8m1(y4, 2), vl), vl);
	vfloat32m4_t ya = __riscv_vfwcvt_f(__riscv_vzext_vf2(__riscv_vget_u8m1(y4, 3), vl), vl);
	vfloat32m4_t vy, dr, dg, db, v;

	/* ((v-255)*(va/255)+255) - ((y-255)*(ya/255)+255)
		* = (v-255)*(va/255)+255  -  (y-255)*(ya/255)-255
		* = (v-255)*(va/255)      -  (y-255)*(ya/255)
		* = (v-255)*(va/255)      -  (y-255)*(ya/255)
		* = (v*va/255-255*va/255) -  (y*ya/255-255*ya/255)
		* = (v*va/255-    va    ) -  (y*ya/255-    ya    )
		* =  v*va/255-    va      -   y*ya/255+    ya
		* =  v*va/255-  y*ya/255  -     va    +    ya
		* =  v*va/255- (y*ya/255  +    (va    -    ya)) */
	vy = __riscv_vfsub(va, ya, vl);
	va = __riscv_vfmul(va, 1/255.0f, vl);
	ya = __riscv_vfmul(ya, 1/255.0f, vl);
	dr = __riscv_vfmsub(vr, va, __riscv_vfmadd(yr, ya, vy, vl), vl);
	dg = __riscv_vfmsub(vg, va, __riscv_vfmadd(yg, ya, vy, vl), vl);
	db = __riscv_vfmsub(vb, va, __riscv_vfmadd(yb, ya, vy, vl), vl);

	/* r*(r*Y1 + g*Y2 + b*Y3) + g*(g*Y4 + b*Y5) + b*b*Y6 (see top of file) */
	v = __riscv_vfmul(__riscv_vfmul(db, Y6, vl), db, vl);
	v = __riscv_vfmacc(v, dg, __riscv_vfmacc(__riscv_vfmul(dg, Y4, vl), Y5, db, vl), vl);
	v = __riscv_vfmacc(v, dr, __riscv_vfmacc(__riscv_vfmacc(__riscv_vfmul(dr, Y1, vl), Y2, dg, vl), Y3, db, vl), vl);
	return v;
}

uint32_t
odiffRVV(uint32_t *src1, uint32_t *src2, size_t n, float max_delta, uint32_t *diff, uint32_t diffcol)
{
	size_t count = 0;
	for (size_t i = 0, vl; n > 0; n -= vl, i += vl) {
		vl = __riscv_vsetvl_e32m2(n);
		vuint32m2_t v1 = __riscv_vle32_v_u32m2(src1+i, vl);
		vuint32m2_t v2 = __riscv_vle32_v_u32m2(src2+i, vl);
		long idx = __riscv_vfirst(__riscv_vmsne(v1, v2, vl), vl);
		if (idx < 0) continue;
		n -= idx;
		i += idx;

		vl = __riscv_vsetvl_e8m1(n);
		vuint8m1x4_t v4 = __riscv_vlseg4e8_v_u8m1x4((uint8_t*)(src1+i), vl);
		vuint8m1x4_t y4 = __riscv_vlseg4e8_v_u8m1x4((uint8_t*)(src2+i), vl);

		vbool8_t m = __riscv_vmfgt(rvv_yiq_diff(v4, y4, vl), max_delta, vl);
		count += __riscv_vcpop(m, vl);

		if (diff) {
			__riscv_vse32(m, diff+i, __riscv_vmv_v_x_u32m4(diffcol, vl), vl);
		}
	}
	return count;
}

double /* Wrapper for testing */
calculatePixelColorDeltaRVVForTest(uint32_t pixel_a, uint32_t pixel_b)
{
	vuint8m1x4_t v4 = __riscv_vcreate_v_u8m1x4(
			__riscv_vmv_s_x_u8m1((uint8_t)(pixel_a>>(0*8)), 1),
			__riscv_vmv_s_x_u8m1((uint8_t)(pixel_a>>(1*8)), 1),
			__riscv_vmv_s_x_u8m1((uint8_t)(pixel_a>>(2*8)), 1),
			__riscv_vmv_s_x_u8m1((uint8_t)(pixel_a>>(3*8)), 1));
	vuint8m1x4_t y4 = __riscv_vcreate_v_u8m1x4(
			__riscv_vmv_s_x_u8m1((uint8_t)(pixel_b>>(0*8)), 1),
			__riscv_vmv_s_x_u8m1((uint8_t)(pixel_b>>(1*8)), 1),
			__riscv_vmv_s_x_u8m1((uint8_t)(pixel_b>>(2*8)), 1),
			__riscv_vmv_s_x_u8m1((uint8_t)(pixel_b>>(3*8)), 1));
	return __riscv_vfmv_f(rvv_yiq_diff(v4, y4, 1));
}
#endif
