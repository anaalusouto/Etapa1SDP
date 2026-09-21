import hashlib
import os
import time
from PIL import Image, ImageFilter

BLUR_PASSES_DEFAULT = 4


def process_image(input_path: str, output_path: str, blur_passes: int = BLUR_PASSES_DEFAULT) -> dict:
    t0 = time.perf_counter()

    img = Image.open(input_path).convert("L")
    for _ in range(blur_passes):
        img = img.filter(ImageFilter.GaussianBlur(radius=3))
    img = img.filter(ImageFilter.FIND_EDGES)

    img.save(output_path)

    with open(output_path, "rb") as f:
        digest = hashlib.md5(f.read()).hexdigest()

    elapsed = time.perf_counter() - t0

    return {
        "filename": os.path.basename(input_path),
        "elapsed_s": elapsed,
        "md5": digest,
    }
