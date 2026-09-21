import argparse
import os
import numpy as np
from PIL import Image


def generate_image(index: int, width: int, height: int) -> Image.Image:
    rng = np.random.default_rng(index)
    arr = rng.integers(0, 256, size=(height, width, 3), dtype=np.uint8)
    return Image.fromarray(arr, "RGB")


def main():
    parser = argparse.ArgumentParser(description="Gera dataset sintético de imagens")
    parser.add_argument("--n", type=int, default=600, help="Número de imagens")
    parser.add_argument("--size", type=str, default="800x600", help="Resolução WxH")
    parser.add_argument("--out", type=str, default="data/input", help="Diretório de saída")
    args = parser.parse_args()

    width, height = (int(v) for v in args.size.lower().split("x"))
    os.makedirs(args.out, exist_ok=True)

    for i in range(args.n):
        img = generate_image(i, width, height)
        img.save(os.path.join(args.out, f"img_{i:05d}.bmp"))
        if (i + 1) % 100 == 0 or (i + 1) == args.n:
            print(f"  gerado {i + 1}/{args.n}")

    print(f"Dataset pronto: {args.n} imagens {width}x{height} em '{args.out}'")


if __name__ == "__main__":
    main()
