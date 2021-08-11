type img('a) = {
  width: int,
  height: int,
  image: 'a,
};

exception ImageNotLoaded;

module type ImageIO = {
  type t;

  let loadImage: string => img(t);
  let makeSameAsLayout: img(t) => img(t);
  let readDirectPixel: (~x: int, ~y: int, img(t)) => Int32.t;
  let setImgColor: (~x: int, ~y: int, Int32.t, img(t)) => unit;
  let saveImage: (img(t), string) => unit;
  let freeImage: img(t) => unit;
};
