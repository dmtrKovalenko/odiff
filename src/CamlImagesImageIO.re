/* open Util;

exception ImageNotLoaded;

 
module ImageIO: ImageIO.ImageIO {
  type t = Rgba32.t; 
  let loadImage = filename => {
    switch (Images.load(filename, [])) {
    | Index8(i8img) => Index8.to_rgba32(i8img)
    | Rgb24(rgba24img) => Rgb24.to_rgba32(rgba24img)
    | Rgba32(img) => img
    | imgTyp => raise(ImageNotLoaded)
    };
  };
  
  let saveImage = (filename, imageBuffer: ImageIO.img(t)) => {
    let a = Images.Rgba32(imageBuffer) 
    
    Png.save(filename, [], a);
  }
  
  let readImgColor = (x, y, img: ImageIO.img(t)) => {
    let (bytes, position) = Rgba32.unsafe_access(img, x, y);
  
    (
      Bytes.unsafe_get(bytes, position) |> Char.code,
      Bytes.unsafe_get(bytes, position + 1) |> Char.code,
      Bytes.unsafe_get(bytes, position + 2) |> Char.code,
      Bytes.unsafe_get(bytes, position + 3) |> Char.code,
    );
  };
  
  let readImgAlpha = (x, y, img: ImageIO.img(t)) => {
    let (bytes, position) = Rgba32.unsafe_access(img, x, y);
  
    Bytes.unsafe_get(bytes, position + 3) |> Char.code;
  };
  
  let setImgColor = (x, y, (r, g, b, a), img) => {
    let (bytes, position) = Rgba32.unsafe_access(img, x, y);
  
    Bytes.unsafe_set(bytes, position, r |> char_of_int);
    Bytes.unsafe_set(bytes, position + 1, g |> char_of_int);
    Bytes.unsafe_set(bytes, position + 2, b |> char_of_int);
    Bytes.unsafe_set(bytes, position + 3, a |> char_of_int);
  };
} */