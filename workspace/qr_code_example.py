import qrcode


if __name__ == "__main__":
  qr = qrcode.QRCode(
  version=1,
  error_correction=qrcode.constants.ERROR_CORRECT_L,
  box_size=10,
  border=4,
  )
  
  data = "https://www.example.com"
  qr.add_data(data)
  qr.make(fit=True)

  img = qr.make_image(fill_color=None, back_color="")

  img.save("qr_code.png")

  print("QR code saved as qr_code.png")