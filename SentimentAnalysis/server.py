"""
実験用：ローカル感情分析 API（任意）。

端末内 Core ML 運用が主経路です。
Mac 上で Python 検証だけしたい場合に使ってください。

起動:
  python server.py
"""

from __future__ import annotations

from fastapi import FastAPI
from pydantic import BaseModel, Field
import uvicorn

from analyzer import WRIMESentimentAnalyzer

app = FastAPI(title="WRIME Sentiment API", version="1.0.0")
_analyzer: WRIMESentimentAnalyzer | None = None


def get_analyzer() -> WRIMESentimentAnalyzer:
    global _analyzer
    if _analyzer is None:
        _analyzer = WRIMESentimentAnalyzer()
    return _analyzer


class AnalyzeRequest(BaseModel):
    text: str = Field(min_length=1)


class AnalyzeResponse(BaseModel):
    text: str
    score: float
    label: str


@app.on_event("startup")
def load_model() -> None:
    get_analyzer()


@app.get("/")
def root() -> dict[str, object]:
    """ブラウザで開いたときの案内。404 はここが無かったため。"""
    return {
        "service": "WRIME Sentiment API",
        "status": "running",
        "endpoints": {
            "GET /": "この案内",
            "GET /health": "ヘルスチェック",
            "POST /analyze": {"text": "分析したい一文"},
            "GET /docs": "Swagger UI（試し打ち用）",
        },
        "example": {
            "curl": 'curl -X POST http://127.0.0.1:8765/analyze -H "Content-Type: application/json" -d \'{"text":"今日は楽しい"}\'',
        },
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/favicon.ico", include_in_schema=False)
def favicon() -> dict[str, str]:
    return {"status": "no favicon"}


@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(request: AnalyzeRequest) -> AnalyzeResponse:
    result = get_analyzer().analyze(request.text)
    print(result.console_block())
    print()
    return AnalyzeResponse(text=result.text, score=result.score, label=result.label)


if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=8765, reload=False)
