"""Analyze B4 sample and template for position mapping."""

import sys
from pathlib import Path
import fitz

# Analyze sample form pages 1-2
sample_path = r"C:\Users\FooFangKhai\Downloads\Forms Section\B4 FORM - CRS Self-Certification Form Sample.pdf"
doc = fitz.open(sample_path)
print(f"Sample B4: {doc.page_count} pages\n")

for page_idx in [0, 1]:
    page = doc[page_idx]
    print(f"\n{'='*80}")
    print(f"PAGE {page_idx + 1} (sample)")
    print(f"{'='*80}")
    blocks = page.get_text("dict")["blocks"]
    for b in blocks:
        if "lines" not in b:
            continue
        for line in b["lines"]:
            for span in line["spans"]:
                text = span["text"].strip()
                if text:
                    y = round(span["origin"][1], 1)
                    x = round(span["origin"][0], 1)
                    size = round(span["size"], 1)
                    safe_text = text.encode("ascii", "replace").decode("ascii")
                    print(f"  x={x}, y={y}, size={size}: '{safe_text}'")

doc.close()

# Analyze template form pages 1-2
template_path = r"C:\Users\FooFangKhai\Downloads\Citadel First Application (New Version)\citadel-first\backend\app\templates\vtb_forms\B4_FORM.pdf"
doc2 = fitz.open(template_path)
print(f"\n\nTemplate B4: {doc2.page_count} pages\n")

for page_idx in [0, 1]:
    page = doc2[page_idx]
    print(f"\n{'='*80}")
    print(f"PAGE {page_idx + 1} (template)")
    print(f"{'='*80}")
    blocks = page.get_text("dict")["blocks"]
    for b in blocks:
        if "lines" not in b:
            continue
        for line in b["lines"]:
            for span in line["spans"]:
                text = span["text"].strip()
                if text:
                    y = round(span["origin"][1], 1)
                    x = round(span["origin"][0], 1)
                    size = round(span["size"], 1)
                    safe_text = text.encode("ascii", "replace").decode("ascii")
                    print(f"  x={x}, y={y}, size={size}: '{safe_text}'")

doc2.close()