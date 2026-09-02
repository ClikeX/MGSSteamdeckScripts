#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from html.parser import HTMLParser
from typing import Any
from urllib.parse import quote, urljoin, urlparse

from release_assets import ReleaseSelectionError, select_release_asset


class GitHubReleaseError(RuntimeError):
    pass


class _AssetLinks(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.hrefs: list[str] = []

    def handle_starttag(
        self, _tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        for key, value in attrs:
            if key.lower() == "href" and value:
                self.hrefs.append(value)


def _request(url: str, *, accept: str | None = None) -> urllib.response.addinfourl:
    headers = {"User-Agent": "MGSSteamdeckScripts"}
    if accept:
        headers["Accept"] = accept
    request = urllib.request.Request(url, headers=headers)
    return urllib.request.urlopen(request, timeout=30)


def _fetch_json(url: str) -> dict[str, Any]:
    with _request(url, accept="application/vnd.github+json") as response:
        payload = response.read().decode("utf-8")
    value = json.loads(payload)
    if not isinstance(value, dict):
        raise GitHubReleaseError("GitHub release metadata is not an object")
    return value


def _release_from_html(repo: str, tag: str, html: str) -> dict[str, Any]:
    expected = f"/{repo}/releases/download/{tag}/"
    parser = _AssetLinks()
    parser.feed(html)

    assets = []
    for href in parser.hrefs:
        parsed = urlparse(href)
        if parsed.scheme and parsed.scheme != "https":
            continue
        path = parsed.path if parsed.scheme else href
        if not path.startswith(expected):
            continue
        assets.append(
            {
                "name": path.rsplit("/", 1)[-1],
                "browser_download_url": urljoin("https://github.com", path),
            }
        )

    return {
        "tag_name": tag,
        "draft": False,
        "prerelease": False,
        "assets": assets,
    }


def resolve_release(
    repo: str,
    *,
    tag: str | None = None,
    match: str | None = None,
    reject: str | None = None,
    extension: str = r"\.zip$",
    api_base: str = "https://api.github.com",
    web_base: str = "https://github.com",
) -> tuple[str, str, str]:
    api_base = api_base.rstrip("/")
    web_base = web_base.rstrip("/")
    encoded_tag = quote(tag, safe="") if tag else None
    endpoint = (
        f"{api_base}/repos/{repo}/releases/tags/{encoded_tag}"
        if encoded_tag
        else f"{api_base}/repos/{repo}/releases/latest"
    )

    try:
        release = _fetch_json(endpoint)
    except urllib.error.HTTPError as exc:
        if exc.code not in (403, 429):
            if exc.code == 404:
                raise GitHubReleaseError(f"GitHub release not found for {repo}") from exc
            raise GitHubReleaseError(
                f"GitHub API returned HTTP {exc.code} for {repo}"
            ) from exc
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise GitHubReleaseError(f"could not read GitHub release metadata: {exc}") from exc
    else:
        release_tag = str(release.get("tag_name") or "")
        prefix = f"https://github.com/{repo}/releases/download/{release_tag}/"
        return select_release_asset(
            release,
            match=match,
            reject=reject,
            extension=extension,
            allow_prerelease=tag is not None,
            download_prefix=prefix,
        )

    fallback_tag = tag
    if fallback_tag is None:
        try:
            with _request(f"{web_base}/{repo}/releases/latest") as response:
                effective_url = response.geturl()
        except (urllib.error.URLError, TimeoutError) as exc:
            raise GitHubReleaseError(
                f"GitHub rate-limit fallback could not resolve a tag: {exc}"
            ) from exc

        prefix = f"{web_base}/{repo}/releases/tag/"
        if not effective_url.startswith(prefix):
            raise GitHubReleaseError(
                "GitHub rate-limit fallback did not resolve a release tag"
            )
        fallback_tag = effective_url[len(prefix) :]

    if not fallback_tag or "/" in fallback_tag:
        raise GitHubReleaseError("unsafe GitHub release tag in fallback")

    try:
        with _request(
            f"{web_base}/{repo}/releases/expanded_assets/{quote(fallback_tag, safe='')}"
        ) as response:
            html = response.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, TimeoutError) as exc:
        raise GitHubReleaseError(
            f"could not read GitHub release assets page: {exc}"
        ) from exc

    release = _release_from_html(repo, fallback_tag, html)
    return select_release_asset(
        release,
        match=match,
        reject=reject,
        extension=extension,
        download_prefix=(
            f"https://github.com/{repo}/releases/download/{fallback_tag}/"
        ),
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Resolve a GitHub release asset")
    parser.add_argument("repo", help="Repository in owner/name form")
    parser.add_argument("--tag")
    parser.add_argument("--match")
    parser.add_argument("--reject")
    parser.add_argument("--extension", default=r"\.zip$")
    parser.add_argument(
        "--api-base",
        default="https://api.github.com",
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--web-base",
        default="https://github.com",
        help=argparse.SUPPRESS,
    )
    args = parser.parse_args(argv)

    try:
        selected = resolve_release(
            args.repo,
            tag=args.tag,
            match=args.match,
            reject=args.reject,
            extension=args.extension,
            api_base=args.api_base,
            web_base=args.web_base,
        )
    except (GitHubReleaseError, ReleaseSelectionError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print("\t".join(selected))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
