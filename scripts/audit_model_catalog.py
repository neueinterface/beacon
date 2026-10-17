#!/usr/bin/env python3
"""Audit Hub metadata/configs against the pinned runtime; never download weights.

This checks load prerequisites, not iPhone inference or memory reliability.
Run with --runtime-checkout pointing to Xcode's mlx-swift-lm checkout.
"""

import argparse
import concurrent.futures
import fnmatch
import json
from pathlib import Path
import re
from datetime import datetime, timezone
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def get_json(url):
    request = Request(url, headers={"User-Agent": "Beacon-Catalog-Audit", "Accept": "application/json"})
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def registry_types(path):
    return set(re.findall(r'"([^"\n]+)"\s*:\s*create\(', path.read_text()))


def audit(model, llm_types, vlm_types, processor_types):
    repo = model["repositoryID"]
    api = f"https://huggingface.co/api/models/{repo}?blobs=true"
    base = f"https://huggingface.co/{repo}/raw/main/"
    result = {"id": model["id"], "repositoryID": repo, "source": api, "issues": []}
    try:
        metadata = get_json(api)
        config = get_json(base + "config.json")
        tokenizer = get_json(base + "tokenizer_config.json")
        files = metadata.get("siblings", [])
        names = {entry["rfilename"] for entry in files}
        architecture = config.get("model_type")
        vision = model.get("supportsImages", False)
        supported = vlm_types if vision else llm_types
        if architecture not in supported:
            result["issues"].append(f"Unsupported {'vision' if vision else 'text'} architecture: {architecture}")
        if metadata.get("gated") or metadata.get("private"):
            result["issues"].append("Repository needs authentication or license acceptance")
        if "tokenizer.json" not in names:
            result["issues"].append("Missing standalone tokenizer.json")
        if not tokenizer.get("chat_template") and "chat_template.jinja" not in names:
            result["issues"].append("Missing chat template")
        if not any(name.endswith(".safetensors") for name in names):
            result["issues"].append("Missing safetensors weights")
        processor = None
        if vision:
            for filename in ["processor_config.json", "preprocessor_config.json"]:
                if filename in names:
                    processor = get_json(base + filename).get("processor_class")
                    if processor:
                        break
            processor = processor or tokenizer.get("processor_class")
            if processor not in processor_types:
                result["issues"].append(f"Unsupported image processor: {processor}")
        # Match MLXLMCommon's modelDownloadPatterns, not examples/training files.
        selected = [entry for entry in files if any(fnmatch.fnmatch(entry["rfilename"], pattern)
                    for pattern in ["*.safetensors", "*.json", "*.jinja"])]
        byte_count = sum(entry.get("size") or entry.get("lfs", {}).get("size", 0) for entry in selected)
        result.update({
            "revision": metadata.get("sha"),
            "architecture": architecture,
            "processor": processor,
            "quantizationBits": (config.get("quantization") or config.get("quantization_config") or {}).get("bits"),
            "downloadBytes": byte_count,
            "catalogSizeInGB": model["sizeInGB"],
            "parameters": metadata.get("safetensors", {}).get("total"),
            "license": (metadata.get("cardData") or {}).get("license"),
            "lastModified": metadata.get("lastModified"),
        })
    except (HTTPError, OSError, ValueError, KeyError) as error:
        result["issues"].append(str(error))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime-checkout", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, default=Path("beacon/Resources/models.json"))
    parser.add_argument("--output", type=Path, default=Path("reports/model-catalog-audit.json"))
    args = parser.parse_args()
    libraries = args.runtime_checkout / "Libraries"
    llm = registry_types(libraries / "MLXLLM/LLMModelFactory.swift")
    vlm_source = (libraries / "MLXVLM/VLMModelFactory.swift").read_text()
    vlm = set(re.findall(r'"([^"\n]+)"\s*:\s*create\(', vlm_source.split("public enum VLMProcessorTypeRegistry")[0]))
    processors = set(re.findall(r'"([^"\n]+)"\s*:\s*create\(', vlm_source.split("public enum VLMProcessorTypeRegistry")[1]))
    models = [model for model in json.loads(args.catalog.read_text()) if not model["isBuiltIn"]]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(lambda model: audit(model, llm, vlm, processors), models))
    report = {
        "checkedAt": datetime.now(timezone.utc).isoformat(),
        "runtime": "mlx-swift-lm 3.31.3",
        "scope": "Public Hub files, templates, architecture and processor support only. No inference or iPhone memory validation.",
        "models": results,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    failures = [result for result in results if result["issues"]]
    print(f"Audited {len(results)} models; {len(failures)} need attention. Report: {args.output}")
    for result in failures:
        print(result["repositoryID"], "; ".join(result["issues"]))
    raise SystemExit(bool(failures))


if __name__ == "__main__":
    main()
