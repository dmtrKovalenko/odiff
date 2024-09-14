open Int32

type pixel = { r : float; g : float; b : float; a : float }

let white_pixel : pixel = { r = 255.; g = 255.; b = 255.; a = 0. }
let blend_channel_white color alpha = 255. +. ((color -. 255.) *. alpha)

let blendSemiTransparentPixel = function
  | { r; g; b; a } when a = 0. -> white_pixel
  | { r; g; b; a } when a = 255. -> { r; g; b; a = 1. }
  | { r; g; b; a } when a < 255. ->
      let normalizedAlpha = a /. 255. in
      let r, g, b, a =
        ( blend_channel_white r normalizedAlpha,
          blend_channel_white g normalizedAlpha,
          blend_channel_white b normalizedAlpha,
          normalizedAlpha )
      in

      { r; g; b; a }
  | _ ->
      failwith
        "Found pixel with alpha value greater than uint8 max value. Aborting."

let decodeRawPixel pixel =
  let a = logand (shift_right_logical pixel 24) 255l in
  let b = logand (shift_right_logical pixel 16) 255l in
  let g = logand (shift_right_logical pixel 8) 255l in
  let r = logand pixel 255l in

  {
    r = Int32.to_float r;
    g = Int32.to_float g;
    b = Int32.to_float b;
    a = Int32.to_float a;
  }
[@@inline]

let rgb2y { r; g; b; a } =
  (r *. 0.29889531) +. (g *. 0.58662247) +. (b *. 0.11448223)

let rgb2i { r; g; b; a } =
  (r *. 0.59597799) -. (g *. 0.27417610) -. (b *. 0.32180189)

let rgb2q { r; g; b; a } =
  (r *. 0.21147017) -. (g *. 0.52261711) +. (b *. 0.31114694)

let calculatePixelColorDelta pixelA pixelB =
  let pixelA = pixelA |> decodeRawPixel |> blendSemiTransparentPixel in
  let pixelB = pixelB |> decodeRawPixel |> blendSemiTransparentPixel in

  let y = rgb2y pixelA -. rgb2y pixelB in
  let i = rgb2i pixelA -. rgb2i pixelB in
  let q = rgb2q pixelA -. rgb2q pixelB in

  let delta = (0.5053 *. y *. y) +. (0.299 *. i *. i) +. (0.1957 *. q *. q) in
  delta

let calculatePixelBrightnessDelta pixelA pixelB =
  let pixelA = pixelA |> decodeRawPixel |> blendSemiTransparentPixel in
  let pixelB = pixelB |> decodeRawPixel |> blendSemiTransparentPixel in
  rgb2y pixelA -. rgb2y pixelB
