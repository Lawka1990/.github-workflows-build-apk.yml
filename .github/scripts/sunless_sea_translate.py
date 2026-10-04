#!/usr/bin/env python3
import csv, hashlib, json, os, re, sys, time
from pathlib import Path
from collections import defaultdict
import requests
import sentencepiece as spm
import ctranslate2
from huggingface_hub import snapshot_download
from rapidfuzz.fuzz import ratio as fuzz_ratio

OUT = Path("sunless_sea_pl_build")
SRC = OUT / "source"
OUT.mkdir(exist_ok=True)
SRC.mkdir(exist_ok=True)

BASE = "https://raw.githubusercontent.com/Enneagon/SunlessSeaRewritten/master/Sunless%20Sea%20Rewritten/"
FILES = [
    "entities/events.json",
    "entities/qualities.json",
    "entities/exchanges.json",
    "entities/areas.json",
    "encyclopaedia/SpawnedEntities.json",
    "encyclopaedia/CombatItems.json",
    "encyclopaedia/CombatAttacks.json",
    "encyclopaedia/Associations.json",
    "geography/Tiles.json",
    "geography/TileRules.json",
    "geography/TileSets.json",
]

# Fields whose contents can be translated in the add-on JSON without changing engine identifiers.
SAFE_FIELDS = {
    "Description", "Teaser", "ButtonText", "MoveMessage",
    "ChangeDescriptionText", "LevelDescriptionText", "LevelImageText",
    "Label", "HumanName", "Tooltip", "BuyMessage", "SellMessage",
}
# Some files use Name only as visible text and are safe enough for direct localization.
SAFE_NAME_FILES = {
    "encyclopaedia/Tutorials.json",
}
# Names from every file are translated into a separate UI dictionary, but not necessarily
# written back into engine JSON. This gives us a safe display-name translation layer.
UI_NAME_FIELDS = {"Name"}

TECH_TOKEN = re.compile(
    r"(\[[A-Z][A-Z0-9_]*\]|\[[qd]:[^\]]+\]|<[^>]+>|\{[^{}]+\}|¤¤P\d+¤¤)"
)
WORD_RE = re.compile(r"[A-Za-zÀ-ž]+")
EN_COMMON = set("the a an and or but if then this that these those is are was were be been being to of in on at from for with without by as it its you your we our they their he she his her not no yes can could will would should may might do does did have has had".split())

# Terms whose spelling is part of the setting and should survive MT.
PROTECTED_TERMS = {
    "Unterzee": "Unterzee",
    "the Unterzee": "Unterzee",
    "Neath": "Neath",
}
# Post-edit glossary. Only exact/case-insensitive occurrences are replaced; inflected
# forms are handled by later grammar fixes where possible.
GLOSSARY = [
    ("Fallen London", "Upadły Londyn"),
    ("Tomb-Colonies", "Kolonie Grobowe"),
    ("Tomb-Colonist", "Kolonista Grobowy"),
    ("Clay Men", "Gliniani Ludzie"),
    ("Port Report", "Raport Portowy"),
    ("Strategic Information", "Informacje Strategiczne"),
    ("Vital Intelligence", "Kluczowe Dane Wywiadowcze"),
    ("Admiralty", "Admiralicja"),
    ("Drydock", "Suchy Dok"),
]

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()

def download(rel):
    dst = SRC / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    urls = [BASE + rel, BASE.replace("https://", "http://") + rel]
    last = None
    for u in urls:
        try:
            r = requests.get(u, timeout=90)
            r.raise_for_status()
            dst.write_bytes(r.content)
            print(f"DOWNLOADED {rel} {len(r.content)} bytes")
            return dst
        except Exception as e:
            last = e
            print(f"WARN download {u}: {e}")
    raise RuntimeError(f"Could not download {rel}: {last}")

def visible_text(s):
    if not isinstance(s, str):
        return False
    t = s.strip()
    if not t:
        return False
    if t.startswith("http://") or t.startswith("https://"):
        return False
    if re.fullmatch(r"[-+]?\d+(?:\.\d+)?", t):
        return False
    return bool(re.search(r"[A-Za-z]", t))

def looks_human_name(s):
    if not visible_text(s):
        return False
    t = s.strip()
    # Avoid obvious identifiers / asset keys.
    if re.fullmatch(r"[A-Z0-9_\-]+", t):
        return False
    if re.fullmatch(r"[A-Za-z]+(?:[A-Z][A-Za-z0-9]*){2,}", t):
        return False
    if any(x in t for x in ("http://", "https://", ".png", ".jpg", ".prefab", "/")):
        return False
    return True

def walk(obj, rel, path=()):
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = path + (str(k),)
            if isinstance(v, str):
                safe = k in SAFE_FIELDS or (k == "Name" and rel in SAFE_NAME_FILES)
                ui_name = k in UI_NAME_FIELDS and looks_human_name(v)
                if safe and visible_text(v):
                    yield ("safe", v, rel, "/".join(p))
                if ui_name and visible_text(v):
                    yield ("ui", v, rel, "/".join(p))
            else:
                yield from walk(v, rel, p)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk(v, rel, path + (str(i),))

def protect_terms(text):
    # Use private Unicode markers unlikely to occur naturally.
    repl = {}
    out = text
    idx = 0
    for src, target in sorted(PROTECTED_TERMS.items(), key=lambda x: -len(x[0])):
        pat = re.compile(re.escape(src), re.I)
        while True:
            m = pat.search(out)
            if not m:
                break
            key = f"¤¤P{idx}¤¤"
            repl[key] = target
            out = out[:m.start()] + key + out[m.end():]
            idx += 1
    return out, repl

def restore_terms(text, repl):
    out = text
    for k, v in repl.items():
        out = out.replace(k, v)
        # Some tokenizers may insert spaces around the marker.
        out = out.replace(k.replace("¤¤", "¤ ¤"), v)
    return out

def split_technical(text):
    parts = []
    last = 0
    for m in TECH_TOKEN.finditer(text):
        if m.start() > last:
            parts.append(("text", text[last:m.start()]))
        parts.append(("tech", m.group(0)))
        last = m.end()
    if last < len(text):
        parts.append(("text", text[last:]))
    return parts or [("text", text)]

def split_long_text(text, max_chars=420):
    if len(text) <= max_chars:
        return [text]
    chunks = []
    # Preserve whitespace after sentences as part of chunks.
    pieces = re.split(r"(?<=[.!?])(?=\s)", text)
    cur = ""
    for p in pieces:
        if len(cur) + len(p) <= max_chars:
            cur += p
        else:
            if cur:
                chunks.append(cur)
            if len(p) <= max_chars:
                cur = p
            else:
                # Fallback for very long sentence: split on semicolon/comma boundaries.
                subs = re.split(r"(?<=[;,:])(?=\s)", p)
                cur = ""
                for q in subs:
                    if len(cur) + len(q) <= max_chars:
                        cur += q
                    else:
                        if cur:
                            chunks.append(cur)
                        if len(q) > max_chars:
                            for i in range(0, len(q), max_chars):
                                chunks.append(q[i:i+max_chars])
                            cur = ""
                        else:
                            cur = q
    if cur:
        chunks.append(cur)
    return chunks

def load_ct2(repo_id):
    model_dir = snapshot_download(repo_id=repo_id)
    model_dir = Path(model_dir)
    src_spm = next(iter(model_dir.glob("*source*.spm")), None)
    tgt_spm = next(iter(model_dir.glob("*target*.spm")), None)
    if not src_spm or not tgt_spm:
        spms = list(model_dir.glob("*.spm"))
        if len(spms) >= 2:
            src_spm, tgt_spm = spms[0], spms[1]
    if not src_spm or not tgt_spm:
        raise RuntimeError(f"SentencePiece files not found in {repo_id}: {list(model_dir.iterdir())}")
    src = spm.SentencePieceProcessor(model_file=str(src_spm))
    tgt = spm.SentencePieceProcessor(model_file=str(tgt_spm))
    tr = ctranslate2.Translator(str(model_dir), device="cpu", compute_type="int8", inter_threads=1, intra_threads=max(2, os.cpu_count() or 2))
    return tr, src, tgt

def translate_batch(texts, tr, src_sp, tgt_sp, beam=2):
    encoded = [src_sp.encode(t, out_type=str) for t in texts]
    results = tr.translate_batch(
        encoded,
        beam_size=beam,
        max_decoding_length=600,
        repetition_penalty=1.08,
        max_batch_size=64,
    )
    return [tgt_sp.decode(r.hypotheses[0]).strip() for r in results]

def norm_similarity(a, b):
    def n(s):
        s = s.lower()
        s = re.sub(r"[^a-z0-9 ]+", " ", s)
        s = re.sub(r"\s+", " ", s).strip()
        return s
    return fuzz_ratio(n(a), n(b))

def glossary_cleanup(src, pl):
    out = pl
    # Setting terms that MT often leaves in English.
    for en, pol in GLOSSARY:
        out = re.sub(re.escape(en), pol, out, flags=re.I)
    # Common grammatical repairs after replacing "Fallen London".
    fixes = [
        (r"\bw Upadły Londyn\b", "w Upadłym Londynie"),
        (r"\bwe Upadły Londyn\b", "w Upadłym Londynie"),
        (r"\bdo Upadły Londyn\b", "do Upadłego Londynu"),
        (r"\bz Upadły Londyn\b", "z Upadłego Londynu"),
        (r"\bze Upadły Londyn\b", "z Upadłego Londynu"),
        (r"\bUpadły Londynem\b", "Upadłym Londynem"),
    ]
    for pat, rep in fixes:
        out = re.sub(pat, rep, out, flags=re.I)
    # Typographic cleanup.
    out = re.sub(r"\s+([,.;:!?])", r"\1", out)
    out = re.sub(r"([«„])\s+", r"\1", out)
    out = re.sub(r"\s+([»”])", r"\1", out)
    out = re.sub(r"[ \t]{2,}", " ", out)
    return out.strip()

def english_fraction(s):
    words = [w.lower() for w in WORD_RE.findall(s)]
    if not words:
        return 0.0
    hits = sum(1 for w in words if w in EN_COMMON)
    return hits / len(words)

def main():
    docs = {}
    source_hashes = {}
    failed_sources = {}
    contexts = defaultdict(list)
    types = defaultdict(set)
    for rel in FILES:
        try:
            p = download(rel)
            source_hashes[rel] = sha256(p)
        except Exception as e:
            failed_sources[rel] = str(e)
            print(f"SKIP UNAVAILABLE SOURCE {rel}: {e}")
            continue
        raw_text = p.read_text(encoding="utf-8-sig", errors="replace")
        try:
            doc = json.loads(raw_text)
            docs[rel] = doc
            recovered = walk(doc, rel)
        except Exception as e:
            failed_sources[rel] = "malformed mirror; regex recovery used: " + str(e)
            print(f"MALFORMED MIRROR {rel}; recovering text fields with regex: {e}")
            recovered = extract_fields_from_malformed_json(raw_text, rel)
        for typ, src_text, r, path in recovered:
            contexts[src_text].append({"file": r, "path": path, "type": typ})
            types[src_text].add(typ)

    strings = sorted(contexts, key=lambda x: (len(x), x))
    print(f"UNIQUE SOURCE STRINGS: {len(strings)}")

    # Build segment graph while preserving technical tokens and line breaks.
    string_plan = {}
    segments = []
    for s in strings:
        protected, prepl = protect_terms(s)
        plan = []
        for typ, part in split_technical(protected):
            if typ == "tech":
                plan.append(("raw", part))
                continue
            # Preserve newlines exactly.
            lineparts = re.split(r"(\r?\n)", part)
            for lp in lineparts:
                if lp in ("\n", "\r\n"):
                    plan.append(("raw", lp))
                elif not lp.strip():
                    plan.append(("raw", lp))
                else:
                    for chunk in split_long_text(lp):
                        idx = len(segments)
                        segments.append(chunk)
                        plan.append(("seg", idx))
        string_plan[s] = (plan, prepl)

    # Deduplicate translation segments.
    seg_to_uid = {}
    unique_segs = []
    seg_uid = []
    for seg in segments:
        if seg not in seg_to_uid:
            seg_to_uid[seg] = len(unique_segs)
            unique_segs.append(seg)
        seg_uid.append(seg_to_uid[seg])
    print(f"UNIQUE MT SEGMENTS: {len(unique_segs)}")

    enpl, ensp, plsp = load_ct2("rohanksaxena/opus-mt-en-pl")
    pl_en, plsp2, ensp2 = load_ct2("rohanksaxena/opus-mt-pl-en")

    pl_segments = [""] * len(unique_segs)
    batch = 48
    for i in range(0, len(unique_segs), batch):
        arr = unique_segs[i:i+batch]
        trans = translate_batch(arr, enpl, ensp, plsp, beam=2)
        pl_segments[i:i+len(trans)] = trans
        if i % (batch * 20) == 0:
            print(f"EN->PL {i}/{len(unique_segs)}")

    # Round-trip QA. We only retranslate suspicious segments; everything is still scored.
    qa = []
    retry_indices = []
    for i in range(0, len(unique_segs), batch):
        pls = pl_segments[i:i+batch]
        back = translate_batch(pls, pl_en, plsp2, ensp2, beam=2)
        for j, rt in enumerate(back):
            k = i + j
            src = unique_segs[k]
            pl = pls[j]
            score = norm_similarity(src, rt)
            frac = english_fraction(pl)
            len_ratio = len(pl) / max(1, len(src))
            suspicious = (
                score < 44
                or len_ratio < 0.28
                or len_ratio > 3.20
                or (len(src) > 35 and pl.strip().lower() == src.strip().lower())
                or (len(src.split()) >= 8 and frac > 0.38)
            )
            if suspicious:
                retry_indices.append(k)
            qa.append({
                "segment_id": k,
                "score": score,
                "length_ratio": round(len_ratio, 3),
                "english_fraction": round(frac, 3),
                "retry": int(suspicious),
                "source": src,
                "polish_v1": pl,
                "roundtrip_v1": rt,
            })
        if i % (batch * 20) == 0:
            print(f"QA roundtrip {i}/{len(unique_segs)}")

    # Second, stronger decoding for suspicious segments, then retain candidate with better round-trip.
    print(f"SUSPICIOUS SEGMENTS: {len(retry_indices)}")
    qa_by_id = {r["segment_id"]: r for r in qa}
    for base in range(0, len(retry_indices), batch):
        ids = retry_indices[base:base+batch]
        srcs = [unique_segs[k] for k in ids]
        candidates = translate_batch(srcs, enpl, ensp, plsp, beam=6)
        backs = translate_batch(candidates, pl_en, plsp2, ensp2, beam=3)
        for k, cand, rt in zip(ids, candidates, backs):
            old = qa_by_id[k]
            score2 = norm_similarity(unique_segs[k], rt)
            # Prefer better semantic return, but avoid selecting a mostly-English candidate.
            frac2 = english_fraction(cand)
            choose = score2 >= old["score"] + 4 and frac2 <= max(0.25, old["english_fraction"] + 0.05)
            old["polish_v2"] = cand
            old["roundtrip_v2"] = rt
            old["score_v2"] = score2
            old["selected_v2"] = int(choose)
            if choose:
                pl_segments[k] = cand
        if base % (batch * 10) == 0:
            print(f"RETRY {base}/{len(retry_indices)}")

    # Reconstruct full strings.
    tm = {}
    for src, (plan, prepl) in string_plan.items():
        pieces = []
        for typ, val in plan:
            if typ == "raw":
                pieces.append(val)
            else:
                uid = seg_uid[val]
                pieces.append(pl_segments[uid])
        pl = "".join(pieces)
        pl = restore_terms(pl, prepl)
        pl = glossary_cleanup(src, pl)
        tm[src] = pl

    # Static glossary/UI entries that should be stable even if not present in the downloaded build.
    tm.update({
        "Fallen London": "Upadły Londyn",
        "Terror": "Groza",
        "Echoes": "Echa",
        "Fuel": "Paliwo",
        "Supplies": "Zapasy",
        "Crew": "Załoga",
        "Hull": "Kadłub",
        "Veils": "Zasłony",
        "Pages": "Karty",
        "Iron": "Żelazo",
        "Hearts": "Serca",
        "Mirrors": "Lustra",
        "Secret": "Sekret",
        "Secrets": "Sekrety",
        "Port Report": "Raport Portowy",
        "Admiralty": "Admiralicja",
        "Drydock": "Suchy Dok",
        "Unterzee": "Unterzee",
        "Neath": "Neath",
    })

    (OUT / "translation_memory.json").write_text(
        json.dumps(tm, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (OUT / "contexts.json").write_text(
        json.dumps(contexts, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (OUT / "source_hashes.json").write_text(
        json.dumps(source_hashes, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    with (OUT / "qa_segments.csv").open("w", newline="", encoding="utf-8-sig") as f:
        fields = ["segment_id","score","score_v2","length_ratio","english_fraction","retry","selected_v2","source","polish_v1","polish_v2","roundtrip_v1","roundtrip_v2"]
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for r in sorted(qa, key=lambda x: (min(x.get("score",100), x.get("score_v2",100)), x["segment_id"])):
            w.writerow(r)

    # Plain text list of the worst remaining translations for human review.
    worst = sorted(qa, key=lambda r: max(r.get("score",0), r.get("score_v2",0)))[:1000]
    with (OUT / "worst_1000.txt").open("w", encoding="utf-8") as f:
        for r in worst:
            k = r["segment_id"]
            f.write(f"### {k} score={r.get('score')} score2={r.get('score_v2','')}\n")
            f.write("EN: " + unique_segs[k].replace("\n","\\n") + "\n")
            f.write("PL: " + pl_segments[k].replace("\n","\\n") + "\n")
            f.write("RT: " + str(r.get("roundtrip_v2") or r.get("roundtrip_v1","")).replace("\n","\\n") + "\n\n")

    report = {
        "unique_source_strings": len(strings),
        "unique_mt_segments": len(unique_segs),
        "suspicious_segments_retried": len(retry_indices),
        "translation_memory_entries": len(tm),
        "source_hashes": source_hashes,
        "failed_sources": failed_sources,
        "model_en_pl": "rohanksaxena/opus-mt-en-pl",
        "model_pl_en": "rohanksaxena/opus-mt-pl-en",
    }
    (OUT / "build_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
