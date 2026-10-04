#!/usr/bin/env python3
import csv,json,os,re
from pathlib import Path
import sentencepiece as spm
import ctranslate2
from huggingface_hub import snapshot_download
from rapidfuzz.fuzz import ratio as fuzz_ratio

ROOT=Path("/tmp/sscn"); OUT=Path("sunless_sea_ui_pl"); OUT.mkdir(exist_ok=True)
CURATED={
"Exit to Desktop","New Game","Options","Load Game","Credits","Quit to Title Screen",
"Start new game","Are you sure?","Continue","Continue...","Close Gazetteer","Story",
"Hold","Journal","Officers","Shops","Shipyard","Your hold","Hold capacity: ",
"Current Officers","Available Officers","You do not have any officers!","Video settings",
"Quality:","Resolution:","Audio settings","SFX Volume:","Music Volume:","Back","Accept",
"Cancel","Delete","Confirm","Save","Manual Save","Autosave","Full Power","Lights","Repair",
"Hull","Crew","Fuel","Supplies","Terror","Echoes","Log Book","Objectives","Cargo","Equipment",
"Messages","BUY","SELL","BUY SHIP","TRADE","Cost:","Trade:","Choose your name","ACCEPT",
"Loading...","Paused","Unpause","Main Menu","Return to Game","Quit","Apply","Yes","No","OK","Done"
}
def dec(s):
    try: return json.loads('"'+s.replace('"','\\\"')+'"')
    except: return s.replace('\\n','\n').replace('\\r','\r').replace('\\t','\t').replace('\\\"','"').replace('\\\\','\\')
def cjk(s): return bool(re.search(r'[\u3400-\u9fff]',s))
def good(s):
    if not s or not re.search(r'[A-Za-z]',s) or len(s)>650: return False
    if s.startswith(("Assets/","Sunless.","UnityEngine.","System.")): return False
    if ("/" in s or "\\" in s) and " " not in s: return False
    return True
pairs={}
for p in ROOT.rglob("*.cs"):
    c=p.read_text(encoding="utf-8-sig",errors="replace")
    regs=[
      r'\[\s*"((?:\\.|[^"\\])*)"\s*\]\s*=\s*"((?:\\.|[^"\\])*)"',
      r'"((?:\\.|[^"\\])*)"\s*,\s*"((?:\\.|[^"\\])*)"'
    ]
    for rg in regs:
      for m in re.finditer(rg,c):
        en,zh=dec(m.group(1)),dec(m.group(2))
        if good(en) and cjk(zh): pairs.setdefault(en,set()).add(str(p.relative_to(ROOT)))
keys=sorted(set(pairs)|CURATED)
print("UI KEYS",len(keys))
def load(repo):
    d=Path(snapshot_download(repo_id=repo)); ss=list(d.glob("*.spm"))
    a=next(iter(d.glob("*source*.spm")),ss[0]); b=next(iter(d.glob("*target*.spm")),ss[1])
    return ctranslate2.Translator(str(d),device="cpu",compute_type="int8",inter_threads=1,intra_threads=max(2,os.cpu_count() or 2)),spm.SentencePieceProcessor(model_file=str(a)),spm.SentencePieceProcessor(model_file=str(b))
def tb(texts,tr,src,tgt,beam=3):
    flat=[]; own=[]
    for i,t in enumerate(texts):
      toks=src.encode(t,out_type=str) or src.encode(" ",out_type=str)
      for j in range(0,len(toks),380): flat.append(toks[j:j+380]); own.append(i)
    rr=tr.translate_batch(flat,beam_size=beam,max_decoding_length=600,max_batch_size=64)
    parts=[[] for _ in texts]
    for i,r in zip(own,rr): parts[i].append(tgt.decode(r.hypotheses[0]).strip())
    return [" ".join(a).strip() for a in parts]
enpl,ens,pls=load("rohanksaxena/opus-mt-en-pl")
plen,pls2,ens2=load("rohanksaxena/opus-mt-pl-en")
out={}; qa=[]
for i in range(0,len(keys),64):
    src=keys[i:i+64]; pl=tb(src,enpl,ens,pls,4); rt=tb(pl,plen,pls2,ens2,3)
    for a,b,c in zip(src,pl,rt):
      sc=fuzz_ratio(re.sub(r'\W+',' ',a.lower()),re.sub(r'\W+',' ',c.lower()))
      out[a]=b
      qa.append((sc,a,b,c,";".join(sorted(pairs.get(a,[])))))
# High-confidence curated Polish UI vocabulary overrides.
out.update({
"Exit to Desktop":"Wyjdź do pulpitu","New Game":"Nowa gra","Options":"Opcje","Load Game":"Wczytaj grę",
"Credits":"Twórcy","Quit to Title Screen":"Wyjdź do ekranu tytułowego","Start new game":"Rozpocznij nową grę",
"Are you sure?":"Czy na pewno?","Continue":"Kontynuuj","Continue...":"Kontynuuj…","Close Gazetteer":"Zamknij dziennik",
"Story":"Opowieść","Hold":"Ładownia","Journal":"Dziennik","Officers":"Oficerowie","Shops":"Sklepy",
"Shipyard":"Stocznia","Your hold":"Twoja ładownia","Hold capacity: ":"Pojemność ładowni: ",
"Current Officers":"Obecni oficerowie","Available Officers":"Dostępni oficerowie",
"You do not have any officers!":"Nie masz żadnych oficerów!","Video settings":"Ustawienia obrazu",
"Quality:":"Jakość:","Resolution:":"Rozdzielczość:","Audio settings":"Ustawienia dźwięku",
"SFX Volume:":"Głośność efektów:","Music Volume:":"Głośność muzyki:","Back":"Wstecz","Accept":"Akceptuj",
"Cancel":"Anuluj","Delete":"Usuń","Confirm":"Potwierdź","Save":"Zapisz","Manual Save":"Zapis ręczny",
"Autosave":"Autozapis","Hull":"Kadłub","Crew":"Załoga","Fuel":"Paliwo","Supplies":"Zapasy","Terror":"Groza",
"Echoes":"Echa","Cargo":"Ładunek","Equipment":"Wyposażenie","BUY":"KUP","SELL":"SPRZEDAJ","Cost:":"Koszt:",
"Trade:":"Wymiana:","Choose your name":"Wybierz imię","ACCEPT":"AKCEPTUJ","Loading...":"Wczytywanie…",
"Paused":"Pauza","Main Menu":"Menu główne","Return to Game":"Wróć do gry","Quit":"Wyjdź","Apply":"Zastosuj",
"Yes":"Tak","No":"Nie","OK":"OK","Done":"Gotowe"
})
(OUT/"ui_translation_memory.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
with (OUT/"qa_ui.csv").open("w",newline="",encoding="utf-8-sig") as f:
  w=csv.writer(f); w.writerow(["score","english","polish","roundtrip","source_files"]); w.writerows(sorted(qa))
(OUT/"ui_source_keys.txt").write_text("\n".join(keys),encoding="utf-8")
print("DONE",len(out))
