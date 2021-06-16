open ImageIO;

module MakeAntialiasing = (IO1: ImageIO.ImageIO, IO2: ImageIO.ImageIO) => {
  let hasManySiblingsWithSameColor = (~x, ~y, ~width, ~height, ~readColor) =>
    if (x <= width - 1 && y <= height - 1) {
      let x0 = max(x - 1, 0);
      let y0 = max(y - 1, 0);

      let x1 = min(x + 1, width - 1);
      let y1 = min(y + 1, height - 1);

      let zeroes =
        x == x0 || x == x1 || y == y0 || y == y1 ? ref(1) : ref(0);

      let baseColor = readColor(~x, ~y);

      // go through 8 adjacent pixels
      for (adj_y in y0 to y1) {
        for (adj_x in x0 to x1) {
          /* This is not the current pixel and we don't have our result */
          if (zeroes^ < 3 && (x != adj_x || y != adj_y)) {
            let adjacentColor = readColor(~x=adj_x, ~y=adj_y);
            if (baseColor == adjacentColor) {
              incr(zeroes);
            };
          };
        };
      };

      zeroes^ >= 3;
    } else {
      false;
    };

  let detect = (~x, ~y, ~baseImg, ~compImg) => {
    let x0 = max(x - 1, 0);
    let y0 = max(y - 1, 0);

    let x1 = min(x + 1, baseImg.width - 1);
    let y1 = min(y + 1, baseImg.height - 1);

    let minAdjacientDelta = ref(0.0);
    let maxAdjacientDelta = ref(0.0);

    let minAdjacientDeltaCoord = ref((0, 0));
    let maxAdjacientDeltaCoord = ref((0, 0));

    let zeroes = ref(x == x0 || x == x1 || y == y0 || y == y1 ? 1 : 0);

    let baseColor = baseImg |> IO1.readDirectPixel(~x, ~y);

    for (adj_y in y0 to y1) {
      for (adj_x in x0 to x1) {
        /* This is not the current pixel and we don't have our result */
        if (zeroes^ < 3 && (x != adj_x || y != adj_y)) {
          let adjacentColor =
            baseImg |> IO1.readDirectPixel(~x=adj_x, ~y=adj_y);

          if (baseColor == adjacentColor) {
            incr(zeroes);
          } else {
            let delta =
              ColorDelta.calculatePixelBrightnessDelta(
                baseColor,
                adjacentColor,
              );

            if (delta < minAdjacientDelta^) {
              minAdjacientDelta := delta;
              minAdjacientDeltaCoord := (adj_x, adj_y);
            } else if (delta > maxAdjacientDelta^) {
              maxAdjacientDelta := delta;
              maxAdjacientDeltaCoord := (adj_x, adj_y);
            };
          };
        };
      };
    };

    // if we found more than 2 equal siblings or
    // there are no darker pixels among the siblings or
    // there are no brighter pixels among the siblings it's not anti-aliasing
    if (zeroes^ >= 3 || minAdjacientDelta^ == 0.0 || maxAdjacientDelta^ == 0.0) {
      false;
    } else {
      // if either the darkest or the brightest pixel has 3+ equal siblings in both images
      // (definitely not anti-aliased), this pixel is anti-aliased
      let (minX, minY) = minAdjacientDeltaCoord^;
      let (maxX, maxY) = maxAdjacientDeltaCoord^;
      (
        hasManySiblingsWithSameColor(
          ~x=minX,
          ~y=minY,
          ~width=baseImg.width,
          ~height=baseImg.height,
          ~readColor=IO1.readDirectPixel(baseImg),
        )
        || hasManySiblingsWithSameColor(
             ~x=maxX,
             ~y=maxY,
             ~width=baseImg.width,
             ~height=baseImg.height,
             ~readColor=IO1.readDirectPixel(baseImg),
           )
      )
      && (
        hasManySiblingsWithSameColor(
          ~x=minX,
          ~y=minY,
          ~width=compImg.width,
          ~height=compImg.height,
          ~readColor=IO2.readDirectPixel(compImg),
        )
        || hasManySiblingsWithSameColor(
             ~x=maxX,
             ~y=maxY,
             ~width=compImg.width,
             ~height=compImg.height,
             ~readColor=IO2.readDirectPixel(compImg),
           )
      );
    };
  };
};
