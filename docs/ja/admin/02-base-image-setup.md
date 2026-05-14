# 管理者セットアップ：マイアーカイブ作成

**チームで1回だけ実施**する手順です。作成したマイアーカイブをメンバー全員が使います。

NVIDIA Driver の更新時など環境の更新が必要な場合のみ再作成してください。

---

## 1. ベースサーバーを起動

1. コントロールパネル → **石狩第1ゾーン**を選択
2. サーバー作成
3. アーカイブ選択：**「Ubuntu 24.04 LTS 64bit (cloudimg)」**
4. プラン：高火力 VRT(GPU) H100
5. ディスクサイズ：20 GB（マイアーカイブ用の最小サイズ）
6. SSH 公開鍵を設定
7. サーバー名：`base-image-builder`
8. 作成・起動

---

## 2. SSH 接続

```bash
ssh ubuntu@<サーバーIPアドレス>
```

---

## 3. 必要パッケージのインストール

```bash
sudo apt-get update
sudo apt-get install -y gdisk
```

---

## 4. NVIDIA Driver インストール

```bash
# Verify GPU is recognized
lspci | grep -i nvidia

# Add CUDA repository
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# Install driver only (CUDA Toolkit goes in the container, not the host)
sudo apt-get install -y cuda-drivers

# Reboot to load driver
sudo reboot
```

再起動後に再度 SSH 接続して確認：

```bash
nvidia-smi
# GPU 情報が表示されれば OK
```

---

## 5. Docker Engine + nvidia-container-toolkit インストール

```bash
# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu

# Install nvidia-container-toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker

# Disable Docker auto-start (setup-storage.service starts Docker after storage is ready)
sudo systemctl disable docker.service docker.socket
```

---

## 6. sudoers 設定

```bash
echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/ubuntu-nopasswd
sudo chmod 440 /etc/sudoers.d/ubuntu-nopasswd
```

---

## 7. ストレージセットアップスクリプトの配置

```bash
sudo mkdir -p /opt/vrt
sudo curl -fsSL https://raw.githubusercontent.com/<your-org>/<your-repo>/main/scripts/setup_storage.sh \
  -o /opt/vrt/setup_storage.sh
sudo curl -fsSL https://raw.githubusercontent.com/<your-org>/<your-repo>/main/scripts/shutdown_storage.sh \
  -o /opt/vrt/shutdown_storage.sh
sudo chmod +x /opt/vrt/setup_storage.sh /opt/vrt/shutdown_storage.sh
```

または手動でコピー：

```bash
sudo tee /opt/vrt/setup_storage.sh > /dev/null < scripts/setup_storage.sh
sudo tee /opt/vrt/shutdown_storage.sh > /dev/null < scripts/shutdown_storage.sh
sudo chmod +x /opt/vrt/setup_storage.sh /opt/vrt/shutdown_storage.sh
```

---

## 8. systemd サービスの登録

```bash
sudo curl -fsSL https://raw.githubusercontent.com/<your-org>/<your-repo>/main/scripts/setup-storage.service \
  -o /etc/systemd/system/setup-storage.service

# または手動でコピー
sudo cp scripts/setup-storage.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable setup-storage.service
```

これにより起動時に `setup_storage.sh` が自動実行され、ストレージ準備後に Docker が起動します。

---

## 9. 動作確認

```bash
# Manually run setup to verify (safe to run multiple times)
sudo /opt/vrt/setup_storage.sh

# Verify workspace is mounted
mountpoint /workspace

# Verify Docker is running and can access GPU
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi

# Check dm-cache status (H100 only)
sudo dmsetup status vrt-workspace
```

---

## 10. マイアーカイブとして保存

1. コントロールパネルでサーバーを**停止**
2. サーバーの「ディスク」タブ → 「アーカイブに変換」
3. アーカイブ名：`base-v1-ubuntu2404`（日付不要、バージョン番号で管理）
4. 変換完了後、元のサーバーを**削除**

> アーカイブは約1円/GB/日で保存できます（20GB で月約600円）。

---

## アーカイブのバージョン管理

マイアーカイブは **1本前のバージョンのみ残し、それより古いものは削除**してください。

| バージョン | 状態 | 対応 |
|-----------|------|------|
| v3（最新） | 運用中 | 残す |
| v2（直前） | 緊急ロールバック用 | 1週間後に削除 |
| v1（それ以前） | 不要 | 即削除 |

古いアーカイブを保持しても固定費が増えるだけです（20GB で月約600円/本）。スクリプト（このドキュメント）が再作成の手順書なので、バイナリを手元に保存する必要はありません。

### 削除忘れ防止：Issue を立てる

新バージョンが動作確認できたら、旧バージョン削除用の Issue を作成してください。

```bash
gh issue create \
  --title "マイアーカイブ旧バージョン削除: base-v{N}-ubuntu2404" \
  --body "新バージョン v{N+1} の動作確認が取れたため、v{N} を削除する。
- [ ] さくらのクラウド コントロールパネル → アーカイブ → \`base-v{N}-ubuntu2404\` を削除" \
  --label "chore"
```

Issue のマイルストーンを**作成日から1週間後**に設定しておくと見落としを防げます。

---

## 更新が必要なタイミング

- NVIDIA Driver の新バージョンが必要になったとき
- Docker の大型アップデート時
- `setup_storage.sh` の変更時

更新時は同じ手順で新しいマイアーカイブを作成し、バージョン番号（`v2` 等）で区別してください。
