# miyabi で大規模実験する

VRT で開発・小規模実験が完了し、東大 miyabi（JCAHPC）で大規模実験を行う手順です。

---

## 概要

miyabi は HPC クラスター環境です。Docker は使えませんが、**Apptainer** を使うことで GHCR の Docker イメージをそのまま実行できます。

```
GHCR（ghcr.io/<your-org>/<project>:v1.0）
        ↓ apptainer pull
miyabi 上の .sif ファイル
        ↓ apptainer exec --nv
        実行（GPU あり）
```

VRT と miyabi で同じコンテナイメージを使うため、**環境の差異がありません。**

---

## 1. miyabi へのログイン

miyabi のアカウント申請・ログイン手順は [JCAHPC の公式ドキュメント](https://miyabi-www.jcahpc.jp/) を参照してください。

---

## 2. GHCR から Apptainer イメージを pull

```bash
# Set GHCR credentials
export APPTAINER_DOCKER_USERNAME=<YOUR_GITHUB_USERNAME>
export APPTAINER_DOCKER_PASSWORD=<YOUR_PAT>

# Pull and convert Docker image to .sif
apptainer pull \
  docker://ghcr.io/<your-org>/<your-project>:v1.0

# Creates: your-project_v1.0.sif
```

> `.sif` ファイルは数 GB になります。miyabi のホームディレクトリ容量に注意してください。

---

## 3. 動作確認（インタラクティブ）

```bash
# Interactive session with GPU
apptainer exec --nv your-project_v1.0.sif python -c \
  "import torch; print(torch.cuda.is_available())"
# True
```

---

## 4. SLURM ジョブスクリプトの例

```bash
#!/bin/bash
#SBATCH --job-name=my-experiment
#SBATCH --nodes=1
#SBATCH --gpus-per-node=4
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x-%j.out

# Run training inside Apptainer container
apptainer exec --nv \
  --bind /path/to/data:/workspace/data \
  your-project_v1.0.sif \
  python train.py \
    --data-dir /workspace/data \
    --output-dir /workspace/data/results
```

```bash
# Submit job
sbatch job.sh

# Check status
squeue -u $USER
```

---

## VRT との対応関係

| VRT での操作 | miyabi での対応 |
|---|---|
| `docker run --gpus all -v /mnt/data:/workspace/data ...` | `apptainer exec --nv --bind /path/to/data:/workspace/data ...` |
| `/workspace/data/` | `--bind` でマウントした永続ストレージ |
| `/workspace/.cache/` | miyabi のスクラッチ領域 |

---

## 注意事項

- miyabi では Docker を使えません（Apptainer のみ）
- `.sif` ファイルは毎回 pull する必要はありません。同じバージョンなら再利用できます
- イメージを更新した場合は再 pull が必要です（タグで管理しているため `:v1.1` 等で区別）
- miyabi の利用規約・利用申請は所属機関を通じて行ってください
