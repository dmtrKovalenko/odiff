// ARM64 NEON assembly implementation for odiff
// Integer-only arithmetic following calculatePixelColorDeltaSimd approach
// Processes 4 RGBA pixels simultaneously using 128-bit NEON registers

.text
.align 4

// ARM64 NEON assembly implementation for odiff - constants embedded inline

.text
.global _vneon
.align 4

// Function: vneon
// Parameters:
//   x0 = base_rgba (pointer to base image RGBA data)
//   x1 = comp_rgba (pointer to comparison image RGBA data)
//   x2 = base_width (base image width in pixels)
//   x3 = comp_width (comparison image width in pixels)
//   x4 = base_height (base image height in pixels)
//   x5 = comp_height (comparison image height in pixels)
// Returns:
//   w0 = number of different pixels found

_vneon:
    // Function prologue - save registers
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    stp     x25, x26, [sp, #-16]!

    // Initialize difference counter
    mov     w19, #0                       // w19 = diff_count = 0

    // Calculate image dimensions
    mov     x20, x2                       // x20 = base_width
    mov     x21, x3                       // x21 = comp_width
    mov     x22, x4                       // x22 = base_height
    mov     x23, x5                       // x23 = comp_height

    // Calculate processing dimensions (minimum of both images)
    cmp     x20, x21
    csel    x24, x20, x21, lo            // x24 = min_width = min(base_width, comp_width)
    cmp     x22, x23
    csel    x25, x22, x23, lo            // x25 = min_height = min(base_height, comp_height)

    // Calculate row increments after processing min_width pixels
    sub     x26, x20, x24                // base_row_skip = base_width - min_width
    lsl     x26, x26, #2                 // * 4 bytes per pixel
    sub     x6, x21, x24                 // comp_row_skip = comp_width - min_width
    lsl     x6, x6, #2                   // * 4 bytes per pixel

    // Load constant vectors using immediate values (avoiding symbol resolution issues)

    // Channel masks: R=0xff, G=0xff00, B=0xff0000, A=0xff000000
    mov     w8, #0xff
    dup     v16.4s, w8                   // R mask: 0x000000ff
    mov     w8, #0xff00
    dup     v17.4s, w8                   // G mask: 0x0000ff00
    mov     w8, #0xff0000
    dup     v18.4s, w8                   // B mask: 0x00ff0000
    mov     w8, #0xff000000
    dup     v19.4s, w8                   // A mask: 0xff000000

    // Alpha zero detection: 0x01000000
    mov     w8, #0x01000000
    dup     v20.4s, w8

    // Alpha blend constants from disassembly
    mov     w8, #0x1011
    dup     v21.4s, w8                   // Alpha blend const1
    mov     w8, #0x1010
    dup     v22.4s, w8                   // Alpha blend const2

    // White background: 0xff000 (255 << 12)
    mov     w8, #0xff000
    dup     v23.4s, w8                   // White background

    // YIQ transformation coefficients (exact values from disassembly)
    // Y coefficients: 0x4c8, 0x962, 0x1d4, 0x0
    mov     w8, #0x4c8
    mov     v24.s[0], w8
    mov     w8, #0x962
    mov     v24.s[1], w8
    mov     w8, #0x1d4
    mov     v24.s[2], w8
    mov     w8, #0x0
    mov     v24.s[3], w8

    // I coefficients: 0x989, 0xfffffb9d (-1123), 0xfffffada (-1318), 0x0
    mov     w8, #0x989
    mov     v25.s[0], w8
    mov     w8, #0xfffffb9d
    mov     v25.s[1], w8
    mov     w8, #0xfffffada
    mov     v25.s[2], w8
    mov     w8, #0x0
    mov     v25.s[3], w8

    // Q coefficients: 0x362, 0xfffff7a4 (-2140), 0x4fa, 0x0
    mov     w8, #0x362
    mov     v26.s[0], w8
    mov     w8, #0xfffff7a4
    mov     v26.s[1], w8
    mov     w8, #0x4fa
    mov     v26.s[2], w8
    mov     w8, #0x0
    mov     v26.s[3], w8

    // Delta weight factors: Y=0x815, I=0x321, Q=0x321
    mov     w8, #0x815
    dup     v27.4s, w8                   // Y weight
    mov     w8, #0x321
    dup     v28.4s, w8                   // I weight
    dup     v29.4s, w8                   // Q weight

    // Process overflow pixels from height difference
    sub     x7, x22, x25                 // height_diff = base_height - min_height
    mul     x7, x7, x20                  // overflow_pixels = height_diff * base_width
    add     w19, w19, w7                 // diff_count += overflow_pixels

    // Main processing loop - process by rows
    mov     x7, #0                       // y = 0 (row counter)

row_loop:
    cmp     x7, x25                      // compare y with min_height
    b.ge    done                         // if y >= min_height, we're done

    // Process pixels in current row - handle 4 pixels at a time
    mov     x8, #0                       // x = 0 (column counter)

pixel_loop_4:
    add     x9, x8, #4                   // x + 4
    cmp     x9, x24                      // compare (x + 4) with min_width
    b.gt    pixel_loop_remainder         // if (x + 4) > min_width, handle remainder

    // Load 4 pixels from base image
    ldr     q0, [x0]                     // Load 4 RGBA pixels from base
    ldr     q1, [x1]                     // Load 4 RGBA pixels from comp

    // Process 4 pixels simultaneously
    bl      process_4_pixels

    // Add result to difference counter
    add     w19, w19, w0                 // diff_count += pixel_differences

    // Advance to next 4 pixels
    add     x0, x0, #16                  // base_ptr += 16 bytes (4 pixels)
    add     x1, x1, #16                  // comp_ptr += 16 bytes (4 pixels)
    add     x8, x8, #4                   // x += 4
    b       pixel_loop_4

pixel_loop_remainder:
    // Handle remaining pixels in row (less than 4)
    cmp     x8, x24                      // compare x with min_width
    b.ge    end_row                      // if x >= min_width, end of row

    // Load single pixel and process
    ldr     w9, [x0], #4                 // Load base pixel, advance pointer
    ldr     w10, [x1], #4                // Load comp pixel, advance pointer

    // Process single pixel
    bl      process_single_pixel

    // Add result to difference counter
    add     w19, w19, w0                 // diff_count += pixel_difference

    add     x8, x8, #1                   // x++
    b       pixel_loop_remainder

end_row:
    // Handle overflow pixels at end of row (width differences)
    sub     x9, x20, x24                 // width_diff = base_width - min_width
    add     w19, w19, w9                 // diff_count += width_diff (assume all different)

    // Move to next row
    add     x0, x0, x26                  // base_ptr += base_row_skip
    add     x1, x1, x6                   // comp_ptr += comp_row_skip
    add     x7, x7, #1                   // y++
    b       row_loop

done:
    // Return difference count
    mov     w0, w19

    // Function epilogue - restore registers
    ldp     x25, x26, [sp], #16
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// Helper function: process_4_pixels
// Input: q0 = 4 base pixels, q1 = 4 comp pixels
// Output: w0 = number of different pixels (0-4)
// Uses: v0-v15 as scratch registers (v16-v29 contain constants)
process_4_pixels:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Check if pixels are identical first (quick exit)
    cmeq    v0.4s, v0.4s, v1.4s
    uminv   s2, v0.4s                     // s2 = min of comparison results
    fmov    w0, s2
    cbnz    w0, pixels_identical          // If all bits set, all pixels are identical

    // All pixels are different, need detailed analysis
    // Reload the original pixels (they got overwritten by cmeq)
    ldr     q0, [x0]                     // Reload base pixels
    ldr     q1, [x1]                     // Reload comp pixels

    // Extract RGBA channels for base pixels (v0)
    and     v2.16b, v0.16b, v16.16b      // v2 = base R channels
    and     v3.16b, v0.16b, v17.16b      // v3 = base G channels (shifted)
    and     v4.16b, v0.16b, v18.16b      // v4 = base B channels (shifted)
    and     v5.16b, v0.16b, v19.16b      // v5 = base A channels (shifted)

    // Extract RGBA channels for comp pixels (v1)
    and     v6.16b, v1.16b, v16.16b      // v6 = comp R channels
    and     v7.16b, v1.16b, v17.16b      // v7 = comp G channels (shifted)
    and     v8.16b, v1.16b, v18.16b      // v8 = comp B channels (shifted)
    and     v9.16b, v1.16b, v19.16b      // v9 = comp A channels (shifted)

    // Shift channels to proper positions
    ushr    v3.4s, v3.4s, #8            // Shift G to position
    ushr    v4.4s, v4.4s, #16           // Shift B to position
    ushr    v5.4s, v5.4s, #24           // Shift A to position
    ushr    v7.4s, v7.4s, #8            // Shift G to position
    ushr    v8.4s, v8.4s, #16           // Shift B to position
    ushr    v9.4s, v9.4s, #24           // Shift A to position

    // Handle alpha=0 case for base pixels - replace with white
    // Compare alpha with 0
    cmeq    v10.4s, v5.4s, #0           // v10 = mask where base alpha == 0

    // Set RGB to 255 where alpha is 0
    mov     w8, #255
    dup     v11.4s, w8
    bsl     v10.16b, v11.16b, v2.16b    // v2 = R (255 if alpha=0, else original)
    cmeq    v12.4s, v5.4s, #0
    bsl     v12.16b, v11.16b, v3.16b    // v3 = G (255 if alpha=0, else original)
    cmeq    v13.4s, v5.4s, #0
    bsl     v13.16b, v11.16b, v4.16b    // v4 = B (255 if alpha=0, else original)

    mov     v2.16b, v10.16b              // Update base R
    mov     v3.16b, v12.16b              // Update base G
    mov     v4.16b, v13.16b              // Update base B

    // Handle alpha=0 case for comp pixels - replace with white
    cmeq    v10.4s, v9.4s, #0           // v10 = mask where comp alpha == 0
    bsl     v10.16b, v11.16b, v6.16b    // v6 = R (255 if alpha=0, else original)
    cmeq    v12.4s, v9.4s, #0
    bsl     v12.16b, v11.16b, v7.16b    // v7 = G (255 if alpha=0, else original)
    cmeq    v13.4s, v9.4s, #0
    bsl     v13.16b, v11.16b, v8.16b    // v8 = B (255 if alpha=0, else original)

    mov     v6.16b, v10.16b              // Update comp R
    mov     v7.16b, v12.16b              // Update comp G
    mov     v8.16b, v13.16b              // Update comp B

    // Scale to fixed-point (12-bit fractional) - shift left by 12
    shl     v2.4s, v2.4s, #12           // base R scaled
    shl     v3.4s, v3.4s, #12           // base G scaled
    shl     v4.4s, v4.4s, #12           // base B scaled
    shl     v6.4s, v6.4s, #12           // comp R scaled
    shl     v7.4s, v7.4s, #12           // comp G scaled
    shl     v8.4s, v8.4s, #12           // comp B scaled

    // Perform alpha blending using integer arithmetic
    // Following the pattern from calculatePixelColorDeltaSimd
    // blend = (pixel - 255) * (alpha / 255) + 255
    // Using fixed-point: blend = (pixel - (255<<12)) * alpha * (1/255) + (255<<12)

    // Alpha normalization (divide by 255 using multiply by 1/255 approximation)
    mov     w8, #0x101                   // 257 (approximation of 256*256/255)
    dup     v14.4s, w8

    // Normalize alpha values: alpha * 257 >> 16 ≈ alpha / 255
    mul     v5.4s, v5.4s, v14.4s        // base alpha * 257
    mul     v9.4s, v9.4s, v14.4s        // comp alpha * 257
    ushr    v5.4s, v5.4s, #16           // base alpha / 255 (approximated)
    ushr    v9.4s, v9.4s, #16           // comp alpha / 255 (approximated)

    // Alpha blending for base pixels
    // (pixel - white_bg) * alpha + white_bg, where white_bg = 255<<12
    sub     v2.4s, v2.4s, v23.4s        // (base_R - white)
    sub     v3.4s, v3.4s, v23.4s        // (base_G - white)
    sub     v4.4s, v4.4s, v23.4s        // (base_B - white)

    mul     v2.4s, v2.4s, v5.4s         // (base_R - white) * alpha
    mul     v3.4s, v3.4s, v5.4s         // (base_G - white) * alpha
    mul     v4.4s, v4.4s, v5.4s         // (base_B - white) * alpha
    ushr    v2.4s, v2.4s, #8            // Normalize multiplication
    ushr    v3.4s, v3.4s, #8
    ushr    v4.4s, v4.4s, #8

    add     v2.4s, v2.4s, v23.4s        // + white_bg
    add     v3.4s, v3.4s, v23.4s
    add     v4.4s, v4.4s, v23.4s

    // Alpha blending for comp pixels
    sub     v6.4s, v6.4s, v23.4s        // (comp_R - white)
    sub     v7.4s, v7.4s, v23.4s        // (comp_G - white)
    sub     v8.4s, v8.4s, v23.4s        // (comp_B - white)

    mul     v6.4s, v6.4s, v9.4s         // (comp_R - white) * alpha
    mul     v7.4s, v7.4s, v9.4s         // (comp_G - white) * alpha
    mul     v8.4s, v8.4s, v9.4s         // (comp_B - white) * alpha
    ushr    v6.4s, v6.4s, #8            // Normalize multiplication
    ushr    v7.4s, v7.4s, #8
    ushr    v8.4s, v8.4s, #8

    add     v6.4s, v6.4s, v23.4s        // + white_bg
    add     v7.4s, v7.4s, v23.4s
    add     v8.4s, v8.4s, v23.4s

    // Calculate RGB differences
    sub     v2.4s, v2.4s, v6.4s         // delta_R = base_R - comp_R
    sub     v3.4s, v3.4s, v7.4s         // delta_G = base_G - comp_G
    sub     v4.4s, v4.4s, v8.4s         // delta_B = base_B - comp_B

    // Convert RGB deltas to YIQ using dotprod (if available) or regular multiply-accumulate
    // Y = delta_R * coeff_Y_R + delta_G * coeff_Y_G + delta_B * coeff_Y_B
    mul     v10.4s, v2.4s, v24.s[0]     // delta_R * Y_R_coeff
    mla     v10.4s, v3.4s, v24.s[1]     // + delta_G * Y_G_coeff
    mla     v10.4s, v4.4s, v24.s[2]     // + delta_B * Y_B_coeff -> v10 = Y_delta

    // I = delta_R * coeff_I_R + delta_G * coeff_I_G + delta_B * coeff_I_B
    mul     v11.4s, v2.4s, v25.s[0]     // delta_R * I_R_coeff
    mla     v11.4s, v3.4s, v25.s[1]     // + delta_G * I_G_coeff
    mla     v11.4s, v4.4s, v25.s[2]     // + delta_B * I_B_coeff -> v11 = I_delta

    // Q = delta_R * coeff_Q_R + delta_G * coeff_Q_G + delta_B * coeff_Q_B
    mul     v12.4s, v2.4s, v26.s[0]     // delta_R * Q_R_coeff
    mla     v12.4s, v3.4s, v26.s[1]     // + delta_G * Q_G_coeff
    mla     v12.4s, v4.4s, v26.s[2]     // + delta_B * Q_B_coeff -> v12 = Q_delta

    // Normalize YIQ deltas (right shift by 12 to remove fixed-point scaling)
    sshr    v10.4s, v10.4s, #12         // Y_delta normalized
    sshr    v11.4s, v11.4s, #12         // I_delta normalized
    sshr    v12.4s, v12.4s, #12         // Q_delta normalized

    // Calculate weighted squared deltas: Y²*weight_Y + I²*weight_I + Q²*weight_Q
    mul     v10.4s, v10.4s, v10.4s      // Y_delta²
    mul     v11.4s, v11.4s, v11.4s      // I_delta²
    mul     v12.4s, v12.4s, v12.4s      // Q_delta²

    mul     v10.4s, v10.4s, v27.s[0]    // Y²*weight_Y
    mul     v11.4s, v11.4s, v28.s[0]    // I²*weight_I
    mul     v12.4s, v12.4s, v29.s[0]    // Q²*weight_Q

    add     v13.4s, v10.4s, v11.4s      // Y²*weight_Y + I²*weight_I
    add     v13.4s, v13.4s, v12.4s      // + Q²*weight_Q = total_delta

    // Final normalization (right shift by 24, matching disassembly)
    ushr    v13.4s, v13.4s, #24         // Final delta values

    // TODO: Compare with threshold and count differences
    // For now, assume threshold passed via register (will be implemented)
    mov     w8, #0x58                    // Temporary threshold placeholder
    dup     v14.4s, w8

    cmhi    v15.4s, v13.4s, v14.4s      // Compare deltas > threshold

    // Count number of pixels that exceed threshold
    cnt     v15.8b, v15.8b               // Population count per byte
    uaddlv  h0, v15.8b                  // Sum all counts
    fmov    w0, s0                      // Move result to w0
    lsr     w0, w0, #5                  // Adjust count (each 32-bit element contributes 4 bytes)

    ldp     x29, x30, [sp], #16
    ret

pixels_identical:
    mov     w0, #0                       // No differences found
    ldp     x29, x30, [sp], #16
    ret

// Helper function: process_single_pixel
// Input: w9 = base pixel, w10 = comp pixel
// Output: w0 = 1 if different, 0 if same
process_single_pixel:
    // TODO: Implement single pixel processing
    // This is a placeholder - will be implemented in next steps
    cmp     w9, w10
    cset    w0, ne                       // Set w0 = 1 if pixels are different
    ret

// End of vneon function
