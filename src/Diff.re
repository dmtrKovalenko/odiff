let redPixel = (255, 0, 0);
let maxYIQPossibleDelta = 35215.;

type diffVariant('a) =
  | Layout
  | Pixel(('a, int, float));

module MakeDiff = (IO1: ImageIO.ImageIO, IO2: ImageIO.ImageIO) => {
  let compare =
      (
        base: ImageIO.img(IO1.t),
        comp: ImageIO.img(IO2.t),
        ~antialiasing=false,
        ~outputDiffMask=false,
        ~diffPixel: (int, int, int)=redPixel,
        ~threshold=0.1,
        (),
      ) => {
    let diffPixels = ref([]);
    let maxDelta = maxYIQPossibleDelta *. threshold ** 2.;
    let diffOutput = outputDiffMask ? IO1.makeSameAsLayout(base) : base;

    let countDifference = (x, y) => {
      diffPixels := [(x, y), ...diffPixels^];
    };

    for (y in 0 to base.height - 1) {
      let row = IO1.readRow(base, y);
      let row2 = IO2.readRow(comp, y);

      let getBaseColor = (x, rowToGet) => {
        IO1.readImgColor(
          x,
          rowToGet == y ? row : IO1.readRow(base, rowToGet),
          base,
        );
      };

      let getCompColor = (x, rowToGet) => {
        IO2.readImgColor(
          x,
          rowToGet == y ? row2 : IO2.readRow(comp, rowToGet),
          comp,
        );
      };

      for (x in 0 to base.width - 1) {
        if (x >= comp.width || y >= comp.height) {
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
                  Antialiasing.isAntialiased(
                    ~x,
                    ~y,
                    ~baseWidth=base.width,
                    ~baseHeight=base.height,
                    ~readBaseColor=getBaseColor,
                    ~compWidth=comp.width,
                    ~compHeight=comp.height,
                    ~readCompColor=getCompColor,
                  )
                  || Antialiasing.isAntialiased(
                       ~x,
                       ~y,
                       ~baseWidth=comp.width,
                       ~baseHeight=comp.height,
                       ~readBaseColor=getCompColor,
                       ~compWidth=base.width,
                       ~compHeight=base.height,
                       ~readCompColor=getBaseColor,
                     );
                };

              if (!isAntialiased) {
                countDifference(x, y);
              };
            };
          };
        };
      };
    };

    diffPixels^
    |> List.iter(((x, y)) => IO1.setImgColor(x, y, diffPixel, diffOutput));
    let diffCount = List.length(diffPixels^);

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
          (),
        );

      Pixel(diffResult);
    };
};
