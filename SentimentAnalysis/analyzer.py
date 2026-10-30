"""
neuralnaut/deberta-wrime-sentiment を使った感情極性分析。
出力スケール: -2.0 〜 +2.0（デノーマライズ後）
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import torch
from transformers import AutoModelForSequenceClassification, AutoTokenizer

MODEL_NAME = "neuralnaut/deberta-wrime-sentiment"


@dataclass
class SentimentResult:
    text: str
    score: float
    label: str

    def console_block(self) -> str:
        bar_position = int((self.score + 2) * 10)
        bar_position = max(0, min(40, bar_position))
        lines = [
            f"テキスト: {self.text}",
            f"感情極性: {self.score:+.2f} ({self.label})",
            "",
            "[-2]────────────────[0]────────────────[+2]",
            " " * bar_position + "▼",
        ]
        return "\n".join(lines)


class WRIMESentimentAnalyzer:
    def __init__(self, model_name: str = MODEL_NAME) -> None:
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModelForSequenceClassification.from_pretrained(model_name)
        self.model.eval()

    @staticmethod
    def label_for_score(score: float) -> str:
        if score <= -1.5:
            return "強いネガティブ"
        if score < -0.5:
            return "ネガティブ"
        if score <= 0.5:
            return "中立"
        if score < 1.5:
            return "ポジティブ"
        return "強いポジティブ"

    @staticmethod
    def denormalize(raw_logit: float) -> float:
        # ⚠️ 重要：デノーマライズ (-1~+1 → -2~+2)
        prediction = float(raw_logit) * 2.0
        return float(np.clip(prediction, -2.0, 2.0))

    def analyze(self, text: str) -> SentimentResult:
        inputs = self.tokenizer(
            text,
            return_tensors="pt",
            truncation=True,
            max_length=128,
        )
        with torch.no_grad():
            outputs = self.model(**inputs)
            raw = outputs.logits.cpu().numpy()[0][0]

        score = self.denormalize(raw)
        label = self.label_for_score(score)
        return SentimentResult(text=text, score=score, label=label)


def visualize_sentiment(text: str, score: float) -> None:
    """感情極性を視覚化（サンプルコードと同じ出力）"""
    label = WRIMESentimentAnalyzer.label_for_score(score)
    print(f"\nテキスト: {text}")
    print(f"感情極性: {score:+.2f} ({label})")

    bar_position = int((score + 2) * 10)
    bar_position = max(0, min(40, bar_position))

    print("\n[-2]────────────────[0]────────────────[+2]")
    print(" " * bar_position + "▼")


if __name__ == "__main__":
    analyzer = WRIMESentimentAnalyzer()
    sample = "今日はとても楽しい一日でした！"
    result = analyzer.analyze(sample)
    print(result.console_block())
