// Antialiasing detection - equivalent to Antialiasing.ml
const std = @import("std");
const image_io = @import("image_io.zig");
const color_delta = @import("color_delta.zig");

const Image = image_io.Image;

fn hasManySiblingsWithSameColor(x: u32, y: u32, width: u32, height: u32, image: *const Image) bool {
    if (x <= width - 1 and y <= height - 1) {
        const x0 = @max(if (x > 0) x - 1 else 0, 0);
        const y0 = @max(if (y > 0) y - 1 else 0, 0);
        const x1 = @min(x + 1, width - 1);
        const y1 = @min(y + 1, height - 1);

        var zeroes: u32 = if (x == x0 or x == x1 or y == y0 or y == y1) 1 else 0;

        const base_color = image.readRawPixel(x, y);

        var adj_y = y0;
        while (adj_y <= y1) : (adj_y += 1) {
            var adj_x = x0;
            while (adj_x <= x1) : (adj_x += 1) {
                if (zeroes < 3 and (x != adj_x or y != adj_y)) {
                    const adjacent_color = image.readRawPixel(adj_x, adj_y);
                    if (base_color == adjacent_color) {
                        zeroes += 1;
                    }
                }
            }
        }

        return zeroes >= 3;
    } else {
        return false;
    }
}

pub fn detect(x: u32, y: u32, base_img: *const Image, comp_img: *const Image) bool {
    const x0 = @max(if (x > 0) x - 1 else 0, 0);
    const y0 = @max(if (y > 0) y - 1 else 0, 0);
    const x1 = @min(x + 1, base_img.width - 1);
    const y1 = @min(y + 1, base_img.height - 1);

    var min_sibling_delta: f64 = 0.0;
    var max_sibling_delta: f64 = 0.0;
    var min_sibling_coord = struct { x: u32, y: u32 }{ .x = 0, .y = 0 };
    var max_sibling_coord = struct { x: u32, y: u32 }{ .x = 0, .y = 0 };

    var zeroes: u32 = if (x == x0 or x == x1 or y == y0 or y == y1) 1 else 0;

    const base_color = base_img.readRawPixel(x, y);

    var adj_y = y0;
    while (adj_y <= y1) : (adj_y += 1) {
        var adj_x = x0;
        while (adj_x <= x1) : (adj_x += 1) {
            if (zeroes < 3 and (x != adj_x or y != adj_y)) {
                const adjacent_color = base_img.readRawPixel(adj_x, adj_y);
                if (base_color == adjacent_color) {
                    zeroes += 1;
                } else {
                    const delta = color_delta.calculatePixelBrightnessDelta(base_color, adjacent_color);
                    if (delta < min_sibling_delta) {
                        min_sibling_delta = delta;
                        min_sibling_coord = .{ .x = adj_x, .y = adj_y };
                    } else if (delta > max_sibling_delta) {
                        max_sibling_delta = delta;
                        max_sibling_coord = .{ .x = adj_x, .y = adj_y };
                    }
                }
            }
        }
    }

    if (zeroes >= 3 or min_sibling_delta == 0.0 or max_sibling_delta == 0.0) {
        // If we found more than 2 equal siblings or there are
        // no darker pixels among other siblings or
        // there are not brighter pixels among the siblings
        return false;
    } else {
        // If either the darkest or the brightest pixel has 3+ equal siblings in both images
        // (definitely not anti-aliased), this pixel is anti-aliased
        const min_has_siblings_base = hasManySiblingsWithSameColor(min_sibling_coord.x, min_sibling_coord.y, base_img.width, base_img.height, base_img);
        const max_has_siblings_base = hasManySiblingsWithSameColor(max_sibling_coord.x, max_sibling_coord.y, base_img.width, base_img.height, base_img);

        const min_has_siblings_comp = hasManySiblingsWithSameColor(min_sibling_coord.x, min_sibling_coord.y, comp_img.width, comp_img.height, comp_img);
        const max_has_siblings_comp = hasManySiblingsWithSameColor(max_sibling_coord.x, max_sibling_coord.y, comp_img.width, comp_img.height, comp_img);

        return (min_has_siblings_base or max_has_siblings_base) and
            (min_has_siblings_comp or max_has_siblings_comp);
    }
}
