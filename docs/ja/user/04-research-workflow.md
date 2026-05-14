# 研究ワークフロー

---

## 基本的な流れ

```
サーバー起動（または停止中のサーバーを再起動）
  ↓
SSH 接続（/workspace が自動でマウント済み）
  ↓
Dev Container 起動（VSCode）or docker run（CLI）
  ↓
実験・開発（データは /workspace に書く）
  ↓
コードを git push
  ↓
サーバーを「停止」← GPU 料金ゼロ・データは残る
```

**削除はプロジェクト終了時のみです。** 毎回削除する必要はありません。

---

## データの書き先ルール

| データ種別 | 保存先 | 停止後も残る？ |
|---|---|---|
| モデルのチェックポイント | `/workspace/checkpoints/` | ✅ |
| 実験結果・ログ | `/workspace/results/` | ✅ |
| HuggingFace キャッシュ | `$HF_HOME`（自動設定） | H100: ✗ / V100: ✅ |
| コード | Git リポジトリ | ✅（GitHub） |

> H100 の HuggingFace キャッシュはサーバー停止で消えます。次回起動時に自動で再ダウンロードされます（10 Gbps なので高速）。

---

## PyTorch でのチェックポイント保存例

```python
import torch
import os

checkpoint_dir = "/workspace/checkpoints"
os.makedirs(checkpoint_dir, exist_ok=True)

torch.save({
    "epoch": epoch,
    "model_state_dict": model.state_dict(),
    "optimizer_state_dict": optimizer.state_dict(),
}, f"{checkpoint_dir}/checkpoint_epoch{epoch}.pt")
```

---

## 学習終了後にサーバーを自動停止する

長時間の学習を夜間に走らせる場合などに便利です。

```bash
# On VRT host (outside Docker): train inside container, then shut down
docker run --gpus all -v /workspace:/workspace \
  ghcr.io/<your-org>/<your-project>:v1.0 \
  python train.py --output-dir /workspace/checkpoints \
&& sudo shutdown -h now
```

または usacloud（さくら公式 CLI）からリモートで停止することもできます。

```bash
# From your local PC
usacloud server shutdown <server-name> --zone=is1a
```

---

## Dockerfile の更新・イメージの再ビルド

環境に変更が必要になったら Dockerfile を更新して GHCR に push します。

```bash
# On VRT server (outside Docker)
docker build -t ghcr.io/<your-org>/<your-project>:v1.1 .
docker push ghcr.io/<your-org>/<your-project>:v1.1
```

`devcontainer.json` のイメージタグを更新してチームに共有します。

---

## プロジェクト終了時（サーバーを削除する場合）

削除するとシステムディスクのデータが消えます。必要なデータをローカル PC に保存してください。

```bash
# Download results to local PC before deletion
scp -r sakura-vrt:/workspace/results ./local-results
scp -r sakura-vrt:/workspace/checkpoints/final.pt ./
```

### 削除前チェックリスト

```
□ 重要な成果物をローカル PC に scp 済み
□ コードを git push 済み
□ GHCR のイメージが最新 push 済み（必要な場合）
```

### 削除手順

1. コントロールパネルでサーバーを選択
2. 「削除」→ システムディスクも合わせて削除

---

## コスト確認

コントロールパネルの「利用料金管理」で当月の利用状況を確認できます。料金アラートが来たら必ず確認してください。
