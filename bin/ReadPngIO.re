open OdiffIo;

module ReadPngIO: Odiff.ImageIO.ImageIO = {
  type t;
  type row =
    Bigarray.Array1.t(int, Bigarray.int8_unsigned_elt, Bigarray.c_layout);

  let readRow = (img: Odiff.ImageIO.img(t), y): row => {
    let a = ReadPng.read_row(img.image, y, img.width);

    a;
  };

  let readImgColor = (x, row: row, _img: Odiff.ImageIO.img(t)) => {
    (row.{x * 4}, row.{x * 4 + 1}, row.{x * 4 + 2}, row.{x * 4 + 3});
  };

  let setImgColor = (x, y, _pixel, img: Odiff.ImageIO.img(t)) => {
    ReadPng.set_pixel_data(img.image, x, y);
  };

  let loadImage = filename => {
    let (width, height, bytes) = ReadPng.read_png_file_to_tuple(filename);

    let img1: Odiff.ImageIO.img(t) = {width, height, image: bytes};

    img1;
  };

  let saveImage = (img: Odiff.ImageIO.img(t), filename) => {
    ReadPng.write_png_file(img.image, img.width, img.height, filename)
  };

  let freeImage = (img: Odiff.ImageIO.img(t)) => {
    ReadPng.free_row_pointers(img.image, img.height);
  }
};