type img('a) = {
  width: int,
  height: int,
  image: 'a,
};

exception ImageNotLoaded;

module type ImageIO = {
  type t;
  type row;

  let loadImage: string => img(t);
  let readRow: (img(t), int) => row;
  let readImgColor: (int, row, img(t)) => (int, int, int, int);
  let setImgColor: (int, int, (int, int, int, int), img(t)) => unit;
  let saveImage: (img(t), string) => unit;
  let freeImage: img(t) => unit;
  let makeSameAsLayout: img(t) => img(t);
};