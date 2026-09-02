#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Any
from urllib.parse import quote

from release_assets import ReleaseSelectionError, select_release_asset


class ForgejoReleaseError(RuntimeError):
    pass


def _fetch_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "MGSSteamdeckScripts",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8")
    except (urllib.error.URLError, TimeoutError) as exc:
        raise ForgejoReleaseError(f"could not reach Forgejo release API: {exc}") from exc

    try:
        value = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise ForgejoReleaseError(f"could not parse Forgejo metadata: {exc}") from exc
    if not isinstance(value, dict):
        raise ForgejoReleaseError("Forgejo release metadata is not an object")
    return value


def resolve_release(
    base_url: str,
    repo: str,
    *,
    tag: str | None = None,
    match: str | None = None,
    reject: str | None = None,
    extension: str = r"\.zip$",
) -> tuple[str, str, str]:
    base_url = base_url.rstrip("/")
    endpoint = (
        f"{base_url}/api/v1/repos/{repo}/releases/tags/{quote(tag, safe='')}"
        if tag
        else f"{base_url}/api/v1/repos/{repo}/releases/latest"
    )
    release = _fetch_json(endpoint)
    release_tag = str(release.get("tag_name") or "")
    prefix = f"{base_url}/{repo}/releases/download/{release_tag}/"
    return select_release_asset(
        release,
        match=match,
        reject=reject,
        extension=extension,
        allow_prerelease=tag is not None,
        download_prefix=prefix,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Resolve a Forgejo release asset")
    parser.add_argument("base_url")
    parser.add_argument("repo", help="Repository in owner/name form")
    parser.add_argument("--tag")
    parser.add_argument("--match")
    parser.add_argument("--reject")
    parser.add_argument("--extension", default=r"\.zip$")
    args = parser.parse_args(argv)

    try:
        selected = resolve_release(
            args.base_url,
            args.repo,
            tag=args.tag,
            match=args.match,
            reject=args.reject,
            extension=args.extension,
        )
    except (ForgejoReleaseError, ReleaseSelectionError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print("\t".join(selected))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
