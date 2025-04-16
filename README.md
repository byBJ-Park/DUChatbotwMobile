# 모바일 환경 음성 기반 PEFT-RAG 로컬 챗봇

> PEFT(LoRA)와 RAG 방식을 혼합한 하이브리드 챗봇 모델  
> Android / iOS 환경에서 음성으로 동작하는 로컬 챗봇 구현

---

## 개요

본 프로젝트는 **동서울대학교 안내 챗봇**을 모바일 환경에서 구현한 연구입니다.  
사용자의 편의성을 위해 **음성 인식(STT)** 및 **음성 합성(TTS)** 기능을 적용했으며,  
**PEFT(LoRA)**, **RAG**, 그리고 두 방식을 결합한 **Hybrid 모델**을 비교 평가했습니다.

---

## 응용된 기술

| 기술 | 설명 |
|------|------|
| LLM | LLaMA 3.2 8B 모델 |
| PEFT | LoRA를 활용한 파라미터 효율적 미세조정 |
| RAG | 검색 기반 응답 생성으로 최신성 및 정확성 확보 |
| STT | 음성 명령을 텍스트로 변환 (Android/iOS 대응) |
| TTS | 텍스트 응답을 음성으로 변환 |
| Client | Android & iOS 앱에서 로컬 챗봇 동작 지원 |

---

## 시스템 구성도
![image](https://github.com/user-attachments/assets/173bca10-a6da-4cec-9289-14e2e5f9b7ce)
> RAG 기반 응답 생성 + STT/TTS 클라이언트 구성  

---

## 성능 비교

![image](https://github.com/user-attachments/assets/0a3fbfad-dc38-45a6-ad16-3664557280da)

- 평가 데이터: 웹 크롤링으로 수집한 동서울대 Q/A 720쌍  
- 성능 지표: BLEU, METEOR, ROUGE  
- Hybrid 모델이 가장 우수한 결과를 보임

---

## 클라이언트 STT/TTS 구성

| 플랫폼   | STT API | TTS API |
|----------|----------|---------|
| Android  | Android SpeechRecognizer | Google TTS |
| iOS      | Apple Speech Framework | AVSpeechSynthesizer |

---

## 결론 및 의의

- 기존 LLM 챗봇의 한계(환각, 최신성 부족 등)를 보완하기 위해 **PEFT + RAG** 결합
- 실시간 정보 반영과 신뢰성 높은 응답이 가능해짐
- 다양한 모바일 환경에서 동작 가능하도록 STT/TTS 포함
- 향후 **대학 외 다양한 안내 챗봇 서비스**로 확장 가능

---

## 참고문헌

1. Vipula Rawte et al., *The Troubling Emergence of Hallucination in LLMs*, arXiv:2310.04988  
2. Edward J. Hu et al., *LoRA: Low-Rank Adaptation of Large Language Models*, arXiv:2106.09685  
3. Patrick Lewis et al., *Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks*, arXiv:2005.11401
