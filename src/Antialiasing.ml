open ImageIO

module MakeAntialiasing (IO1 : ImageIO.ImageIO) (IO2 : ImageIO.ImageIO) = struct
  let hasManySiblingsWithSameColor ~x ~y ~width ~height ~readColor =
    if x <= width - 1 && y <= height - 1 then (
      let x0 = max (x - 1) 0 in
      let y0 = max (y - 1) 0 in
      let x1 = min (x + 1) (width - 1) in
      let y1 = min (y + 1) (height - 1) in
      let zeroes =
        match x = x0 || x = x1 || y = y0 || y = y1 with
        | true -> ref 1
        | false -> ref 0
      in
      let baseColor = readColor ~x ~y in
      for adj_y = y0 to y1 do
        for adj_x = x0 to x1 do
          if !zeroes < 3 && (x <> adj_x || y <> adj_y) then
            let adjacentColor = readColor ~x:adj_x ~y:adj_y in
            if baseColor = adjacentColor then incr zeroes
        done
      done;
      !zeroes >= 3)
    else false

  let detect ~x ~y ~baseImg ~compImg =
    let x0 = max (x - 1) 0 in
    let y0 = max (y - 1) 0 in
    let x1 = min (x + 1) (baseImg.width - 1) in
    let y1 = min (y + 1) (baseImg.height - 1) in
    let minSiblingDelta = ref 0.0 in
    let maxSiblingDelta = ref 0.0 in
    let minSiblingDeltaCoord = ref (0, 0) in
    let maxSiblingDeltaCoord = ref (0, 0) in
    let zeroes =
      ref
        (match x = x0 || x = x1 || y = y0 || y = y1 with
        | true -> 1
        | false -> 0)
    in

    let baseColor = baseImg |> IO1.readRawPixel ~x ~y in
    for adj_y = y0 to y1 do
      for adj_x = x0 to x1 do
        if !zeroes < 3 && (x <> adj_x || y <> adj_y) then
          let adjacentColor = baseImg |> IO1.readRawPixel ~x:adj_x ~y:adj_y in
          if baseColor = adjacentColor then incr zeroes
          else
            let delta =
              ColorDelta.calculatePixelBrightnessDelta baseColor adjacentColor
            in
            if delta < !minSiblingDelta then (
              minSiblingDelta := delta;
              minSiblingDeltaCoord := (adj_x, adj_y))
            else if delta > !maxSiblingDelta then (
              maxSiblingDelta := delta;
              maxSiblingDeltaCoord := (adj_x, adj_y))
      done
    done;

    if !zeroes >= 3 || !minSiblingDelta = 0.0 || !maxSiblingDelta = 0.0 then
      (*
          If we found more than 2 equal siblings or there are
          no darker pixels among other siblings or
          there are not brighter pixels among the siblings
      *)
      false
    else
      (*
         If either the darkest or the brightest pixel has 3+ equal siblings in both images
         (definitely not anti-aliased), this pixel is anti-aliased
      *)
      let minX, minY = !minSiblingDeltaCoord in
      let maxX, maxY = !maxSiblingDeltaCoord in
      (hasManySiblingsWithSameColor ~x:minX ~y:minY ~width:baseImg.width
         ~height:baseImg.height ~readColor:(IO1.readRawPixel baseImg)
      || hasManySiblingsWithSameColor ~x:maxX ~y:maxY ~width:baseImg.width
           ~height:baseImg.height ~readColor:(IO1.readRawPixel baseImg))
      && (hasManySiblingsWithSameColor ~x:minX ~y:minY ~width:compImg.width
            ~height:compImg.height ~readColor:(IO2.readRawPixel compImg)
         || hasManySiblingsWithSameColor ~x:maxX ~y:maxY ~width:compImg.width
              ~height:compImg.height ~readColor:(IO2.readRawPixel compImg))
end
