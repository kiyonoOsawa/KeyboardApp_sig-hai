# On-device WRIME Resources

このフォルダに Core ML モデルとトークナイザを置きます。

## 生成（必須・1回）

conda の Python（torch 入り）で:

```bash
cd SentimentAnalysis
/opt/miniconda3/bin/python export_coreml.py
```

生成物:

- `WRIMESentiment.mlpackage` ← これがないとアプリは「モデル未配置」
- `tokenizer/`

## その後

1. Xcode → **Product → Clean Build Folder**
2. メインアプリを再ビルド／実行

キーボード拡張にはこの Resources を含めません（メモリ制限のため）。
分析はメインアプリ起動時に端末内で行います。
