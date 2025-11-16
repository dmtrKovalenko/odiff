// Simplified ARM64 NEON assembly implementation for odiff - basic pixel comparison
// This is a minimal version to debug segfault issues

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

    // Initialize difference counter
    mov     w19, #0                       // w19 = diff_count = 0

    // Calculate processing dimensions (minimum of both images)
    cmp     x2, x3                        // compare base_width with comp_width
    csel    x20, x2, x3, lo              // x20 = min_width = min(base_width, comp_width)
    cmp     x4, x5                        // compare base_height with comp_height
    csel    x21, x4, x5, lo              // x21 = min_height = min(base_height, comp_height)

    // Calculate total pixels to process
    mul     x22, x20, x21                 // x22 = total_pixels = min_width * min_height

    // Process pixels using NEON SIMD (4 pixels at a time when possible)
    mov     x6, #0                        // x6 = pixel_counter = 0

simd_loop:
    add     x7, x6, #4                    // x7 = pixel_counter + 4
    cmp     x7, x22                       // compare (pixel_counter + 4) with total_pixels
    b.gt    scalar_loop                   // if not enough pixels for SIMD, use scalar

    // Load 4 pixels from each image using NEON
    ldr     q0, [x0], #16                 // Load 4 base pixels, advance pointer
    ldr     q1, [x1], #16                 // Load 4 comp pixels, advance pointer

    // Handle alpha=0 pixels by replacing them with white (0xFFFFFFFF)
    // Extract alpha channels
    mov     w7, #0xFF000000               // Alpha mask
    dup     v2.4s, w7                    // Alpha mask in all lanes
    and     v3.16b, v0.16b, v2.16b       // Base alpha channels
    and     v4.16b, v1.16b, v2.16b       // Comp alpha channels

    // Check for alpha=0
    cmeq    v5.4s, v3.4s, #0             // Base alpha == 0 mask
    cmeq    v6.4s, v4.4s, #0             // Comp alpha == 0 mask

    // Replace alpha=0 pixels with white
    mov     w7, #0xFFFFFFFF               // White pixel value
    dup     v7.4s, w7                    // White in all lanes
    bsl     v5.16b, v7.16b, v0.16b       // Replace base pixels where alpha=0
    bsl     v6.16b, v7.16b, v1.16b       // Replace comp pixels where alpha=0

    mov     v0.16b, v5.16b                // Update base pixels
    mov     v1.16b, v6.16b                // Update comp pixels

    // Enhanced comparison using basic YIQ color space difference
    // Extract RGBA channels for base pixels (v0)
    mov     w8, #0xFF
    dup     v8.4s, w8                    // R mask: 0x000000FF
    mov     w8, #0xFF00
    dup     v9.4s, w8                    // G mask: 0x0000FF00
    mov     w8, #0xFF0000
    dup     v10.4s, w8                   // B mask: 0x00FF0000

    and     v2.16b, v0.16b, v8.16b       // Base R channels
    and     v3.16b, v0.16b, v9.16b       // Base G channels (shifted)
    and     v4.16b, v0.16b, v10.16b      // Base B channels (shifted)

    and     v11.16b, v1.16b, v8.16b      // Comp R channels
    and     v12.16b, v1.16b, v9.16b      // Comp G channels (shifted)
    and     v13.16b, v1.16b, v10.16b     // Comp B channels (shifted)

    // Shift channels to proper positions
    ushr    v3.4s, v3.4s, #8             // Shift G to position
    ushr    v4.4s, v4.4s, #16            // Shift B to position
    ushr    v12.4s, v12.4s, #8           // Shift G to position
    ushr    v13.4s, v13.4s, #16          // Shift B to position

    // Calculate RGB differences
    sub     v2.4s, v2.4s, v11.4s         // Delta R = base_R - comp_R
    sub     v3.4s, v3.4s, v12.4s         // Delta G = base_G - comp_G
    sub     v4.4s, v4.4s, v13.4s         // Delta B = base_B - comp_B

    // Simple weighted difference (approximating YIQ importance)
    // Y ≈ 0.3*R + 0.6*G + 0.1*B, so we weight G more heavily
    abs     v2.4s, v2.4s                 // |Delta R|
    abs     v3.4s, v3.4s                 // |Delta G|
    abs     v4.4s, v4.4s                 // |Delta B|

    // Weight: R*1 + G*2 + B*1 (simple integer weights)
    add     v14.4s, v2.4s, v4.4s         // R + B
    add     v3.4s, v3.4s, v3.4s          // G * 2
    add     v14.4s, v14.4s, v3.4s        // R + G*2 + B = weighted difference

    // Compare with threshold (approximate perceptual threshold)
    mov     w8, #3                       // Threshold value
    dup     v15.4s, w8
    cmhi    v14.4s, v14.4s, v15.4s       // Compare: 1 if difference > threshold

    // Count different pixels
    ushr    v14.4s, v14.4s, #31          // Extract MSB: 0 if same, 1 if different
    addv    s3, v14.4s                   // Sum all lanes to get count of different pixels
    fmov    w7, s3                       // Move count to general register
    add     w19, w19, w7                 // Add to total difference count

    add     x6, x6, #4                   // pixel_counter += 4
    b       simd_loop

scalar_loop:
    cmp     x6, x22                      // compare pixel_counter with total_pixels
    b.ge    done                         // if pixel_counter >= total_pixels, we're done

    // Load one pixel from each image
    ldr     w7, [x0], #4                 // Load base pixel, advance pointer
    ldr     w8, [x1], #4                 // Load comp pixel, advance pointer

    // Handle alpha=0 pixels - replace with white
    mov     w11, #0xFFFFFFFF             // White pixel constant
    and     w9, w7, #0xFF000000          // Extract base alpha
    cmp     w9, #0                       // Check if alpha == 0
    csel    w7, w11, w7, eq              // Replace with white if alpha=0

    and     w10, w8, #0xFF000000         // Extract comp alpha
    cmp     w10, #0                      // Check if alpha == 0
    csel    w8, w11, w8, eq              // Replace with white if alpha=0

    // Enhanced scalar comparison using weighted RGB difference
    // Extract RGB channels
    and     w9, w7, #0xFF                // Base R
    and     w10, w7, #0xFF00             // Base G (shifted)
    and     w11, w7, #0xFF0000           // Base B (shifted)
    lsr     w10, w10, #8                 // Shift G to position
    lsr     w11, w11, #16                // Shift B to position

    and     w12, w8, #0xFF               // Comp R
    and     w13, w8, #0xFF00             // Comp G (shifted)
    and     w14, w8, #0xFF0000           // Comp B (shifted)
    lsr     w13, w13, #8                 // Shift G to position
    lsr     w14, w14, #16                // Shift B to position

    // Calculate RGB differences
    sub     w9, w9, w12                  // Delta R = base_R - comp_R
    sub     w10, w10, w13                // Delta G = base_G - comp_G
    sub     w11, w11, w14                // Delta B = base_B - comp_B

    // Get absolute values
    cmp     w9, #0
    cneg    w9, w9, mi                   // |Delta R|
    cmp     w10, #0
    cneg    w10, w10, mi                 // |Delta G|
    cmp     w11, #0
    cneg    w11, w11, mi                 // |Delta B|

    // Weighted difference: R*1 + G*2 + B*1
    add     w12, w9, w11                 // R + B
    add     w10, w10, w10                // G * 2
    add     w12, w12, w10                // R + G*2 + B = weighted difference

    // Compare with threshold
    cmp     w12, #3                      // Compare with threshold
    b.le    next_pixel                   // If difference <= threshold, skip

    // Pixels are significantly different, increment counter
    add     w19, w19, #1

next_pixel:
    add     x6, x6, #1                   // pixel_counter++
    b       scalar_loop

done:
    // Return difference count
    mov     w0, w19

    // Function epilogue - restore registers
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// End of vneon function