import argparse
import json
import sys


def verify(seq_manifest_path: str, par_manifest_path: str) -> bool:
    with open(seq_manifest_path) as f:
        seq = json.load(f)["manifest"]
    with open(par_manifest_path) as f:
        par = json.load(f)["manifest"]

    if seq.keys() != par.keys():
        only_seq = seq.keys() - par.keys()
        only_par = par.keys() - seq.keys()
        print("FALHA: conjuntos de arquivos diferentes.")
        if only_seq:
            print(f"  só na sequencial: {sorted(only_seq)[:5]}...")
        if only_par:
            print(f"  só na paralela: {sorted(only_par)[:5]}...")
        return False

    mismatches = [
        fname for fname in seq
        if seq[fname]["md5"] != par[fname]["md5"]
    ]

    if mismatches:
        print(f"FALHA: {len(mismatches)} imagem(ns) com hash diferente:")
        for fname in mismatches[:10]:
            print(f"  {fname}: seq={seq[fname]['md5']} par={par[fname]['md5']}")
        return False

    print(f"OK: {len(seq)} imagens, hash idêntico entre sequencial e paralelo.")
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seq", type=str, default="results_sequential.json")
    parser.add_argument("--par", type=str, default="results_parallel.json")
    args = parser.parse_args()

    ok = verify(args.seq, args.par)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
