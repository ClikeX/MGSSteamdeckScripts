#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import shutil
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath


class ArchiveError(ValueError):
    pass


def _safe_parts(name: str) -> tuple[str, ...]:
    normalized = name.replace("\\", "/")
    if "\n" in name or "\r" in name:
        raise ArchiveError(f"archive entry contains a newline: {name!r}")
    if normalized.startswith("/"):
        raise ArchiveError(f"archive entry is absolute: {name}")
    if len(normalized) >= 2 and normalized[1] == ":":
        raise ArchiveError(f"archive entry has a drive prefix: {name}")

    parts = tuple(part for part in normalized.split("/") if part not in ("", "."))
    if any(part == ".." for part in parts):
        raise ArchiveError(f"archive entry traverses outside the target: {name}")
    if PurePosixPath(normalized).is_absolute():
        raise ArchiveError(f"unsafe archive entry: {name}")
    return parts


def validate_zip(path: Path) -> list[zipfile.ZipInfo]:
    if not zipfile.is_zipfile(path):
        raise ArchiveError(f"not a valid ZIP archive: {path}")

    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        if not entries:
            raise ArchiveError("ZIP archive is empty")
        for entry in entries:
            _safe_parts(entry.filename)
            mode = entry.external_attr >> 16
            if stat.S_ISLNK(mode):
                raise ArchiveError(
                    "symbolic links are not allowed in release archives: "
                    f"{entry.filename}"
                )
        return entries


def extract_zip(path: Path, destination: Path) -> None:
    validate_zip(path)
    destination.mkdir(parents=True, exist_ok=True)
    destination_root = destination.resolve()

    with zipfile.ZipFile(path) as archive:
        for entry in archive.infolist():
            parts = _safe_parts(entry.filename)
            if not parts:
                continue
            target = destination.joinpath(*parts)
            resolved_target = target.resolve(strict=False)
            try:
                resolved_target.relative_to(destination_root)
            except ValueError as exc:
                raise ArchiveError(
                    f"archive entry escapes extraction directory: {entry.filename}"
                ) from exc

            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue

            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(entry) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output)

            mode = (entry.external_attr >> 16) & 0o777
            if mode:
                os.chmod(target, mode)


def payload_root(path: Path) -> Path:
    root = path.resolve()
    if not root.is_dir():
        raise ArchiveError(f"extracted payload directory does not exist: {path}")

    while True:
        entries = list(root.iterdir())
        if len(entries) != 1 or not entries[0].is_dir():
            return root
        root = entries[0].resolve()


def payload_files(path: Path) -> list[str]:
    root = path.resolve()
    if not root.is_dir():
        raise ArchiveError(f"payload root does not exist: {path}")
    return sorted(
        child.relative_to(root).as_posix()
        for child in root.rglob("*")
        if child.is_file()
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Safely inspect release ZIP archives")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("archive", type=Path)

    extract_parser = subparsers.add_parser("extract")
    extract_parser.add_argument("archive", type=Path)
    extract_parser.add_argument("destination", type=Path)

    root_parser = subparsers.add_parser("root")
    root_parser.add_argument("directory", type=Path)

    files_parser = subparsers.add_parser("files")
    files_parser.add_argument("directory", type=Path)

    args = parser.parse_args(argv)
    try:
        if args.command == "validate":
            validate_zip(args.archive)
        elif args.command == "extract":
            extract_zip(args.archive, args.destination)
        elif args.command == "root":
            print(payload_root(args.directory))
        elif args.command == "files":
            for relative_path in payload_files(args.directory):
                print(relative_path)
    except (ArchiveError, OSError, zipfile.BadZipFile) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
