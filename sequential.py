import argparse
import glob
import json
import os
import time

from processing import process_image, BLUR_PASSES_DEFAULT


def run_sequential(input_dir: str, output_dir: str, blur_passes: int) -> dict:
    os.makedirs(output_dir, exist_ok=True)
    input_paths = sorted(glob.glob(os.path.join(input_dir, "*.bmp")))

    manifest = {}
    processed_count = 0

    t_start = time.perf_counter()
    for path in input_paths:
        out_name = os.path.splitext(os.path.basename(path))[0] + ".png"
        out_path = os.path.join(output_dir, out_name)
        result = process_image(path, out_path, blur_passes=blur_passes)
        manifest[result["filename"]] = result
        processed_count += 1
    t_total = time.perf_counter() - t_start

    return {
        "mode": "sequential",
        "workers": 1,
        "n_images": len(input_paths),
        "processed_count": processed_count,
        "total_time_s": t_total,
        "manifest": manifest,
    }


def main():
    parser = argparse.ArgumentParser(description="Processamento sequencial de imagens")
    parser.add_argument("--input", type=str, default="data/input")
    parser.add_argument("--output", type=str, default="data/output_seq")
    parser.add_argument("--blur-passes", type=int, default=BLUR_PASSES_DEFAULT)
    parser.add_argument("--manifest-out", type=str, default="results_sequential.json")
    args = parser.parse_args()

    result = run_sequential(args.input, args.output, args.blur_passes)

    with open(args.manifest_out, "w") as f:
        json.dump(result, f, indent=2)

    print(f"[SEQUENCIAL] {result['processed_count']} imagens em {result['total_time_s']:.3f}s")


if __name__ == "__main__":
    main()
