#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import shutil
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


class VdfError(ValueError):
    pass


@dataclass
class Token:
    kind: str
    value: str
    start: int
    end: int


def tokenize(text: str) -> list[Token]:
    tokens: list[Token] = []
    index = 0
    while index < len(text):
        char = text[index]
        if char in " \t\r\n":
            index += 1
            continue
        if text.startswith("//", index):
            newline = text.find("\n", index)
            index = len(text) if newline < 0 else newline + 1
            continue
        if char in "{}":
            tokens.append(Token(char, char, index, index + 1))
            index += 1
            continue
        if char == '"':
            cursor = index + 1
            buffer: list[str] = []
            while cursor < len(text):
                if text[cursor] == "\\" and cursor + 1 < len(text):
                    buffer.append(text[cursor + 1])
                    cursor += 2
                    continue
                if text[cursor] == '"':
                    break
                buffer.append(text[cursor])
                cursor += 1
            if cursor >= len(text):
                raise VdfError("unterminated quoted string")
            tokens.append(Token("str", "".join(buffer), index, cursor + 1))
            index = cursor + 1
            continue
        cursor = index
        while cursor < len(text) and text[cursor] not in ' \t\r\n{}"':
            cursor += 1
        tokens.append(Token("str", text[index:cursor], index, cursor))
        index = cursor
    return tokens


def parse(
    tokens: list[Token], position: int = 0
) -> tuple[list[dict[str, object]], int]:
    entries: list[dict[str, object]] = []
    while position < len(tokens):
        token = tokens[position]
        if token.kind == "}":
            return entries, position + 1
        if token.kind == "{":
            position += 1
            continue

        key = token.value
        key_start = token.start
        position += 1
        if position >= len(tokens):
            raise VdfError(f"missing value for key {key!r}")
        value_token = tokens[position]
        if value_token.kind == "{":
            children, position = parse(tokens, position + 1)
            entries.append(
                {
                    "key": key,
                    "object": True,
                    "children": children,
                    "open_end": value_token.end,
                    "key_start": key_start,
                }
            )
        elif value_token.kind == "}":
            raise VdfError(f"missing value for key {key!r}")
        else:
            entries.append(
                {
                    "key": key,
                    "object": False,
                    "value": value_token.value,
                    "value_start": value_token.start,
                    "value_end": value_token.end,
                    "key_start": key_start,
                }
            )
            position += 1
    return entries, position


def find_entry(
    entries: list[dict[str, object]], name: str
) -> dict[str, object] | None:
    for entry in entries:
        if str(entry["key"]).lower() == name.lower():
            return entry
    return None


def escape_vdf(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def indentation_at(text: str, position: int) -> str:
    line_start = text.rfind("\n", 0, position) + 1
    indentation = []
    for char in text[line_start:position]:
        if char in "\t ":
            indentation.append(char)
        else:
            break
    return "".join(indentation)


def split_overrides(value: str) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for part in value.split(";"):
        part = part.strip()
        if not part or "=" not in part:
            continue
        names, order = part.rsplit("=", 1)
        for name in names.split(","):
            if name.strip():
                pairs.append((name.strip(), order.strip()))
    return pairs


def join_overrides(pairs: list[tuple[str, str]]) -> str:
    return ";".join(f"{name}={order}" for name, order in pairs)


def find_overrides(value: str) -> tuple[int, int, str] | None:
    key = "WINEDLLOVERRIDES="
    start = value.find(key)
    if start < 0:
        return None
    value_start = start + len(key)
    if value_start < len(value) and value[value_start] == '"':
        end = value.find('"', value_start + 1)
        if end < 0:
            raise VdfError("unterminated WINEDLLOVERRIDES value")
        return start, end + 1, value[value_start + 1 : end]
    end = value_start
    while end < len(value) and value[end] not in " \t":
        end += 1
    return start, end, value[value_start:end]


def merge_launch_value(existing: str | None, wanted: str) -> str:
    wanted_pairs = split_overrides(wanted)
    if not wanted_pairs:
        raise VdfError("no valid DLL overrides were requested")

    if not existing or not existing.strip():
        return f'WINEDLLOVERRIDES="{join_overrides(wanted_pairs)}" %command%'

    hit = find_overrides(existing)
    if hit:
        start, end, inner = hit
        merged: list[tuple[str, str]] = []
        positions: dict[str, int] = {}
        for name, order in split_overrides(inner) + wanted_pairs:
            key = name.lower()
            if key in positions:
                merged[positions[key]] = (name, order)
            else:
                positions[key] = len(merged)
                merged.append((name, order))
        return (
            existing[:start]
            + f'WINEDLLOVERRIDES="{join_overrides(merged)}"'
            + existing[end:]
        )

    prefix = f'WINEDLLOVERRIDES="{join_overrides(wanted_pairs)}"'
    if "%command%" in existing:
        return f"{prefix} {existing}"
    return f"{prefix} %command% {existing.strip()}"


def update_launch_options(
    text: str, appid: str, overrides: str
) -> tuple[str, str | None, str, bool]:
    if not appid.isdigit():
        raise VdfError(f"invalid Steam AppID: {appid}")

    root, _ = parse(tokenize(text))
    store = find_entry(root, "UserLocalConfigStore")
    node: dict[str, object] = store if store else {"children": root}
    for name in ("Software", "Valve", "Steam", "apps"):
        children = node.get("children")
        if not isinstance(children, list):
            raise VdfError(f"could not find the {name!r} section")
        next_node = find_entry(children, name)
        if next_node is None or not next_node.get("object"):
            raise VdfError(f"could not find the {name!r} section")
        node = next_node
    apps = node

    app_children = apps.get("children")
    if not isinstance(app_children, list):
        raise VdfError("Steam apps section is malformed")
    app = find_entry(app_children, appid)
    if app is not None and not app.get("object"):
        raise VdfError(f"entry for app {appid} is malformed")

    if app is not None:
        children = app.get("children")
        if not isinstance(children, list):
            raise VdfError(f"entry for app {appid} is malformed")
        launch_options = find_entry(children, "LaunchOptions")
        if launch_options is not None and not launch_options.get("object"):
            old_value = str(launch_options["value"])
            new_value = merge_launch_value(old_value, overrides)
            if new_value == old_value:
                return text, old_value, new_value, False
            start = int(launch_options["value_start"])
            end = int(launch_options["value_end"])
            updated = text[:start] + f'"{escape_vdf(new_value)}"' + text[end:]
            return updated, old_value, new_value, True

        new_value = merge_launch_value(None, overrides)
        indentation = indentation_at(text, int(app["key_start"])) + "\t"
        insertion = int(app["open_end"])
        updated = (
            text[:insertion]
            + f'\n{indentation}"LaunchOptions"\t\t"{escape_vdf(new_value)}"'
            + text[insertion:]
        )
        return updated, None, new_value, True

    new_value = merge_launch_value(None, overrides)
    indentation = indentation_at(text, int(apps["key_start"])) + "\t"
    insertion = int(apps["open_end"])
    block = (
        f'\n{indentation}"{appid}"\n'
        f"{indentation}{{\n"
        f'{indentation}\t"LaunchOptions"\t\t"{escape_vdf(new_value)}"\n'
        f"{indentation}}}"
    )
    return text[:insertion] + block + text[insertion:], None, new_value, True


def write_updated_file(path: Path, content: str, backup: Path | None) -> Path:
    backup_path = backup or path.with_name(
        f"{path.name}.mgs-installer-{datetime.now():%Y%m%d%H%M%S%f}.bak"
    )
    shutil.copy2(path, backup_path)

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", errors="surrogateescape") as handle:
            handle.write(content)
        shutil.copymode(path, temporary)
        os.replace(temporary, path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    return backup_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Merge Steam launch options")
    parser.add_argument("localconfig", type=Path)
    parser.add_argument("appid")
    parser.add_argument("--overrides", required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--backup", type=Path)
    args = parser.parse_args(argv)

    try:
        text = args.localconfig.read_text(
            encoding="utf-8", errors="surrogateescape"
        )
        updated, old_value, new_value, changed = update_launch_options(
            text, args.appid, args.overrides
        )
        if not changed:
            print("already set")
            return 0
        if old_value:
            print(f"was: {old_value}")
        print(f"set: {new_value}")
        if args.dry_run:
            return 0
        backup = write_updated_file(args.localconfig, updated, args.backup)
        print(f"backup: {backup}")
    except (OSError, VdfError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
