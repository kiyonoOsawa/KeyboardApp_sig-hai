"""
neuralnaut/deberta-wrime-sentiment を Core ML に変換する。

DeBERTa の Core ML 非対応箇所をパッチしてから変換する:
- scaled_size_sqrt (int32 sqrt)
- build_rpos の if 分岐（固定長 128 では relative_pos をそのまま使う）

使い方:
  /opt/miniconda3/bin/python export_coreml.py
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
import transformers.models.deberta_v2.modeling_deberta_v2 as deberta_v2
from transformers import AutoModelForSequenceClassification, AutoTokenizer

MODEL_NAME = "neuralnaut/deberta-wrime-sentiment"
MAX_LENGTH = 128
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "Shared" / "Sentiment" / "Resources"


def patch_deberta_for_coreml(hidden_size: int, num_attention_heads: int) -> None:
    head_size = hidden_size // num_attention_heads

    def scaled_size_sqrt_fixed(query_layer: torch.Tensor, scale_factor: int):
        value = float(head_size) * float(scale_factor)
        return torch.sqrt(
            torch.tensor(value, dtype=torch.float32, device=query_layer.device)
        )

    # 固定長入力では query/key 長が一致するため分岐不要
    def build_rpos_fixed(query_layer, key_layer, relative_pos, position_buckets: int, max_relative_positions: int):
        return relative_pos

    deberta_v2.scaled_size_sqrt = scaled_size_sqrt_fixed
    deberta_v2.build_rpos = build_rpos_fixed
    print(f"Patched DeBERTa for Core ML (head_size={head_size})")


class TraceableSentimentModel(torch.nn.Module):
    def __init__(self, model: torch.nn.Module) -> None:
        super().__init__()
        self.model = model

    def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
        outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
        return outputs.logits.to(dtype=torch.float32)


def export_tokenizer(tokenizer, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    tokenizer.save_pretrained(dest)
    meta = {
        "model_name": MODEL_NAME,
        "max_length": MAX_LENGTH,
        "tokenizer_class": tokenizer.__class__.__name__,
        "cls_token_id": tokenizer.cls_token_id,
        "sep_token_id": tokenizer.sep_token_id,
        "pad_token_id": tokenizer.pad_token_id if tokenizer.pad_token_id is not None else 0,
        "unk_token_id": tokenizer.unk_token_id,
        "denormalize_scale": 2.0,
        "score_min": -2.0,
        "score_max": 2.0,
    }
    (dest / "wrime_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Tokenizer saved: {dest}")


def export_coreml(model, dest_mlpackage: Path) -> None:
    wrapper = TraceableSentimentModel(model)
    wrapper.eval()

    example_ids = torch.zeros(1, MAX_LENGTH, dtype=torch.long)
    example_mask = torch.ones(1, MAX_LENGTH, dtype=torch.long)

    print("Tracing TorchScript ...")
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, (example_ids, example_mask), strict=False)

    print("Converting to Core ML ...")
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, MAX_LENGTH), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, MAX_LENGTH), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="logits")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS16,
        compute_precision=ct.precision.FLOAT32,
    )
    mlmodel.short_description = "WRIME sentiment polarity (raw logit; multiply by 2 on device)"
    mlmodel.author = MODEL_NAME

    if dest_mlpackage.exists():
        shutil.rmtree(dest_mlpackage)
    dest_mlpackage.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(dest_mlpackage))
    print(f"Core ML saved: {dest_mlpackage}")


def verify_parity(tokenizer, pt_model, mlpackage: Path) -> None:
    text = "今日はとても楽しい一日でした！"
    encoded = tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        max_length=MAX_LENGTH,
        padding="max_length",
    )
    with torch.no_grad():
        pt_logit = pt_model(**encoded).logits.cpu().numpy()[0][0]

    mlmodel = ct.models.MLModel(str(mlpackage))
    ids = encoded["input_ids"].numpy().astype(np.int32)
    mask = encoded["attention_mask"].numpy().astype(np.int32)
    out = mlmodel.predict({"input_ids": ids, "attention_mask": mask})
    logit_key = "logits" if "logits" in out else next(iter(out.keys()))
    ml_logit = float(np.array(out[logit_key]).reshape(-1)[0])

    pt_score = float(np.clip(pt_logit * 2.0, -2.0, 2.0))
    ml_score = float(np.clip(ml_logit * 2.0, -2.0, 2.0))
    print("\n=== parity check ===")
    print(f"text: {text}")
    print(f"PyTorch raw={pt_logit:+.4f} score={pt_score:+.2f}")
    print(f"CoreML  raw={ml_logit:+.4f} score={ml_score:+.2f}")
    print(f"abs diff (score) = {abs(pt_score - ml_score):.4f}")


def main() -> None:
    print(f"Loading {MODEL_NAME} ...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_NAME)
    model.eval()

    patch_deberta_for_coreml(model.config.hidden_size, model.config.num_attention_heads)

    tokenizer_dir = OUTPUT_DIR / "tokenizer"
    mlpackage = OUTPUT_DIR / "WRIMESentiment.mlpackage"

    export_tokenizer(tokenizer, tokenizer_dir)
    export_coreml(model, mlpackage)
    verify_parity(tokenizer, model, mlpackage)

    for leftover in ("WRIMESentiment.onnx",):
        p = OUTPUT_DIR / leftover
        if p.exists():
            p.unlink()
            print(f"Removed {leftover}")

    print("\n完了。Xcode で Product → Clean Build Folder のあと再実行してください。")


if __name__ == "__main__":
    main()
