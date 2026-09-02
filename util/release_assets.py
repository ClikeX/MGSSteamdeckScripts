#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


class ReleaseSelectionError(ValueError):
    pass


def load_release(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise ReleaseSelectionError(f"could not parse release metadata: {exc}") from exc

    if not isinstance(value, dict):
        raise ReleaseSelectionError("release metadata must be a JSON object")
    return value


def _compile(pattern: str | None, label: str) -> re.Pattern[str] | None:
    if not pattern:
        return None
    try:
        return re.compile(pattern, re.IGNORECASE)
    except re.error as exc:
        raise ReleaseSelectionError(f"invalid {label} regex: {exc}") from exc


def select_release_asset(
    release: dict[str, Any],
    *,
    match: str | None = None,
    reject: str | None = None,
    extension: str = r"\.zip$",
    allow_prerelease: bool = False,
    download_prefix: str | None = None,
) -> tuple[str, str, str]:
    if release.get("draft"):
        raise ReleaseSelectionError("release is a draft")
    if release.get("prerelease") and not allow_prerelease:
        raise ReleaseSelectionError("latest release is a prerelease")

    tag = str(release.get("tag_name") or "")
    if not tag:
        raise ReleaseSelectionError("release metadata has no tag_name")

    match_re = _compile(match, "asset match")
    reject_re = _compile(reject, "asset rejection")
    extension_re = _compile(extension, "asset extension")
    assert extension_re is not None

    eligible: list[tuple[str, str]] = []
    assets = release.get("assets") or []
    if not isinstance(assets, list):
        raise ReleaseSelectionError("release assets must be a JSON array")

    for asset in assets:
        if not isinstance(asset, dict):
            continue
        name = str(asset.get("name") or "")
        url = str(asset.get("browser_download_url") or "")
        lower_name = name.lower()
        if not name or not url or not extension_re.search(name):
            continue
        if "source code" in lower_name or re.search(
            r"(^|[-_. ])source($|[-_. ])", lower_name
        ):
            continue
        if download_prefix and not url.startswith(download_prefix):
            raise ReleaseSelectionError(
                f"release asset URL is outside the expected release: {url}"
            )
        eligible.append((name, url))

    matched = [
        asset
        for asset in eligible
        if (match_re is None or match_re.search(asset[0]))
        and (reject_re is None or not reject_re.search(asset[0]))
    ]

    if len(matched) == 1:
        chosen = matched[0]
    elif not matched and len(eligible) == 1:
        chosen = eligible[0]
    elif not eligible:
        raise ReleaseSelectionError("release has no eligible assets")
    elif not matched:
        raise ReleaseSelectionError(
            "no release asset matched the requested component"
        )
    else:
        names = ", ".join(name for name, _ in matched)
        raise ReleaseSelectionError(
            f"release asset selection is ambiguous: {names}"
        )

    return tag, chosen[0], chosen[1]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Select an asset from release JSON")
    parser.add_argument("metadata", type=Path)
    parser.add_argument("--match")
    parser.add_argument("--reject")
    parser.add_argument("--extension", default=r"\.zip$")
    parser.add_argument("--allow-prerelease", action="store_true")
    parser.add_argument("--download-prefix")
    args = parser.parse_args(argv)

    try:
        selected = select_release_asset(
            load_release(args.metadata),
            match=args.match,
            reject=args.reject,
            extension=args.extension,
            allow_prerelease=args.allow_prerelease,
            download_prefix=args.download_prefix,
        )
    except ReleaseSelectionError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print("\t".join(selected))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
