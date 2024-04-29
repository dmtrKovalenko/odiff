let blend_channel_white color alpha = 255. +. ((color -. 255.) *. alpha)
let white_pixel = (255., 255., 255., 0.)

let blendSemiTransparentColor = function
  | r, g, b, 0. -> white_pixel
  | r, g, b, 255. -> (r, g, b, 1.)
  | r, g, b, alpha when alpha < 255. ->
      let normalizedAlpha = alpha /. 255. in
      let r, g, b, a =
        ( blend_channel_white r normalizedAlpha,
          blend_channel_white g normalizedAlpha,
          blend_channel_white b normalizedAlpha,
          normalizedAlpha )
      in
      (r, g, b, a)
  | _ ->
      failwith
        "Found pixel with alpha value greater than uint8 max value. Aborting."

let convertPixelToFloat pixel =
  let pixel = pixel |> Int32.to_int in
  let a = (pixel lsr 24) land 255 in
  let b = (pixel lsr 16) land 255 in
  let g = (pixel lsr 8) land 255 in
  let r = pixel land 255 in

  (Float.of_int r, Float.of_int g, Float.of_int b, Float.of_int a)

let rgb2y (r, g, b, a) =
  (r *. 0.29889531) +. (g *. 0.58662247) +. (b *. 0.11448223)

let rgb2i (r, g, b, a) =
  (r *. 0.59597799) -. (g *. 0.27417610) -. (b *. 0.32180189)

let rgb2q (r, g, b, a) =
  (r *. 0.21147017) -. (g *. 0.52261711) +. (b *. 0.31114694)

let calculatePixelColorDelta _pixelA _pixelB =
  let pixelA = _pixelA |> convertPixelToFloat |> blendSemiTransparentColor in
  let pixelB = _pixelB |> convertPixelToFloat |> blendSemiTransparentColor in

  let y = rgb2y pixelA -. rgb2y pixelB in
  let i = rgb2i pixelA -. rgb2i pixelB in
  let q = rgb2q pixelA -. rgb2q pixelB in

  let delta = (0.5053 *. y *. y) +. (0.299 *. i *. i) +. (0.1957 *. q *. q) in
  delta

let calculatePixelBrightnessDelta pixelA pixelB =
  let pixelA = pixelA |> convertPixelToFloat |> blendSemiTransparentColor in
  let pixelB = pixelB |> convertPixelToFloat |> blendSemiTransparentColor in
  rgb2y pixelA -. rgb2y pixelB
