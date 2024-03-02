let blend color alpha = 255. +. ((color -. 255.) *. alpha)

let blendSemiTransparentColor = function
  | r, g, b, alpha when alpha < 255. ->
      (blend r alpha, blend g alpha, blend b alpha, alpha /. 255.)
  | colors -> colors

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
  (0.5053 *. y *. y) +. (0.299 *. i *. i) +. (0.1957 *. q *. q)

let calculatePixelBrightnessDelta pixelA pixelB =
  let pixelA = pixelA |> convertPixelToFloat |> blendSemiTransparentColor in
  let pixelB = pixelB |> convertPixelToFloat |> blendSemiTransparentColor in
  rgb2y pixelA -. rgb2y pixelB
