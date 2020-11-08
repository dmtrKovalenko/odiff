type pixelColors = (int, int, int, int);
let blend = (c, a) => 255 + (c - 255) * a;

let blendSemiTransparentColor =
  fun
  | (r, g, b, alpha) when alpha < 255 => (
      blend(r, alpha),
      blend(g, alpha),
      blend(b, alpha),
      alpha / 255,
    )
  | colors => colors;

let rgb2y = ((r, g, b, a)) =>
  Float.of_int(r)
  *. 0.29889531
  +. Float.of_int(g)
  *. 0.58662247
  +. Float.of_int(b)
  *. 0.11448223;

let rgb2i = ((r, g, b, a)) =>
  Float.of_int(r)
  *. 0.59597799
  -. Float.of_int(g)
  *. 0.27417610
  -. Float.of_int(b)
  *. 0.32180189;

let rgb2q = ((r, g, b, a)) =>
  Float.of_int(r)
  *. 0.21147017
  -. Float.of_int(g)
  *. 0.52261711
  +. Float.of_int(b)
  *. 0.31114694;

let calculatePixelColorDelta = (pixelA: pixelColors, pixelB: pixelColors) => {
  let y1 = pixelA |> blendSemiTransparentColor |> rgb2y;
  let y2 = pixelB |> blendSemiTransparentColor |> rgb2y;

  let y = y1 -. y2;

  let i = rgb2i(pixelA) -. rgb2i(pixelB);
  let q = rgb2q(pixelA) -. rgb2q(pixelB);

  0.5053 *. y *. y +. 0.299 *. i *. i +. 0.1957 *. q *. q;
};