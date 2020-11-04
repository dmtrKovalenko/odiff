let calcSize = (img: Rgba32.t) => img.width * img.height;

let redPixel: Rgba32.elt = {
  alpha: 255,
  color: {
    r: 255,
    g: 0,
    b: 0,
  },
};

let compare = (a, b, diff) => {
  let diffCount = ref(0);
  let (base, comp) = calcSize(a) > calcSize(b) ? (a, b) : (b, a);

  for (x in 0 to base.width - 1) {
    for (y in 0 to base.height - 1) {
      let pixelA = Rgba32.get(base, x, y);
      let pixelB = Rgba32.get(comp, x, y);

      let delta = ColorDelta.calculatePixelColorDelta(pixelA, pixelB);

      if (delta > 0.) {
        diffCount.contents = diffCount.contents + 1;
        Rgba32.set(diff, x, y, redPixel);
      };
      ();
    };
  };

  
  Console.log(diffCount.contents)
};
