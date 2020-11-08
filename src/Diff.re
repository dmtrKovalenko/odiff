let calcSize = (img: Rgba32.t) => img.width * img.height;

let redPixel: Rgba32.elt = {
  alpha: 255,
  color: {
    r: 255,
    g: 0,
    b: 0,
  },
};

let compare = (a, b, diff, ~threshold=0.1, ()) => {
  let diffCount = ref(0);
  let (base, comp) = calcSize(a) > calcSize(b) ? (a, b) : (b, a);

  for (x in 0 to base.width - 1) {
    for (y in 0 to base.height - 1) {
      let (r, g, b, a) = base |> ImageIO.readImgColor(x, y);
      let (r1, g1, b1, a1) = comp |> ImageIO.readImgColor(x, y);

      if (r != r1 || g != g1 || b != b1 || a != a1) {
        let delta =
          ColorDelta.calculatePixelColorDelta(
            (r, b, g, a),
            (r1, b1, g1, a1),
          );

        if (delta > threshold) {
          diffCount := diffCount^ + 1;
          Rgba32.set(diff, x, y, redPixel);
        };
      };
    };
  };

  diffCount^;
};