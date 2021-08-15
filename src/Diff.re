let redPixel = (255, 0, 0);
let maxYIQPossibleDelta = 35215.;

type diffVariant('a) =
  | Layout
  | Pixel(('a, int, float));

let isInIgnoreRegion = (x, y) => {
  List.exists((((x1, y1), (x2, y2))) =>
    x >= x1 && x <= x2 && y >= y1 && y <= y2
  );
};

module MakeDiff = (IO1: ImageIO.ImageIO, IO2: ImageIO.ImageIO) => {
  module BaseAA = Antialiasing.MakeAntialiasing(IO1, IO2);
  module CompAA = Antialiasing.MakeAntialiasing(IO2, IO1);

  let compare =
      (
        base: ImageIO.img(IO1.t),
        comp: ImageIO.img(IO2.t),
        ~antialiasing=false,
        ~outputDiffMask=false,
        ~diffPixel: (int, int, int)=redPixel,
        ~threshold=0.1,
        ~ignoreRegions=[],
        (),
      ) => {
    let maxDelta = maxYIQPossibleDelta *. threshold ** 2.;
    let diffOutput = outputDiffMask ? IO1.makeSameAsLayout(base) : base;

    let diffPixelQueue = Queue.create();
    let countDifference = (x, y) => {
      diffPixelQueue |> Queue.push((x, y));
    };

    for (y in 0 to base.height - 1) {
      for (x in 0 to base.width - 1) {
        if (isInIgnoreRegion(x, y, ignoreRegions)) {
          ();
        } else if (x >= comp.width || y >= comp.height) {
          let alpha =
            Int32.to_int(IO1.readDirectPixel(x, y, base)) lsr 24 land 0xFF;

          if (alpha != 0) {
            countDifference(x, y);
          };
        } else {
          let baseColor = IO1.readDirectPixel(x, y, base);
          let compColor = IO2.readDirectPixel(x, y, comp);

          if (baseColor != compColor) {
            let delta =
              ColorDelta.calculatePixelColorDelta(baseColor, compColor);

            if (delta > maxDelta) {
              let isAntialiased =
                if (!antialiasing) {
                  false;
                } else {
                  BaseAA.detect(~x, ~y, ~baseImg=base, ~compImg=comp)
                  || CompAA.detect(~x, ~y, ~baseImg=comp, ~compImg=base);
                };

              if (!isAntialiased) {
                countDifference(x, y);
              };
            };
          };
        };
      };
    };

    let diffCount = diffPixelQueue |> Queue.length;

    if (diffCount > 0) {
      let (r, g, b) = diffPixel;
      let a = (255 land 0xFF) lsl 24;
      let b = (b land 0xFF) lsl 16;
      let g = (g land 0xFF) lsl 8;
      let r = (r land 0xFF) lsl 0;
      let diffPixel = Int32.of_int(a lor b lor g lor r);

      diffPixelQueue
      |> Queue.iter(((x, y)) => {
           diffOutput |> IO1.setImgColor(~x, ~y, diffPixel)
         });
    };

    let diffPercentage =
      100.0
      *. Float.of_int(diffCount)
      /. (Float.of_int(base.width) *. Float.of_int(base.height));

    (diffOutput, diffCount, diffPercentage);
  };

  let diff =
      (
        base: ImageIO.img(IO1.t),
        comp: ImageIO.img(IO2.t),
        ~outputDiffMask,
        ~threshold=0.1,
        ~diffPixel=redPixel,
        ~failOnLayoutChange=true,
        ~antialiasing=false,
        ~ignoreRegions=[],
        (),
      ) =>
    if (failOnLayoutChange == true
        && (base.width != comp.width || base.height != comp.height)) {
      Layout;
    } else {
      let diffResult =
        compare(
          base,
          comp,
          ~threshold,
          ~diffPixel,
          ~outputDiffMask,
          ~antialiasing,
          ~ignoreRegions,
          (),
        );

      Pixel(diffResult);
    };
};
