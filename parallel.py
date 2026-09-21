import argparse
import glob
import json
import multiprocessing as mp
import os
import time

from processing import process_image, BLUR_PASSES_DEFAULT

_counter = None
_lock = None
_manifest = None
_blur_passes = None


def _init_worker(counter, lock, manifest, blur_passes):
    global _counter, _lock, _manifest, _blur_passes
    _counter = counter
    _lock = lock
    _manifest = manifest
    _blur_passes = blur_passes


def _worker(args):
    input_path, output_path = args
    result = process_image(input_path, output_path, blur_passes=_blur_passes)

    with _lock:
        _counter.value += 1
        _manifest[result["filename"]] = result
        progress = _counter.value

    return progress


def run_parallel(input_dir: str, output_dir: str, blur_passes: int, workers: int) -> dict:
    os.makedirs(output_dir, exist_ok=True)
    input_paths = sorted(glob.glob(os.path.join(input_dir, "*.bmp")))
    tasks = [
        (p, os.path.join(output_dir, os.path.splitext(os.path.basename(p))[0] + ".png"))
        for p in input_paths
    ]

    manager = mp.Manager()
    shared_manifest = manager.dict()
    shared_counter = mp.Value("i", 0)
    lock = mp.Lock()

    t_start = time.perf_counter()
    with mp.Pool(
        processes=workers,
        initializer=_init_worker,
        initargs=(shared_counter, lock, shared_manifest, blur_passes),
    ) as pool:
        for _ in pool.imap_unordered(_worker, tasks, chunksize=4):
            pass
    t_total = time.perf_counter() - t_start

    return {
        "mode": "parallel",
        "workers": workers,
        "n_images": len(input_paths),
        "processed_count": shared_counter.value,
        "total_time_s": t_total,
        "manifest": dict(shared_manifest),
    }


def main():
    parser = argparse.ArgumentParser(description="Processamento paralelo de imagens")
    parser.add_argument("--input", type=str, default="data/input")
    parser.add_argument("--output", type=str, default="data/output_par")
    parser.add_argument("--blur-passes", type=int, default=BLUR_PASSES_DEFAULT)
    parser.add_argument("--workers", type=int, default=os.cpu_count() or 4)
    parser.add_argument("--manifest-out", type=str, default="results_parallel.json")
    args = parser.parse_args()

    result = run_parallel(args.input, args.output, args.blur_passes, args.workers)

    with open(args.manifest_out, "w") as f:
        json.dump(result, f, indent=2)

    print(
        f"[PARALELO] {result['processed_count']} imagens em "
        f"{result['total_time_s']:.3f}s com {result['workers']} processos"
    )


if __name__ == "__main__":
    main()
