open Bigarray

type data = (int32, int32_elt, c_layout) Array1.t

module IO : Odiff.ImageIO.ImageIO = struct
  type t = data

  let loadImage filename : t Odiff.ImageIO.img =
    let width, height, data = ReadBmp.load filename in
    { width; height; image = data }

  let readDirectPixel ~(x : int) ~(y : int) (img : t Odiff.ImageIO.img) =
    let image : data = img.image in
    Array1.unsafe_get image ((y * img.width) + x)
  [@@inline]

  let setImgColor ~x ~y color (img : t Odiff.ImageIO.img) =
    let image : data = img.image in
    Array1.unsafe_set image ((y * img.width) + x) color
  [@@inline]

  let saveImage (img : t Odiff.ImageIO.img) filename =
    WritePng.write_png_bigarray filename img.image img.width img.height

  let freeImage (img : t Odiff.ImageIO.img) = ()

  let makeSameAsLayout (img : t Odiff.ImageIO.img) =
    let image = Array1.create int32 c_layout (Array1.dim img.image) in
    { img with image }
end
