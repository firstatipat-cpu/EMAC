# Search for 'Python QR code library' to find suitable libraries.
```python
import qrcode
from PIL import Image

def generate_qr_code(data, filename="qr_code.png"):
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(data)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")
        img.save(filename)
        return f"QR code successfully generated and saved as {filename}"
    except Exception as e:
        return f"Error generating QR code: {e}"

if __name__ == "__main__":
    qr_data = "https://www.example.com"
    qr_code_message = generate_qr_code(qr_data, "example_qr.png")
    print(qr_code_message)
```
> 