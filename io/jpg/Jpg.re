open Bigarray;

type data = Array1.t(int32, int32_elt, c_layout);

module IO = {
  type t = data;
  type row = int;
  let buffer = ref(None);

  let loadImage = (filename): Odiff.ImageIO.img(t) => {
    let (width, height, image, b) = ReadJpg.read_jpeg_image(filename);
    buffer := Some(b);

    {width, height, image};
  };

  let readRow = (img: Odiff.ImageIO.img(t), y): row => y;

  let readDirectPixel = (~x, ~y, img: Odiff.ImageIO.img(t)) => {
    (img.image).{y * img.width + x};
  };

  let readImgColor = (x, row: row, img: Odiff.ImageIO.img(t)) => {
    readDirectPixel(~x, ~y=row, img);
  };

  let setImgColor = (x, y, (r, g, b), img: Odiff.ImageIO.img(t)) => {
    let a = (255 land 0xFF) lsl 24;
    let b = (b land 0xFF) lsl 16;
    let g = (g land 0xFF) lsl 8;
    let r = (r land 0xFF) lsl 0;
    Array1.set(
      img.image,
      y * img.width + x,
      Int32.of_int(a lor b lor g lor r),
    );
  };

  let saveImage = (img: Odiff.ImageIO.img(t), filename) => {
    WritePng.write_png_bigarray(filename, img.image, img.width, img.height);
  };

  let freeImage = (img: Odiff.ImageIO.img(t)) => {
    buffer^ |> Option.iter(ReadJpg.cleanup_jpg);
  };

  let makeSameAsLayout = (img: Odiff.ImageIO.img(t)) => {
    let image = Array1.create(int32, c_layout, Array1.dim(img.image));

    {...img, image};
  };
};
