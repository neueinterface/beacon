# MLX catalog expansion — October 17, 2026

Beacon's catalog expands from 15 to 50 entries (36 text and 14 vision). This is a curated expansion, **not an exhaustive list of every iPhone-capable Hub upload**. There are many fine-tunes, quantizations, duplicates, and new uploads. No physical-device inference or memory tests were performed during this audit.

## Added options

| Company | Added models |
| --- | --- |
| Alibaba | Qwen2.5 Instruct 0.5B, 1.5B, 3B; Coder 0.5B, 1.5B; Math 1.5B; Qwen3 4B Thinking; Qwen3.5 0.8B, 2B, 4B; Qwen3-VL 2B, 4B; Qwen2.5-VL 3B |
| Google | Gemma 1.1 2B, Gemma 2 2B, Gemma 3 4B vision, Gemma 3n E2B text-only, Gemma 4 E2B vision |
| Meta | Llama 3.2 3B Instruct |
| Microsoft | Phi 4 Mini Instruct and Mini Reasoning |
| Liquid AI | LFM2 2.6B, LFM2.5 2.6B and 1.2B Thinking; LFM2-VL 450M and 1.6B; LFM2.5-VL 1.6B |
| Hugging Face | SmolLM 135M, 360M, 1.7B Instruct |
| TII | Falcon H1 0.5B, 1.5B, 3B Instruct |
| LG AI Research | EXAONE 4.0 1.2B, including Korean/English support |
| Mistral AI | Ministral 3 3B Instruct, including vision |

## Checks performed

For all 50 entries, the audit checked the public Hub model API, `config.json`, tokenizer configuration, and image-processor configuration where applicable:

- Repository is accessible without a token or gated-access flow.
- Model architecture appears in the pinned **mlx-swift-lm 3.31.3** LLM/VLM registry.
- Image processor appears in that runtime's processor registry.
- Standalone `tokenizer.json`, chat template (inline or Jinja), and safetensors files exist.
- Download size is measured using the runtime's `*.safetensors`, `*.json`, and `*.jinja` patterns, excluding unrelated demo/training files.
- The evidence file records repository commit IDs, timestamps, architecture, processor, quantization, sizes, and advertised license metadata.

The runtime now uses registered per-model configurations where available, preserving supplied stop-token and tokenizer overrides instead of discarding them for generic configurations.

## Important limits

- Architecture registration and file availability do **not** prove that a tokenizer/template/weight conversion generates correctly or fits any particular iPhone. On-device load, image handling, generation, cancellation, long-context, and memory-pressure tests are still required before claiming device validation.
- Gemma 4 E2B is about **3.6 GB** with about **5.1B total parameters** in this conversion. Gemma 3n E2B text-only is about **2.55 GB** with about **4.46B total parameters**. Effective-capacity names are not RAM requirements. Both remain subject to memory warnings.
- Larger multimodal models are offered as manual choices, not added automatically to Chat Core. Existing onboarding bundles and persisted model IDs remain unchanged.
- Audio, embeddings/rerankers, base-only models without a chat template, very large models/MoEs, and duplicate precision/optimization variants were not added in this pass.
- Original SmolVLM2 500M is not a 4-bit conversion. All 35 new entries are 4-bit conversions.
- Public, ungated access does not waive upstream licenses. Review upstream model cards and license terms, especially Gemma, Llama, and EXAONE, for the intended use. No license-compliance determination was made here.

## Reproducing the audit

```sh
python3 scripts/audit_model_catalog.py \
  --runtime-checkout /path/to/mlx-swift-lm
```

The script downloads only metadata/configuration, not model weights. It writes `reports/model-catalog-audit.json` and exits unsuccessfully if any prerequisites fail. Source URLs and resolved commit IDs are in that report. Live marketplace metadata is fetched only for the selected tab to avoid making roughly 100 Hub requests when the marketplace opens.
