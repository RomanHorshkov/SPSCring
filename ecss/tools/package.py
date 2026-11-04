#!/usr/bin/env python3
"""package.py — this repository's ECSS package (ecss/): check it and write its documents' tables.

    ecss/tools/package.py check     the CSVs, the links, the reviews and results, every reference, the tables current
    ecss/tools/package.py tables    rewrite the generated tables of the documents (between <!-- ecss:table ... --> markers)
    ecss/tools/package.py slug <heading>   the anchor a heading gets

The CSVs use the rms import format (human_id,kind,title,body,rationale,criteria,method,owner,source_ref,applicability,notes). An item's
`owner` is the person of rms/cast.csv who writes it; `notes` carries `doc=<DOC>` (the document holding it: a has-child link from
<KEY>-DOC-<DOC>, made by the item's writer) and `review=<SRR|PDR|CDR|QR>` (the review that approves it; a document's is the first of its
`reviews=`). A reference is `<path>#<anchor>`: a Markdown heading's slug (GitHub's rule: lowercase, every character but a letter, a digit,
a space or a hyphen dropped, spaces to hyphens, a repeated slug in one file -1, -2, ...) or lines `L<n>` / `L<n>-L<m>`. In an item's
fields a path is the repository's (customers/<repo>/<path> for a customer's file, listed in rms/customers.csv); in a document's links it
is relative to the document, as a Markdown link is. Standard library only; deterministic.
"""
import csv
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
ROOT = os.path.dirname(PKG)
COLUMNS = ["human_id", "kind", "title", "body", "rationale", "criteria", "method", "owner", "source_ref", "applicability", "notes"]
ITEM_FILES = ["documents.csv", "RB/requirements.csv", "TS/requirements.csv", "DDF/components.csv", "DDF/decisions.csv",
              "DJF/verification_cases.csv", "rms/sources.csv"]
KINDS = {"requirement", "document", "component", "verification-case", "decision", "interface", "assumption", "source-reference",
         "configuration-item", "review", "review-comment", "change-request", "rationale"}
LINK_TYPES = {"derives-from", "refines", "allocates-to", "satisfies", "verifies", "references", "impacts", "implemented-by", "verified-by",
              "depends-on", "traces-to", "assumption-for", "justified-by", "constrained-by", "reviews", "has-child", "belongs-to", "covers"}
REVIEWS = ["SRR", "PDR", "CDR", "QR"]
GENERATED = {"doxygen"}  # a document whose file the loader writes (notes generated=<what>), not kept in the tree
REF = re.compile(r"(?<![\w/.\-])((?:[\w.\-]+/)*[\w.\-]+\.[A-Za-z0-9]+)#([A-Za-z0-9][A-Za-z0-9\-]*)")
LINK = re.compile(r"\]\(([^)\s]+)\)")
MARK = re.compile(r"<!-- ecss:table ([a-z\-]+)((?: [a-z]+=[^ ]+)*) -->\n.*?<!-- /ecss:table -->", re.S)


# ---- reading ------------------------------------------------------------------------------------------------------------------------
def read_csv(rel, pkg=PKG):
    path = os.path.join(pkg, rel)
    if not os.path.exists(path):
        return []
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def notes_of(text):
    out = {}
    for part in (text or "").split(";"):
        if "=" in part:
            k, v = part.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def project(pkg=PKG):
    return {r["field"]: r["value"] for r in read_csv("rms/project.csv", pkg)}


def cast(pkg=PKG):
    return read_csv("rms/cast.csv", pkg)


def items(pkg=PKG):
    out = []
    for rel in ITEM_FILES:
        for r in read_csv(rel, pkg):
            r["_file"] = rel
            out.append(r)
    return out


def item_review(it):
    n = notes_of(it.get("notes"))
    if n.get("review"):
        return n["review"]
    for rv in (n.get("reviews") or "").split(","):
        if rv.strip() in REVIEWS:
            return rv.strip()
    return None


def doc_id(key, short):
    return "%s-DOC-%s" % (key, short)


def links(pkg=PKG):
    """(src, type, dst, by): links.tsv, then each item's has-child from its document, made by the item's writer."""
    key = project(pkg)["key"]
    by_person = {c["person"]: c["key"] for c in cast(pkg)}
    out = []
    with open(os.path.join(pkg, "rms", "links.tsv"), encoding="utf-8") as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            src, typ, dst, by = line.rstrip("\n").split("\t")[:4]
            out.append((src, typ, dst, by))
    for it in items(pkg):
        d = notes_of(it.get("notes")).get("doc")
        if d and it["kind"] != "document":
            out.append((doc_id(key, d), "has-child", it["human_id"], by_person.get(it["owner"], "?")))
    return out


def reviews(pkg=PKG):
    return read_csv("rms/reviews.csv", pkg)


def results(pkg=PKG):
    return read_csv("DJF/results.csv", pkg)


def customers(pkg=PKG):
    return read_csv("rms/customers.csv", pkg)


# ---- anchors ------------------------------------------------------------------------------------------------------------------------
def slug(heading):
    s = heading.strip().lower()
    s = "".join(ch for ch in s if ch.isalnum() or ch in " -")
    return s.replace(" ", "-")


def anchors(text):
    """Every heading's slug in a Markdown text (a repeated one -1, -2, ...), fenced code skipped."""
    seen, out, fence = {}, set(), False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        m = None if fence else re.match(r"^(#{1,6})\s+(.*?)\s*#*\s*$", line)
        if m:
            s = slug(re.sub(r"`|\*\*|\[|\]\([^)]*\)", "", m.group(2)))
            n = seen.get(s, 0)
            out.add(s if n == 0 else "%s-%d" % (s, n))
            seen[s] = n + 1
    return out


def check_anchor(text, anchor):
    """None when @p anchor holds in @p text, else why."""
    m = re.fullmatch(r"L(\d+)(?:-L(\d+))?", anchor)
    if m:
        a, b = int(m.group(1)), int(m.group(2) or m.group(1))
        n = text.count("\n") + (0 if text.endswith("\n") else 1)
        return None if 1 <= a <= b <= n else "lines %s outside 1..%d" % (anchor, n)
    return None if anchor in anchors(text) else "no heading #%s" % anchor


# ---- the tables ---------------------------------------------------------------------------------------------------------------------
def short(key, ident):
    return ident[len(key) + 1:] if ident.startswith(key + "-") else ident


def cell(s):
    return (s or "").replace("|", "\\|").replace("\n", " ").strip()


def reflinks(text, doc_dir):
    """The references of an item's field as Markdown links relative to the document at @p doc_dir."""
    def one(m):
        path, anchor = m.group(1), m.group(2)
        rel = os.path.relpath(path, doc_dir) if doc_dir else path
        return "[%s#%s](%s#%s)" % (path, anchor, rel, anchor)
    return REF.sub(one, cell(text))


TRACE_OUT = [("derives-from", "derives from"), ("satisfies", "satisfies"), ("verified-by", "verified by"), ("justified-by", "justified by"),
             ("depends-on", "depends on"), ("traces-to", "traces to"), ("allocates-to", "allocated to"), ("constrained-by", "constrained by")]
TRACE_IN = [("derives-from", "source of"), ("satisfies", "satisfied by"), ("assumption-for", "assumed by"), ("verifies", "verified by"),
            ("depends-on", "needed by")]


def traces(key, ident, all_links):
    parts = []
    for typ, word in TRACE_OUT:
        dst = [short(key, d) for s, t, d, _ in all_links if s == ident and t == typ]
        if dst:
            parts.append("%s %s" % (word, ", ".join(dst)))
    for typ, word in TRACE_IN:
        src = [short(key, s) for s, t, d, _ in all_links if d == ident and t == typ]
        if src:
            parts.append("%s %s" % (word, ", ".join(src)))
    out = [s for s, t, d, _ in all_links if s == ident and t == "assumption-for"]
    if out:
        parts.append("assumption for %s" % ", ".join(short(key, d) for s, t, d, _ in all_links if s == ident and t == "assumption-for"))
    return "; ".join(parts) or "-"


def table(kind, args, doc_dir, pkg=PKG):
    key = project(pkg)["key"]
    its = items(pkg)
    ls = links(pkg)
    rows, head = [], None
    if kind == "items":
        sel = [i for i in its if notes_of(i["notes"]).get("doc") == args["doc"] and i["kind"] != "document"]
        if args.get("kind"):
            sel = [i for i in sel if i["kind"] == args["kind"]]
        head = ["ID", "Title", "Statement", "Method", "Source", "Traces"]
        for i in sel:
            rows.append([i["human_id"], cell(i["title"]), cell(i["body"]), i["method"] or "-", reflinks(i["source_ref"], doc_dir) or "-",
                         traces(key, i["human_id"], ls)])
    elif kind == "documents":
        head = ["ID", "Title", "DRD", "Review", "Path", "Written by"]
        for i in its:
            if i["kind"] != "document":
                continue
            n = notes_of(i["notes"])
            path = n.get("path", "-")
            shown = "[%s](%s)" % (path, os.path.relpath(path, doc_dir)) if path != "-" and doc_dir is not None else path
            rows.append([i["human_id"], cell(i["title"]), n.get("drd", "-"), n.get("reviews", "-"), shown, i["owner"]])
    elif kind == "cases":
        head = ["ID", "Title", "Method", "What runs", "Criteria", "Verifies"]
        for i in its:
            if i["kind"] != "verification-case":
                continue
            ver = [short(key, s) for s, t, d, _ in ls if d == i["human_id"] and t == "verified-by"]
            rows.append([i["human_id"], cell(i["title"]), i["method"], reflinks(i["body"], doc_dir), cell(i["criteria"]), ", ".join(ver) or "-"])
    elif kind == "results":
        head = ["Case", "Profile", "Commit", "Status", "Summary", "Evidence"]
        commit = project(pkg)["commit"][:8]
        for r in results(pkg):
            rows.append([r["case"], r["profile"], commit, r["status"], cell(r["summary"]), "`%s`" % r["evidence"]])
    elif kind == "rids":
        head = ["ID", "On", "Title", "Raised by", "Decision", "Why"]
        for r in reviews(pkg):
            if r["kind"] != "review-comment" or r["review"] != args["review"]:
                continue
            rows.append([r["human_id"], ", ".join(short(key, t) for t in r["target"].split()), cell(r["title"]), person_of(r["by"], pkg),
                         r["decision"], cell(r["reason"])])
    elif kind == "changes":
        head = ["ID", "Title", "Impacts", "Raised by", "State", "Why"]
        for r in reviews(pkg):
            if r["kind"] != "change-request":
                continue
            rows.append([r["human_id"], cell(r["title"]), ", ".join(short(key, t) for t in r["target"].split()), person_of(r["by"], pkg),
                         r["decision"], cell(r["reason"])])
    elif kind == "sources":
        head = ["ID", "Title", "What it is", "Reference"]
        for i in its:
            if i["kind"] != "source-reference":
                continue
            rows.append([i["human_id"], cell(i["title"]), cell(i["body"]), reflinks(i["source_ref"], doc_dir)])
    elif kind == "cast":
        head = ["Person", "Roles", "Duties"]
        for c in cast(pkg):
            if c["key"] == "owner":
                continue
            rows.append([c["person"], c["roles"].replace(";", ", "), cell(c["duties"])])
    elif kind == "trace":
        head = ["Customer requirement", "Software requirements", "Interfaces and components", "Cases"]
        for i in its:
            if notes_of(i["notes"]).get("doc") not in ("SSS", "IRD") or i["kind"] not in ("requirement",):
                continue
            down = [s for s, t, d, _ in ls if d == i["human_id"] and t == "derives-from"]
            sat = sorted({s for s, t, d, _ in ls if t == "satisfies" and (d == i["human_id"] or d in down)})
            cases = sorted({d for s, t, d, _ in ls if t == "verified-by" and (s == i["human_id"] or s in down)})
            rows.append(["%s %s" % (short(key, i["human_id"]), cell(i["title"])), ", ".join(short(key, x) for x in down) or "-",
                         ", ".join(short(key, x) for x in sat) or "-", ", ".join(short(key, x) for x in cases) or "-"])
    else:
        raise SystemExit("package.py: no table kind %s" % kind)
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    out += ["| " + " | ".join(r) + " |" for r in rows]
    return "\n".join(out)


def person_of(key, pkg=PKG):
    return next((c["person"] for c in cast(pkg) if c["key"] == key), key)


def render(text, doc_rel, pkg=PKG):
    doc_dir = os.path.dirname(doc_rel)

    def one(m):
        args = dict(a.split("=", 1) for a in m.group(2).split())
        return "<!-- ecss:table %s%s -->\n%s\n<!-- /ecss:table -->" % (m.group(1), m.group(2), table(m.group(1), args, doc_dir, pkg))
    return MARK.sub(one, text)


def documents_md(pkg=PKG):
    out = []
    for dp, _, fs in os.walk(pkg):
        for f in fs:
            if f.endswith(".md"):
                out.append(os.path.relpath(os.path.join(dp, f), os.path.dirname(pkg)))
    return sorted(out)


# ---- the check ----------------------------------------------------------------------------------------------------------------------
def tree_file(path, root):
    p = os.path.join(root, path)
    return p if os.path.isfile(p) else None


def check(pkg=PKG, root=None, customer_text=None):
    """Findings (strings); none when the package holds. @p customer_text(path) gives a customer's file's text (None: not checked)."""
    root = root or os.path.dirname(pkg)
    bad = []
    prj = project(pkg)
    key = prj.get("key", "")
    for f in ("key", "name", "commit", "release", "repo"):
        if not prj.get(f):
            bad.append("rms/project.csv: no %s" % f)
    people = {c["person"] for c in cast(pkg)}
    keys = {c["key"] for c in cast(pkg)}
    its = items(pkg)
    ids = {}
    for i in its:
        if list(i.keys())[:11] != COLUMNS:
            bad.append("%s: columns %s" % (i["_file"], list(i.keys())[:11]))
            break
    for i in its:
        if i["human_id"] in ids:
            bad.append("%s: %s twice" % (i["_file"], i["human_id"]))
        ids[i["human_id"]] = i
        if not i["human_id"].startswith(key + "-"):
            bad.append("%s: %s not under %s" % (i["_file"], i["human_id"], key))
        if i["kind"] not in KINDS:
            bad.append("%s: %s kind %s" % (i["_file"], i["human_id"], i["kind"]))
        if i["owner"] not in people:
            bad.append("%s: %s written by %s, not in rms/cast.csv" % (i["_file"], i["human_id"], i["owner"]))
        n = notes_of(i["notes"])
        if i["kind"] == "document":
            path = n.get("path")
            if not path or path == "-":
                bad.append("%s: document %s without a path" % (i["_file"], i["human_id"]))
            elif n.get("generated") not in GENERATED and not tree_file(path, root):
                bad.append("%s: %s path %s not in the tree" % (i["_file"], i["human_id"], path))
            if not item_review(i):
                bad.append("%s: document %s reviewed nowhere" % (i["_file"], i["human_id"]))
        else:
            if n.get("doc") and doc_id(key, n["doc"]) not in [x["human_id"] for x in its]:
                bad.append("%s: %s in document %s, which is not in documents.csv" % (i["_file"], i["human_id"], n["doc"]))
            if not item_review(i) and not (n.get("doc") and item_review(next((x for x in its if x["human_id"] == doc_id(key, n["doc"])), {}))):
                bad.append("%s: %s reviewed nowhere (review= or its document's)" % (i["_file"], i["human_id"]))
    rv_ids = {r["human_id"] for r in reviews(pkg)}
    known = set(ids) | rv_ids | {"%s-INPUT-KYR" % key}
    for s, t, d, by in links(pkg):
        if t not in LINK_TYPES:
            bad.append("links.tsv: %s %s %s: no link type %s" % (s, t, d, t))
        for x in (s, d):
            if x not in known:
                bad.append("links.tsv: %s %s %s: %s unknown" % (s, t, d, x))
        if by not in keys:
            bad.append("links.tsv: %s %s %s made by %s, not a key of rms/cast.csv" % (s, t, d, by))
    for r in reviews(pkg):
        if r["review"] not in REVIEWS:
            bad.append("reviews.csv: %s review %s" % (r["human_id"], r["review"]))
        for t in r["target"].split():
            if t not in known:
                bad.append("reviews.csv: %s on %s, unknown" % (r["human_id"], t))
        for k in (r["by"], r["decided_by"]):
            if k and k not in keys:
                bad.append("reviews.csv: %s: %s not in rms/cast.csv" % (r["human_id"], k))
    for r in results(pkg):
        if r["case"] not in ids or ids[r["case"]]["kind"] != "verification-case":
            bad.append("results.csv: %s is no verification case" % r["case"])
        ev = r["evidence"].split(" ")[0]
        if not tree_file(os.path.join("ecss", "DJF", ev), root):
            bad.append("results.csv: %s evidence %s not under ecss/DJF/" % (r["case"], ev))
    # references in the items
    cust = {c["path"] for c in customers(pkg)}
    for i in its + reviews(pkg):
        for field in ("body", "rationale", "criteria", "source_ref", "notes"):
            for m in REF.finditer(i.get(field) or ""):
                path, anchor = m.group(1), m.group(2)
                if path.startswith("customers/"):
                    if path not in cust:
                        bad.append("%s %s: %s#%s not in rms/customers.csv" % (i["human_id"], field, path, anchor))
                        continue
                    text = customer_text(path) if customer_text else None
                    if text is None:
                        continue
                else:
                    p = tree_file(path, root)
                    if not p:
                        bad.append("%s %s: %s not in the tree" % (i["human_id"], field, path))
                        continue
                    with open(p, encoding="utf-8", errors="replace") as f:
                        text = f.read()
                why = check_anchor(text, anchor)
                if why:
                    bad.append("%s %s: %s#%s: %s" % (i["human_id"], field, path, anchor, why))
    # the documents: tables current, links resolve
    for rel in documents_md(pkg):
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            text = f.read()
        if render(text, rel, pkg) != text:
            bad.append("%s: tables not current (package.py tables)" % rel)
        for m in LINK.finditer(text):
            target = m.group(1)
            if re.match(r"[a-z]+:", target):
                continue
            path, _, anchor = target.partition("#")
            full = os.path.normpath(os.path.join(os.path.dirname(rel), path)) if path else rel
            if full.startswith("customers/"):
                if full not in cust:
                    bad.append("%s: link %s: %s not in rms/customers.csv" % (rel, target, full))
                continue
            p = tree_file(full, root)
            if not p:
                if any(n.get("path") == full and n.get("generated") in GENERATED for n in (notes_of(i["notes"]) for i in its)):
                    continue
                if full.endswith(".svg") and tree_file(full[:-4] + ".puml", root):
                    continue  # the loader renders <stem>.svg beside <stem>.puml
                if "/api/" in full and full.startswith("ecss/DDF/api/"):
                    continue  # the API reference and its graphs, written by the loader from Doxygen
                bad.append("%s: link %s: %s not in the tree" % (rel, target, full))
                continue
            if anchor:
                with open(p, encoding="utf-8", errors="replace") as f:
                    why = check_anchor(f.read(), anchor)
                if why:
                    bad.append("%s: link %s: %s" % (rel, target, why))
    return bad


def main(argv):
    if argv[:1] == ["slug"]:
        print(slug(" ".join(argv[1:])))
        return 0
    if argv[:1] == ["tables"]:
        n = 0
        for rel in documents_md():
            p = os.path.join(ROOT, rel)
            with open(p, encoding="utf-8") as f:
                text = f.read()
            new = render(text, rel)
            if new != text:
                with open(p, "w", encoding="utf-8") as f:
                    f.write(new)
                n += 1
                print("  %s: tables written" % rel)
        print("package.py: %d document(s) rewritten" % n)
        return 0
    if argv[:1] == ["check"]:
        bad = check()
        for b in bad:
            print("  " + b)
        its = items()
        print("package.py: %d item(s), %d link(s), %d review row(s), %d result(s); %s" % (
            len(its), len(links()), len(reviews()), len(results()), "%d finding(s)" % len(bad) if bad else "holds"))
        return 1 if bad else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
