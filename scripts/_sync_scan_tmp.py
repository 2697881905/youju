#!/usr/bin/env python3
import os, sys, json, hashlib

ROOT = "/Users/itxiaobai/HarmonyProject1"
STATE = os.path.join(ROOT, ".workbuddy/state/harmony_sync_state.json")

PRUNE_DIRS = {".git","node_modules","oh_modules","build","dist",".hvigor",
              ".idea",".vscode",".preview","temp",".workbuddy",".codegenie",".appanalyzer"}

DOC_EXTS = {".md", ".txt", ".docx", ".pdf", ".html", ".mermaid"}

EMPTY_HASH = hashlib.sha256(b"").hexdigest()[:16]

# folder ids
F_PROBLEM = "folder_7505655271289541"   # 问题记录
F_DEV     = "folder_7505655426480055"   # 开发文档
F_SUMMARY = "folder_7505655451644451"   # 提交摘要
F_DECISION= "folder_7505655489373459"   # 决策记录

def classify(rel):
    if rel.startswith(".codeartsdoer/experience-reuse"):
        return F_PROBLEM
    if rel.startswith(".trae/documents"):
        return F_DEV
    if rel.startswith("entry/Docs"):
        return F_DEV
    if rel.startswith("docs/"):
        if rel.startswith("docs/risk-assessment/"):
            return F_PROBLEM
        if rel in ("docs/home-segmented-control-style-audit.md",
                   "docs/competitive-analysis.md",
                   "docs/git-worktree-policy.md"):
            return F_DECISION
        if rel == "docs/pre-submission-audit.md":
            return F_PROBLEM
        if rel in ("docs/dead-code-cleanup.md", "docs/2026-09-08-mention-report-ux.md"):
            return F_SUMMARY
        return F_DEV
    if rel.startswith("deliverables/product-strategy"):
        return F_DEV
    if rel.startswith("deliverables/gstack"):
        return F_DEV
    if rel.startswith("deliverables/security-compliance"):
        return F_DEV
    if rel.startswith("deliverables/retrospective"):
        return F_DECISION
    if rel in ("deliverables/agc-pre-review.md",
               "deliverables/youju-agc-review-2026-08-16.md"):
        return F_PROBLEM
    if rel == "deliverables/resume-youju-project.md":
        return F_DEV
    if rel in ("backend/DEPLOY.md", "backend/deploy/README.md"):
        return F_DEV
    if rel.startswith(".codebuddy/memory"):
        return F_SUMMARY
    if rel == "VERSION.md":
        return F_SUMMARY
    if rel.startswith(".zcode/plans"):
        return F_PROBLEM
    if rel.startswith("soft_output/") and rel.endswith(".md"):
        return F_DEV
    return None  # unclassified

# files we don't even want to list as unclassified (skip silently)
def is_skip_file(rel):
    if rel.endswith("obfuscation-rules.txt"):
        return True
    return False

def sha16(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1<<16), b""):
            h.update(chunk)
    return h.hexdigest()[:16]

def main():
    with open(STATE) as f:
        state = json.load(f)
    files_state = state.get("files", {})

    candidates = []  # list of (rel, abspath, size, hash)
    for dirpath, dirnames, filenames in os.walk(ROOT):
        # prune
        rel_dir = os.path.relpath(dirpath, ROOT)
        parts = [] if rel_dir == "." else rel_dir.split("/")
        # remove pruned dirs from traversal
        dirnames[:] = [d for d in dirnames if d not in PRUNE_DIRS
                       and d not in {p for p in parts if p in PRUNE_DIRS}]
        for fn in filenames:
            ext = os.path.splitext(fn)[1].lower()
            if ext not in DOC_EXTS:
                continue
            abspath = os.path.join(dirpath, fn)
            rel = os.path.relpath(abspath, ROOT)
            try:
                size = os.path.getsize(abspath)
            except OSError:
                continue
            if size == 0:
                continue
            h = sha16(abspath)
            if h == EMPTY_HASH:
                continue
            candidates.append((rel, abspath, size, h))

    # compare
    new_list = []
    changed_list = []
    skip_list = []
    unclassified = []
    current_paths = set()
    for rel, ap, size, h in candidates:
        current_paths.add(rel)
        folder = classify(rel)
        if folder is None:
            if not is_skip_file(rel):
                unclassified.append(rel)
            continue
        prev = files_state.get(rel)
        if prev is None:
            new_list.append((rel, ap, size, h, folder))
        else:
            prev_h = prev.get("hash")
            if prev_h != h:
                changed_list.append((rel, ap, size, h, folder))
            else:
                skip_list.append(rel)

    # deleted detection: in state (status != deleted) but not on disk (and not prune dir)
    deleted_list = []
    for rel, meta in files_state.items():
        if meta.get("status") == "deleted":
            continue
        if rel in current_paths:
            continue
        top = rel.split("/")[0]
        if top in PRUNE_DIRS:
            continue
        # file gone
        deleted_list.append(rel)

    out = {
        "new": [{"rel":r,"size":s,"hash":h,"folder":f} for r,s,h,f,_ in new_list],
        "changed": [{"rel":r,"size":s,"hash":h,"folder":f} for r,s,h,f,_ in changed_list],
        "skip": skip_list,
        "unclassified": sorted(unclassified),
        "deleted": deleted_list,
    }
    # write plan for downstream
    with open("/tmp/sync_plan.json","w") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print("=== SCAN RESULT (incremental) ===")
    print(f"candidates total: {len(candidates)}")
    print(f"NEW (classified): {len(new_list)}")
    for r,h,f in [(x[0],x[3],x[4]) for x in new_list]:
        print(f"  + {r}  [{f}]  {h}")
    print(f"CHANGED (classified): {len(changed_list)}")
    for r,h,f in [(x[0],x[3],x[4]) for x in changed_list]:
        print(f"  ~ {r}  [{f}]  {h}")
    print(f"SKIP (unchanged): {len(skip_list)}")
    print(f"DELETED (local): {len(deleted_list)}")
    for r in deleted_list:
        print(f"  - {r}")
    print(f"UNCLASSIFIED (not uploaded): {len(unclassified)}")
    for r in sorted(unclassified):
        print(f"  ? {r}")

if __name__ == "__main__":
    main()
