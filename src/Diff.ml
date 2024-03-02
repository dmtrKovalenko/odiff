let redPixel = (255, 0, 0)
let maxYIQPossibleDelta = 35215.

type 'a diffVariant = Layout | Pixel of ('a * int * float * int Stack.t)

let computeIgnoreRegionOffsets width =
  List.map (fun ((x1, y1), (x2, y2)) ->
      let p1 = (y1 * width) + x1 in
      let p2 = (y2 * width) + x2 in
      (p1, p2))

let isInIgnoreRegion offset =
  List.exists (fun ((p1 : int), (p2 : int)) -> offset >= p1 && offset <= p2)

module MakeDiff (IO1 : ImageIO.ImageIO) (IO2 : ImageIO.ImageIO) = struct
  module BaseAA = Antialiasing.MakeAntialiasing (IO1) (IO2)
  module CompAA = Antialiasing.MakeAntialiasing (IO2) (IO1)

  let compare (base : IO1.t ImageIO.img) (comp : IO2.t ImageIO.img)
      ?(antialiasing = false) ?(outputDiffMask = false) ?(diffLines = false)
      ?(diffPixel : int * int * int = redPixel) ?(threshold = 0.1)
      ?(ignoreRegions = []) () =
    let maxDelta = maxYIQPossibleDelta *. (threshold ** 2.) in
    let diffOutput =
      match outputDiffMask with
      | true -> IO1.makeSameAsLayout base
      | false -> base
    in
    let diffPixelQueue = Queue.create () in
    let diffLinesStack = Stack.create () in
    let countDifference x y =
      diffPixelQueue |> Queue.push (x, y);
      if
        diffLines
        && (diffLinesStack |> Stack.is_empty || diffLinesStack |> Stack.top < y)
      then diffLinesStack |> Stack.push y
    in

    let ignoreRegions =
      ignoreRegions |> computeIgnoreRegionOffsets base.width
    in

    let size = (base.height * base.width) - 1 in
    let x = ref 0 in
    let y = ref 0 in

    for offset = 0 to size do
      (if !x >= comp.width || !y >= comp.height then (
         let alpha =
           (Int32.to_int (IO1.readDirectPixel ~x:!x ~y:!y base) lsr 24) land 255
         in
         if alpha <> 0 then countDifference !x !y)
       else
         let baseColor = IO1.readDirectPixel ~x:!x ~y:!y base in
         let compColor = IO2.readDirectPixel ~x:!x ~y:!y comp in
         if baseColor <> compColor then
           let delta =
             ColorDelta.calculatePixelColorDelta baseColor compColor
           in
           if delta > maxDelta then
             let isIgnored = isInIgnoreRegion offset ignoreRegions in
             if not isIgnored then
               let isAntialiased =
                 if not antialiasing then false
                 else
                   BaseAA.detect ~x:!x ~y:!y ~baseImg:base ~compImg:comp
                   || CompAA.detect ~x:!x ~y:!y ~baseImg:comp ~compImg:base
               in
               if not isAntialiased then countDifference !x !y);

      if !x = base.width - 1 then (
        x := 0;
        incr y)
      else incr x
    done;

    let diffCount = diffPixelQueue |> Queue.length in
    (if diffCount > 0 then
       let r, g, b = diffPixel in
       let a = (255 land 255) lsl 24 in
       let b = (b land 255) lsl 16 in
       let g = (g land 255) lsl 8 in
       let r = (r land 255) lsl 0 in
       let diffPixel = Int32.of_int (a lor b lor g lor r) in
       diffPixelQueue
       |> Queue.iter (fun (x, y) ->
              diffOutput |> IO1.setImgColor ~x ~y diffPixel));

    let diffPercentage =
      100.0 *. Float.of_int diffCount
      /. (Float.of_int base.width *. Float.of_int base.height)
    in
    (diffOutput, diffCount, diffPercentage, diffLinesStack)

  let diff (base : IO1.t ImageIO.img) (comp : IO2.t ImageIO.img) ~outputDiffMask
      ?(threshold = 0.1) ?(diffPixel = redPixel) ?(failOnLayoutChange = true)
      ?(antialiasing = false) ?(diffLines = false) ?(ignoreRegions = []) () =
    if
      failOnLayoutChange = true
      && (base.width <> comp.width || base.height <> comp.height)
    then Layout
    else
      let diffResult =
        compare base comp ~threshold ~diffPixel ~outputDiffMask ~antialiasing
          ~diffLines ~ignoreRegions ()
      in

      Pixel diffResult
end
