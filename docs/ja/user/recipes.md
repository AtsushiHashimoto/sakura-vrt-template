# レシピ集

この設計（GHCR イメージ + `/workspace` 永続化 + 停止運用）に基づいた典型的なパターン集です。

---

## 1. 学習して自動停止

夜間バッチや長時間学習に。学習が終わると GPU 料金が自動でゼロになります。

```bash
# VRT ホスト上（Docker の外）で実行
docker run --rm \
  --gpus all \
  --shm-size 16g \
  -v /workspace:/workspace \
  ghcr.io/sinix/<your-project>:v1.0 \
  python train.py --output-dir /workspace/checkpoints \
&& sudo shutdown -h now
```

> `&&` により train.py が **正常終了した場合のみ** シャットダウンします。
> 失敗した場合はサーバーが停止せず、ログを確認できます。

---

## 2. チェックポイントから学習を再開

停止 → 再起動後も `/workspace` のデータは残っています。

```bash
docker run --rm \
  --gpus all \
  --shm-size 16g \
  -v /workspace:/workspace \
  ghcr.io/sinix/<your-project>:v1.0 \
  python train.py \
    --resume /workspace/checkpoints/checkpoint_epoch50.pt \
    --output-dir /workspace/checkpoints \
&& sudo shutdown -h now
```

---

## 3. ハイパーパラメータ探索（連続実行）

複数の設定を順に回して、終わったら停止します。

```bash
docker run --rm \
  --gpus all \
  -v /workspace:/workspace \
  ghcr.io/sinix/<your-project>:v1.0 \
  bash -c "
    python train.py --lr 1e-3 --output-dir /workspace/results/lr1e-3 &&
    python train.py --lr 3e-4 --output-dir /workspace/results/lr3e-4 &&
    python train.py --lr 1e-4 --output-dir /workspace/results/lr1e-4
  " \
&& sudo shutdown -h now
```

---

## 4. マルチ GPU（単一ノード）

H100 プランは 1 サーバー 1 GPU ですが、将来的に複数 GPU プランが利用可能になった場合や `torchrun` のテスト用。

```bash
docker run --rm \
  --gpus all \
  --shm-size 64g \
  --network host \
  -v /workspace:/workspace \
  ghcr.io/sinix/<your-project>:v1.0 \
  torchrun \
    --nproc_per_node=4 \
    train.py --output-dir /workspace/checkpoints \
&& sudo shutdown -h now
```

---

## 5. リモートからサーバーを停止（usacloud）

ローカル PC から VRT サーバーを停止します。学習完了をログで確認後に止める場合などに。

```bash
# Install usacloud on your local PC
brew install sacloud/homebrew-usacloud/usacloud  # macOS

# Stop server
usacloud server shutdown <server-name> --zone=is1a

# Check server status
usacloud server list --zone=is1a
```

---

## 6. 新しいイメージをビルドして GHCR に push

Dockerfile を変更したときの手順。VRT サーバー上で実行します。

```bash
# On VRT host
docker build -t ghcr.io/sinix/<your-project>:v1.1 .
docker push ghcr.io/sinix/<your-project>:v1.1
```

`devcontainer.json` のイメージタグを `v1.1` に更新してチームに共有します。

---

## 7. miyabi（HPC）への移行

VRT で開発・検証済みのイメージをそのまま miyabi で実行します。環境差異はありません。

```bash
# On miyabi login node
export APPTAINER_DOCKER_USERNAME=<YOUR_GITHUB_USERNAME>
export APPTAINER_DOCKER_PASSWORD=<YOUR_PAT>

# Pull and convert GHCR image to .sif (first time only)
apptainer pull docker://ghcr.io/sinix/<your-project>:v1.0

# Submit SLURM job
sbatch job.sh
```

```bash
# job.sh
#!/bin/bash
#SBATCH --job-name=my-experiment
#SBATCH --nodes=1
#SBATCH --gpus-per-node=4
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x-%j.out

apptainer exec --nv \
  --bind /path/to/data:/workspace \
  your-project_v1.0.sif \
  python train.py --output-dir /workspace/results
```

`.sif` ファイルは同じバージョンなら再利用できます。イメージを更新した場合のみ再 pull が必要です。

---

## 8. devcontainer（VSCode）と docker run の対応

VSCode で開発した内容をそのまま CLI で実行できます。同じイメージを使うため環境差異はゼロです。

| devcontainer.json | docker run |
|---|---|
| `"image": "ghcr.io/sinix/proj:v1.0"` | `ghcr.io/sinix/proj:v1.0` |
| `"runArgs": ["--gpus", "all"]` | `--gpus all` |
| `"mounts": ["source=/workspace,target=/workspace,type=bind"]` | `-v /workspace:/workspace` |
| `"runArgs": ["--shm-size", "16g"]` | `--shm-size 16g` |

---

## 9. ローカル PC へのバックアップ

長期実験中や、サーバー削除前に重要な成果物をローカルに保存します。

```bash
# ~/.ssh/config に sakura-vrt を設定済みの前提

# チェックポイント全体をバックアップ
rsync -avz --progress \
  sakura-vrt:/workspace/checkpoints/ \
  ./backups/checkpoints/

# 実験結果のみバックアップ
rsync -avz --progress \
  sakura-vrt:/workspace/results/ \
  ./backups/results/

# 特定のファイルだけ
scp sakura-vrt:/workspace/checkpoints/checkpoint_epoch100.pt ./
```

`rsync` は差分転送なので、2 回目以降は変更分だけ送られ高速です。

### 定期バックアップ（cron）

ローカル PC の cron に登録して自動バックアップも可能です。

```bash
# crontab -e に追加（毎日 23:00 にバックアップ）
0 23 * * * rsync -az sakura-vrt:/workspace/results/ ~/backups/vrt-results/
```

---

## 10. NVMe キャッシュの活用（H100 専用・V100 では不可）

H100 では `/mnt/nvme` に 6.9 TiB の高速 NVMe があります。停止で消えますが、速度が最優先の用途に使えます。

### HuggingFace・PyTorch キャッシュ（自動設定済み）

`setup_storage.sh` が自動で環境変数を設定するため、コード変更は不要です。

```bash
echo $HF_HOME       # /mnt/nvme/.cache/huggingface
echo $TORCH_HOME    # /mnt/nvme/.cache/torch
```

モデルのダウンロードは 10 Gbps ネットワーク経由で NVMe に直接書かれます。停止で消えますが、次回起動時に再ダウンロードされます。

### 大規模データセットの一時展開

学習中だけ使う大容量データセットは NVMe に展開すると I/O が高速になります。

```bash
# コンテナ外（VRT ホスト）でデータを NVMe に展開
tar -xf /workspace/dataset.tar.gz -C /mnt/nvme/

# コンテナ起動時に NVMe のデータセットをマウント
docker run --rm \
  --gpus all \
  -v /workspace:/workspace \
  -v /mnt/nvme:/nvme \
  ghcr.io/sinix/<your-project>:v1.0 \
  python train.py \
    --data-dir /nvme/dataset \
    --output-dir /workspace/checkpoints \
&& sudo shutdown -h now
```

> データセットの圧縮ファイルは `/workspace` に置き、展開先を NVMe にする運用が基本です。
> 停止で展開済みデータは消えますが、圧縮元は `/workspace` に残ります。

### NVMe の残量確認

```bash
df -h /mnt/nvme
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/nvme0n1p3  4.9T   80G  4.8T   2% /mnt/nvme
```
