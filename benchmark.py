import argparse
import json
import os
import time

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from sequential import run_sequential
from parallel import run_parallel
from processing import BLUR_PASSES_DEFAULT


def amdahl_speedup(p: float, n: int) -> float:
    return 1 / ((1 - p) + p / n)


def estimate_p_from_measurement(speedup_measured: float, n: int) -> float:
    if n <= 1:
        return 0.0
    return (1 - 1 / speedup_measured) / (1 - 1 / n)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=str, default="data/input")
    parser.add_argument("--blur-passes", type=int, default=BLUR_PASSES_DEFAULT)
    parser.add_argument("--workers-list", type=str, default="1,2,4,8",
                         help="Lista de números de processos a testar, separados por vírgula")
    parser.add_argument("--out", type=str, default="benchmark_results.json")
    parser.add_argument("--chart-out", type=str, default="speedup_chart.png")
    args = parser.parse_args()

    workers_list = [int(w) for w in args.workers_list.split(",")]

    print("== Rodando versão sequencial (baseline) ==")
    seq = run_sequential(args.input, "data/output_seq", args.blur_passes)
    t_seq = seq["total_time_s"]
    print(f"  T_seq = {t_seq:.3f}s ({seq['processed_count']} imagens)\n")

    rows = []
    for n in workers_list:
        print(f"== Rodando versão paralela com {n} processo(s) ==")
        par = run_parallel(args.input, f"data/output_par_{n}", args.blur_passes, n)
        t_par = par["total_time_s"]
        speedup = t_seq / t_par
        print(f"  T_par({n}) = {t_par:.3f}s  ->  speedup medido = {speedup:.2f}x\n")
        rows.append({"workers": n, "time_s": t_par, "speedup_measured": speedup})

    best = max(rows, key=lambda r: r["workers"])
    p_est = estimate_p_from_measurement(best["speedup_measured"], best["workers"])
    p_est = max(0.0, min(1.0, p_est))

    for row in rows:
        row["speedup_amdahl_predicted"] = amdahl_speedup(p_est, row["workers"])
        row["gap"] = row["speedup_amdahl_predicted"] - row["speedup_measured"]

    result = {
        "t_seq_s": t_seq,
        "n_images": seq["processed_count"],
        "blur_passes": args.blur_passes,
        "p_estimated": p_est,
        "rows": rows,
    }

    with open(args.out, "w") as f:
        json.dump(result, f, indent=2)

    print("== Resumo ==")
    print(f"p estimado (fração paralelizável): {p_est:.3f}")
    print(f"{'workers':>8} {'T(s)':>10} {'speedup medido':>16} {'speedup Amdahl':>16} {'gap':>8}")
    for row in rows:
        print(f"{row['workers']:>8} {row['time_s']:>10.3f} {row['speedup_measured']:>16.2f} "
              f"{row['speedup_amdahl_predicted']:>16.2f} {row['gap']:>8.2f}")

    ns = [r["workers"] for r in rows]
    measured = [r["speedup_measured"] for r in rows]
    predicted = [r["speedup_amdahl_predicted"] for r in rows]

    plt.figure(figsize=(6, 4))
    plt.plot(ns, measured, "o-", label="Speedup medido")
    plt.plot(ns, predicted, "s--", label=f"Amdahl (p={p_est:.2f})")
    plt.plot(ns, ns, ":", color="gray", label="Speedup linear ideal")
    plt.xlabel("Número de processos")
    plt.ylabel("Speedup")
    plt.title("Speedup medido vs. previsto pela lei de Amdahl")
    plt.legend()
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(args.chart_out, dpi=150)
    print(f"\nGráfico salvo em {args.chart_out}")


if __name__ == "__main__":
    main()
