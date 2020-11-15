let blend = (color, alpha) => 255 + (color - 255) * alpha;

let blendSemiTransparentColor =
  fun
  | (r, g, b, alpha) when alpha < 255 => (
      blend(r, alpha),
      blend(g, alpha),
      blend(b, alpha),
      alpha / 255,
    )
  | colors => colors;

let convertPixelToFloat = ((r, g, b, a)) => (
  Float.of_int(r),
  Float.of_int(g),
  Float.of_int(b),
  Float.of_int(a),
);

let rgb2y = ((r, g, b, a)) =>
  r *. 0.29889531 +. g *. 0.58662247 +. b *. 0.11448223;

let rgb2i = ((r, g, b, a)) =>
  r *. 0.59597799 -. g *. 0.27417610 -. b *. 0.32180189;

let rgb2q = ((r, g, b, a)) =>
  r *. 0.21147017 -. g *. 0.52261711 +. b *. 0.31114694;

let calculatePixelColorDelta = (_pixelA, _pixelB) => {
  let pixelA = _pixelA |> blendSemiTransparentColor |> convertPixelToFloat;
  let pixelB = _pixelB |> blendSemiTransparentColor |> convertPixelToFloat;

  let y = rgb2y(pixelA) -. rgb2y(pixelB);
  let i = rgb2i(pixelA) -. rgb2i(pixelB);
  let q = rgb2q(pixelA) -. rgb2q(pixelB);

  0.5053 *. y *. y +. 0.299 *. i *. i +. 0.1957 *. q *. q;
};