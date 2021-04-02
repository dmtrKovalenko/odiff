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
        ~outputDiffMask=false,
        ~diffPixel: (int, int, int)=redPixel,
        ~threshold=0.1,
        (),
      ) => {
    let diffCount = ref(0);
    let maxDelta = maxYIQPossibleDelta *. threshold ** 2.;
    let diffOutput = outputDiffMask ? IO1.makeSameAsLayout(base) : base;

    let countDifference = (x, y) => {
      diffCount := diffCount^ + 1;
      diffOutput |> IO1.setImgColor(x, y, diffPixel);
    };

    // With the anti-aliasing check, we are getting a 4 x 4 square of colors
    // To not get all of them twice, we cache them in a Hashtable, to be able to look them up easily.
    // TODO: We at most need to keep the current + two rows up + two rows down of colors.
    let colorCacheBase = Array.make_matrix(base.width, base.height, None);
    let rowCacheBase = Array.make(base.height, None);

    let colorCacheComp = Array.make_matrix(comp.width, comp.height, None);
    let rowCacheComp = Array.make(comp.height, None);

    let getBaseRow = y =>
      switch (rowCacheBase[y]) {
      | Some(row) => row
      | None =>
        let row = IO1.readRow(base, y);
        rowCacheBase[y] = Some(row);
        row;
      };

    let getCompRow = y =>
      switch (rowCacheComp[y]) {
      | Some(row) => row
      | None =>
        let row = IO2.readRow(comp, y);
        rowCacheComp[y] = Some(row);
        row;
      };

    let getBaseColor = (x, y) =>
      switch (colorCacheBase[x][y]) {
      | Some(color) => color
      | None =>
        let row = getBaseRow(y);
        let color = IO1.readImgColor(x, row, base);
        colorCacheBase[x][y] = Some(color);
        color;
      };

    let getCompColor = (x, y) =>
      switch (colorCacheComp[x][y]) {
      | Some(color) => color
      | None =>
        let row = getCompRow(y);
        let color = IO2.readImgColor(x, row, comp);
        colorCacheComp[x][y] = Some(color);
        color;
      };

    for (y in 0 to base.height - 1) {
      for (x in 0 to base.width - 1) {
        if (x >= comp.width || y >= comp.height) {
          let (_r, _g, _b, a) = getBaseColor(x, y);
          if (a != 0) {
            countDifference(x, y);
          };
        } else {
          let baseColor = getBaseColor(x, y);
          let compColor = getCompColor(x, y);

          if (!Helpers.isSameColor(baseColor, compColor)) {
            let delta =
              ColorDelta.calculatePixelColorDelta(baseColor, compColor);

            if (delta > maxDelta) {
              let isAntialiased =
                Antialiasing.isAntialiased(
                  ~x,
                  ~y,
                  ~width=base.width,
                  ~height=base.height,
                  ~readBaseColor=getBaseColor,
                  ~readCompColor=getCompColor,
                )
                || Antialiasing.isAntialiased(
                     ~x,
                     ~y,
                     ~width=comp.width,
                     ~height=comp.height,
                     ~readBaseColor=getCompColor,
                     ~readCompColor=getBaseColor,
                   );

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
        (),
      ) =>
    if (failOnLayoutChange == true
        && base.width != comp.width
        && base.height != comp.height) {
      Layout;
    } else {
      let diffResult =
        compare(base, comp, ~threshold, ~diffPixel, ~outputDiffMask, ());

      Pixel(diffResult);
    };
};
