open Int32

(* Decimal representation of the RGBA in32 pixel red pixel *)
let redPixel = Int32.of_int 4278190335

(* Decimal representation of the RGBA in32 pixel green pixel *)
let maxYIQPossibleDelta = 35215.

type 'a diffVariant = Layout | Pixel of ('a * int * float * int Stack.t * (int * (int * int) list) list)

let unrollIgnoreRegions width list =
  list
  |> Option.map
       (List.map (fun ((x1, y1), (x2, y2)) ->
            let p1 = (y1 * width) + x1 in
            let p2 = (y2 * width) + x2 in
            (p1, p2)))

let isInIgnoreRegion offset list =
  list
  |> Option.map
       (List.exists (fun ((p1 : int), (p2 : int)) ->
            offset >= p1 && offset <= p2))
  |> Option.value ~default:false

module MakeDiff (IO1 : ImageIO.ImageIO) (IO2 : ImageIO.ImageIO) = struct
  module BaseAA = Antialiasing.MakeAntialiasing (IO1) (IO2)
  module CompAA = Antialiasing.MakeAntialiasing (IO2) (IO1)

  let compare (base : IO1.t ImageIO.img) (comp : IO2.t ImageIO.img)
      ?(antialiasing = false) ?(outputDiffMask = false) ?(diffLines = false)
      ?diffPixel ?(threshold = 0.1) ?ignoreRegions ?(captureDiff = true) ?(captureDiffCoords = false) () =
    let maxDelta = maxYIQPossibleDelta *. (threshold ** 2.) in
    let diffPixel = match diffPixel with Some x -> x | None -> redPixel in
    let diffOutput =
      match captureDiff with
      | true ->
          Some
            (match outputDiffMask with
            | true -> IO1.makeSameAsLayout base
            | false -> base)
      | false -> None
    in

    let diffCount = ref 0 in
    let diffLinesStack = Stack.create () in
    let diffCoords = ref [] in
    let currentRanges = ref [] in
    let lastY = ref (-1) in
    let lastX = ref (-1) in
    let currentRange = ref None in

    let countDifference x y =
      incr diffCount;
      diffOutput |> Option.iter (IO1.setImgColor ~x ~y diffPixel);

      if captureDiffCoords then (
        if !lastY <> y then (
          !currentRange |> Option.iter (fun (start, _) ->
            currentRanges := (start, !lastX) :: !currentRanges);
          if !currentRanges <> [] then (
            diffCoords := (!lastY, List.rev !currentRanges) :: !diffCoords;
            currentRanges := []
          );
          lastY := y;
          lastX := -1;
          currentRange := None
        );

        if !lastX = -1 || x <> !lastX + 1 then (
          !currentRange |> Option.iter (fun (start, _) ->
            currentRanges := (start, !lastX) :: !currentRanges);
          currentRange := Some (x, x)
        ) else (
          !currentRange |> Option.iter (fun (start, _) ->
            currentRange := Some (start, x))
        );
        lastX := x
      );

      if
        diffLines
        && (diffLinesStack |> Stack.is_empty || diffLinesStack |> Stack.top < y)
      then diffLinesStack |> Stack.push y
    in

    let ignoreRegions = unrollIgnoreRegions base.width ignoreRegions in
    let hasIgnoreRegions = ignoreRegions |> Option.is_some in

    let size = (base.height * base.width) - 1 in
    let x = ref 0 in
    let y = ref 0 in

    let layoutDifference =
      base.width <> comp.width || base.height <> comp.height
    in

    for offset = 0 to size do
      (* if images are different we can't use offset *)
      let baseColor =
        if layoutDifference then IO1.readRawPixel ~x:!x ~y:!y base
        else IO1.readRawPixelAtOffset offset base
      in

      (if !x >= comp.width || !y >= comp.height then (
         let alpha = logand (shift_right_logical baseColor 24) 255l in
         if alpha <> Int32.zero then countDifference !x !y)
       else
         let compColor =
           if layoutDifference then IO2.readRawPixel ~x:!x ~y:!y comp
           else IO2.readRawPixelAtOffset offset comp
         in

         if baseColor <> compColor then
           let isIgnored =
             hasIgnoreRegions && isInIgnoreRegion offset ignoreRegions
           in

           if not isIgnored then
             let delta =
               ColorDelta.calculatePixelColorDelta baseColor compColor
             in
             if delta > maxDelta then
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

    let diffPercentage =
      100.0 *. Float.of_int !diffCount
      /. (Float.of_int base.width *. Float.of_int base.height)
    in

    if captureDiffCoords then (
      if !currentRange <> None then (
        currentRanges := (Option.get !currentRange) :: !currentRanges;
        currentRange := None
      );
      if !currentRanges <> [] then
        diffCoords := (!lastY, List.rev !currentRanges) :: !diffCoords
    );

    let diffCoords = List.rev !diffCoords in
    (diffOutput, !diffCount, diffPercentage, diffLinesStack, diffCoords)

  let diff (base : IO1.t ImageIO.img) (comp : IO2.t ImageIO.img) ~outputDiffMask
      ?(threshold = 0.1) ~diffPixel ?(failOnLayoutChange = true)
      ?(antialiasing = false) ?(diffLines = false) ?ignoreRegions ?(captureDiffCoords = false) () =
    if
      failOnLayoutChange = true
      && (base.width <> comp.width || base.height <> comp.height)
    then Layout
    else
      let diffOutput, diffCount, diffPercentage, diffLinesStack, diffCoords =
        compare base comp ~threshold ~diffPixel ~outputDiffMask ~antialiasing
          ~diffLines ?ignoreRegions ~captureDiff:true ~captureDiffCoords ()
      in
      Pixel (Option.get diffOutput, diffCount, diffPercentage, diffLinesStack, diffCoords)

  let diffWithoutOutput (base : IO1.t ImageIO.img) (comp : IO2.t ImageIO.img)
      ?(threshold = 0.1) ?(failOnLayoutChange = true) ?(antialiasing = false)
      ?(diffLines = false) ?ignoreRegions ?(captureDiffCoords = false) () =
    if
      failOnLayoutChange = true
      && (base.width <> comp.width || base.height <> comp.height)
    then Layout
    else
      let diffOutput, diffCount, diffPercentage, diffLinesStack, diffCoords =
        compare base comp ~threshold ~outputDiffMask:false ~antialiasing
          ~diffLines ?ignoreRegions ~captureDiff:false ~captureDiffCoords ()
      in
      Pixel (diffOutput, diffCount, diffPercentage, diffLinesStack, diffCoords)
end
