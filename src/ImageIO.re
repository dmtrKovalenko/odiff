type img('a) = {
  width: int,
  height: int,
  image: 'a,
};

type rgb_pixel = (int, int, int);
exception ImageNotLoaded;

module type ImageIO = {
  type t;
  type row;

  let loadImage: string => img(t);
  let readRow: (img(t), int) => row;
  let readImgColor: (int, row, img(t)) => Int32.t;
  let setImgColor: (int, int, rgb_pixel, img(t)) => unit;
  let saveImage: (img(t), string) => unit;
  let freeImage: img(t) => unit;
  let makeSameAsLayout: img(t) => img(t);
  let readDirectPixel: (~x: int, ~y: int, img(t)) => Int32.t;
};
