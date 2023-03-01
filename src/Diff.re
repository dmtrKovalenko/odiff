let redPixel = (255, 0, 0);
let maxYIQPossibleDelta = 35215.;

type diffVariant('a) =
  | Layout
  | Pixel(('a, int, float, Option.t(Stack.t(int))));

let computeIngoreRegionOffsets = width => {
  List.map((((x1, y1), (x2, y2))) => {
    let p1 = y1 * width + x1;
    let p2 = y2 * width + x2;
    (p1, p2);
  });
};

let isInIgnoreRegion = offset => {
  List.exists(((p1: int, p2: int)) => offset >= p1 && offset <= p2);
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
        ~diffLines=false,
        ~diffPixel: (int, int, int)=redPixel,
        ~threshold=0.1,
        ~ignoreRegions=[],
        (),
      ) => {
    let maxDelta = maxYIQPossibleDelta *. threshold ** 2.;
    let diffOutput = outputDiffMask ? IO1.makeSameAsLayout(base) : base;

    let diffPixelQueue = Queue.create();
    let diffLinesStack = diffLines ? Some(Stack.create()) : None;

    let countDifference = (x, y) => {
      diffPixelQueue |> Queue.push((x, y));

      switch (diffLinesStack) {
      | Some(stack) when stack |> Stack.is_empty => stack |> Stack.push(y)
      | Some(stack) when stack |> Stack.top < y => stack |> Stack.push(y)
      | _ => ()
      };
    };

    let ignoreRegions =
      ignoreRegions |> computeIngoreRegionOffsets(base.width);

    let size = base.height * base.width - 1;

    let x = ref(0);
    let y = ref(0);

    for (offset in 0 to size) {
      if (x^ >= comp.width || y^ >= comp.height) {
        let alpha =
          Int32.to_int(IO1.readDirectPixel(~x=x^, ~y=y^, base))
          lsr 24
          land 0xFF;

        if (alpha != 0) {
          countDifference(x^, y^);
        };
      } else {
        let baseColor = IO1.readDirectPixel(~x=x^, ~y=y^, base);
        let compColor = IO2.readDirectPixel(~x=x^, ~y=y^, comp);

        if (baseColor != compColor) {
          let delta =
            ColorDelta.calculatePixelColorDelta(baseColor, compColor);

          if (delta > maxDelta) {
            let isIgnored = isInIgnoreRegion(offset, ignoreRegions);

            if (!isIgnored) {
              let isAntialiased =
                if (!antialiasing) {
                  false;
                } else {
                  BaseAA.detect(~x=x^, ~y=y^, ~baseImg=base, ~compImg=comp)
                  || CompAA.detect(~x=x^, ~y=y^, ~baseImg=comp, ~compImg=base);
                };

              if (!isAntialiased) {
                countDifference(x^, y^);
              };
            };
          };
        };
      };
      if (x^ == base.width - 1) {
        x := 0;
        incr(y);
      } else {
        incr(x);
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

    (diffOutput, diffCount, diffPercentage, diffLinesStack);
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
        ~diffLines=false,
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
          ~diffLines,
          ~ignoreRegions,
          (),
        );

      Pixel(diffResult);
    };
};
