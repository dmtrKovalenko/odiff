let redPixel = (
  255 |> char_of_int,
  0 |> char_of_int,
  0 |> char_of_int,
  255 |> char_of_int,
);

let transparentPixel: Rgba32.elt = {
  color: {
    r: 0,
    g: 0,
    b: 0,
  },
  alpha: 0,
};

let maxYIQPossibleDelta = 35215.;

type diffVariant =
  | Layout
  | Pixel((Rgba32.t, int));

let compare =
    (base: Rgba32.t, comp: Rgba32.t, ~threshold=0.1, ~diffImage=false, ()) => {
  let diffCount = ref(0);

  let diff =
    diffImage
      ? Rgba32.copy(base)
      : Rgba32.make(base.width, base.height, transparentPixel);

  let maxDelta = maxYIQPossibleDelta *. threshold ** 2.;

  let countDifference = (x, y) => {
    diffCount := diffCount^ + 1;
    diff |> ImageIO.setImgColor(x, y, redPixel);
  };

  for (x in 0 to base.width - 1) {
    for (y in 0 to base.height - 1) {
      if (x >= comp.width || y >= comp.height) {
        let a = ImageIO.readImgAlpha(x, y, base);

        if (a != 0) {
          countDifference(x, y);
        };
      } else {
        let (r, g, b, a) = ImageIO.readImgColor(x, y, base);
        let (r1, g1, b1, a1) = ImageIO.readImgColor(x, y, comp);

        if (r != r1 || g != g1 || b != b1 || a != a1) {
          let delta =
            ColorDelta.calculatePixelColorDelta(
              (r, g, b, a),
              (r1, g1, b1, a1),
            );

          if (delta > maxDelta) {
            countDifference(x, y);
          };
        };
      };
    };
  };

  (diff, diffCount^);
};

let diff =
    (
      base: Rgba32.t,
      comp: Rgba32.t,
      ~threshold=0.1,
      ~diffImage=false,
      ~failOnLayoutChange=true,
      (),
    ) =>
  if (failOnLayoutChange == true
      && base.width != comp.width
      && base.height != comp.height) {
    Layout;
  } else {
    Pixel(compare(base, comp, ~threshold, ~diffImage, ()));
  };