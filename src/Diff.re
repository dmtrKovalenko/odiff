let redPixel = (255, 0, 0);
let maxYIQPossibleDelta = 35215.;

type diffVariant('a) =
  | Layout
  | Pixel(('a, int, float));

let isInIgnoreRegion = (x, y, regions) => {
  List.exists(
    ((rx, ry, width, height)) => {
      x >= rx && x <= rx + width && y >= ry && y <= ry + height
    },
    regions,
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
    let diffCount = ref(0);
    let maxDelta = maxYIQPossibleDelta *. threshold ** 2.;
    let diffOutput = outputDiffMask ? IO1.makeSameAsLayout(base) : base;

    let countDifference = (x, y) => {
      diffCount := diffCount^ + 1;
      diffOutput |> IO1.setImgColor(x, y, diffPixel);
    };

    for (y in 0 to base.height - 1) {
      let row = IO1.readRow(base, y);
      let row2 = IO2.readRow(comp, y);

      for (x in 0 to base.width - 1) {
        if (isInIgnoreRegion(x, y, ignoreRegions)) {
          ();
        } else if (x >= comp.width || y >= comp.height) {
          let (_r, _g, _b, a) = IO1.readImgColor(x, row, base);
          if (a != 0) {
            countDifference(x, y);
          };
        } else {
          let baseColor = IO1.readImgColor(x, row, base);
          let compColor = IO2.readImgColor(x, row2, comp);

          if (!Helpers.isSameColor(baseColor, compColor)) {
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

    let diffPercentage =
      100.0
      *. Float.of_int(diffCount^)
      /. (Float.of_int(base.width) *. Float.of_int(base.height));

    (diffOutput, diffCount^, diffPercentage);
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
        && base.width != comp.width
        && base.height != comp.height) {
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
