#!/usr/bin/env python3
"""Markdown report of package changes between two images.

Usage: pkgdiff.py OLD.txt NEW.txt REFERENCE

Each input file has one "name.arch<TAB>epoch:version-release" line per
installed RPM (rpm -qa). An empty OLD file means there is no published image
to compare with yet.
"""

import sys


def load(path):
    packages = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            name, _, version = line.partition("\t")
            packages[name] = version.replace("(none):", "").removeprefix("0:")
    return packages


def table(rows, headers):
    out = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    out += ["| " + " | ".join(row) + " |" for row in rows]
    return "\n".join(out)


def main():
    old_path, new_path, reference = sys.argv[1:4]
    old, new = load(old_path), load(new_path)

    print("#### Packages")
    if not old:
        print(f"\nNo published `{reference}` to compare with: {len(new)} packages in this build.\n")
        return

    added = sorted(set(new) - set(old))
    removed = sorted(set(old) - set(new))
    changed = sorted(name for name in set(old) & set(new) if old[name] != new[name])

    print(f"\nCompared with `{reference}`: {len(added)} added, {len(removed)} removed, "
          f"{len(changed)} changed ({len(new)} packages).\n")
    if added:
        print("<details><summary>Added</summary>\n")
        print(table([(f"`{n}`", new[n]) for n in added], ["Package", "Version"]))
        print("\n</details>\n")
    if removed:
        print("<details><summary>Removed</summary>\n")
        print(table([(f"`{n}`", old[n]) for n in removed], ["Package", "Version"]))
        print("\n</details>\n")
    if changed:
        print("<details><summary>Changed</summary>\n")
        print(table([(f"`{n}`", old[n], new[n]) for n in changed], ["Package", "Before", "After"]))
        print("\n</details>\n")


if __name__ == "__main__":
    main()
