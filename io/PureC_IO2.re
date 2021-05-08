module IO: Odiff.ImageIO.ImageIO = {
  type t;
  type row =
    Bigarray.Array1.t(int, Bigarray.int8_unsigned_elt, Bigarray.c_layout);

  let readRow = (img: Odiff.ImageIO.img(t), y): row => {
    ReadPng.read_row(img.image, y, img.width);
  };

  let readImgColor = (x, row: row, _img: Odiff.ImageIO.img(t)) => {
    (row.{x * 4}, row.{x * 4 + 1}, row.{x * 4 + 2}, row.{x * 4 + 3});
  };

  let setImgColor = (x, y, pixel, img: Odiff.ImageIO.img(t)) => {
    ReadPng.set_pixel_data(img.image, x, y, pixel);
  };

  let loadImage = (filename): Odiff.ImageIO.img(t) => {
    let (width, height, rowPointers) = ReadPng.read_png_image(filename);

    {width, height, image: rowPointers};
  };

  let saveImage = (img: Odiff.ImageIO.img(t), filename) => {
    ReadPng.write_png_file(img.image, img.width, img.height, filename);
  };

  let freeImage = (img: Odiff.ImageIO.img(t)) => {
    ReadPng.free_row_pointers(img.image, img.height);
  };

  let makeSameAsLayout = (img: Odiff.ImageIO.img(t)) => {
    {...img, image: ReadPng.create_empty_img(img.height, img.width)};
  };
};
