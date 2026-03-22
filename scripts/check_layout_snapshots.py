#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import struct
import sys
import textwrap
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
BASELINE_DIR = REPO_ROOT / "tests" / "fixtures" / "layout_snapshots" / "baseline"
REGION_CONFIG_PATH = REPO_ROOT / "tests" / "fixtures" / "layout_snapshots" / "regions.json"
DEFAULT_CURRENT_DIR = REPO_ROOT / "artifacts" / "pre_release" / "layout_snapshots"
DEFAULT_DIFF_DIR = REPO_ROOT / "artifacts" / "pre_release" / "layout_snapshot_diffs"
DEFAULT_SCENES = [
    "live_turn",
    "all_in_turn",
    "showdown",
    "footer_showdown",
    "long_names",
    "long_footer_pills",
    "coach_turn",
]
MANIFEST_NAME = "manifest.json"


@dataclass
class PngImage:
    width: int
    height: int
    rgba: bytes


@dataclass
class DiffStats:
    changed_pixels: int
    total_pixels: int
    changed_ratio: float
    max_channel_diff: int
    diff_path: Path | None


@dataclass
class SceneResult:
    scene: str
    width: int
    height: int
    md5_expected: str
    md5_actual: str
    diff: DiffStats


@dataclass
class RegionSpec:
    name: str
    x: float
    y: float
    width: float
    height: float


@dataclass
class RegionResult:
    scene: str
    name: str
    x: int
    y: int
    width: int
    height: int
    md5_expected: str
    md5_actual: str
    diff: DiffStats


@dataclass
class ComparisonResult:
    scene: SceneResult
    regions: list[RegionResult]


def _iter_chunks(blob: bytes) -> Iterable[tuple[bytes, bytes]]:
    offset = len(PNG_SIGNATURE)
    while offset < len(blob):
        if offset + 8 > len(blob):
            raise ValueError("Truncated PNG chunk header")
        length = struct.unpack(">I", blob[offset:offset + 4])[0]
        ctype = blob[offset + 4:offset + 8]
        start = offset + 8
        end = start + length
        crc_end = end + 4
        if crc_end > len(blob):
            raise ValueError("Truncated PNG chunk payload")
        yield ctype, blob[start:end]
        offset = crc_end
        if ctype == b"IEND":
            break


def _paeth_predictor(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path: Path) -> PngImage:
    blob = path.read_bytes()
    if not blob.startswith(PNG_SIGNATURE):
        raise ValueError(f"Not a PNG: {path}")

    width = height = 0
    color_type = None
    bit_depth = None
    interlace = None
    compressed = bytearray()

    for ctype, payload in _iter_chunks(blob):
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(">IIBBBBB", payload)
            if compression != 0 or filter_method != 0:
                raise ValueError(f"Unsupported PNG compression/filter method in {path}")
        elif ctype == b"IDAT":
            compressed.extend(payload)
        elif ctype == b"IEND":
            break

    if bit_depth != 8:
        raise ValueError(f"Unsupported bit depth in {path}: {bit_depth}")
    if interlace != 0:
        raise ValueError(f"Unsupported interlaced PNG in {path}")
    if color_type not in (2, 6):
        raise ValueError(f"Unsupported color type in {path}: {color_type}")

    channels = 4 if color_type == 6 else 3
    stride = width * channels
    raw = memoryview(zlib.decompress(bytes(compressed)))
    expected = height * (stride + 1)
    if len(raw) != expected:
        raise ValueError(f"Unexpected decompressed size in {path}: got {len(raw)}, want {expected}")

    prev = bytearray(stride)
    out = bytearray(width * height * 4)
    raw_offset = 0
    out_offset = 0

    for _ in range(height):
        filter_type = raw[raw_offset]
        raw_offset += 1
        row_in = raw[raw_offset:raw_offset + stride]
        raw_offset += stride
        row = bytearray(stride)

        if filter_type == 0:
            row[:] = row_in
        elif filter_type == 1:
            for i in range(stride):
                left = row[i - channels] if i >= channels else 0
                row[i] = (row_in[i] + left) & 0xFF
        elif filter_type == 2:
            for i in range(stride):
                row[i] = (row_in[i] + prev[i]) & 0xFF
        elif filter_type == 3:
            for i in range(stride):
                left = row[i - channels] if i >= channels else 0
                up = prev[i]
                row[i] = (row_in[i] + ((left + up) // 2)) & 0xFF
        elif filter_type == 4:
            for i in range(stride):
                left = row[i - channels] if i >= channels else 0
                up = prev[i]
                up_left = prev[i - channels] if i >= channels else 0
                row[i] = (row_in[i] + _paeth_predictor(left, up, up_left)) & 0xFF
        else:
            raise ValueError(f"Unsupported PNG filter type {filter_type} in {path}")

        if channels == 4:
            out[out_offset:out_offset + len(row)] = row
            out_offset += len(row)
        else:
            for i in range(0, len(row), 3):
                out[out_offset:out_offset + 4] = bytes((row[i], row[i + 1], row[i + 2], 255))
                out_offset += 4

        prev = row

    return PngImage(width=width, height=height, rgba=bytes(out))


def _png_chunk(ctype: bytes, payload: bytes) -> bytes:
    return b"".join([
        struct.pack(">I", len(payload)),
        ctype,
        payload,
        struct.pack(">I", zlib.crc32(ctype + payload) & 0xFFFFFFFF),
    ])


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    stride = width * 4
    raw = bytearray()
    for row_start in range(0, len(rgba), stride):
        raw.append(0)
        raw.extend(rgba[row_start:row_start + stride])

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=9)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"".join([
            PNG_SIGNATURE,
            _png_chunk(b"IHDR", ihdr),
            _png_chunk(b"IDAT", idat),
            _png_chunk(b"IEND", b""),
        ])
    )


def md5_bytes(blob: bytes) -> str:
    return hashlib.md5(blob).hexdigest()


def load_region_specs() -> dict[str, list[RegionSpec]]:
    if not REGION_CONFIG_PATH.exists():
        return {}
    raw = json.loads(REGION_CONFIG_PATH.read_text())
    specs: dict[str, list[RegionSpec]] = {}
    for scene, rows in raw.items():
        specs[scene] = [RegionSpec(**row) for row in rows]
    return specs


def region_bounds(image: PngImage, spec: RegionSpec) -> tuple[int, int, int, int]:
    x = max(0, min(image.width - 1, int(round(spec.x * image.width))))
    y = max(0, min(image.height - 1, int(round(spec.y * image.height))))
    width = max(1, min(image.width - x, int(round(spec.width * image.width))))
    height = max(1, min(image.height - y, int(round(spec.height * image.height))))
    return x, y, width, height


def crop_image(image: PngImage, x: int, y: int, width: int, height: int) -> PngImage:
    stride = image.width * 4
    out = bytearray(width * height * 4)
    out_offset = 0
    for row in range(y, y + height):
        start = row * stride + x * 4
        end = start + width * 4
        chunk = image.rgba[start:end]
        out[out_offset:out_offset + len(chunk)] = chunk
        out_offset += len(chunk)
    return PngImage(width=width, height=height, rgba=bytes(out))


def compare_images(
    expected: PngImage,
    actual: PngImage,
    diff_path: Path | None = None,
    channel_tolerance: int = 0,
) -> DiffStats:
    if (expected.width, expected.height) != (actual.width, actual.height):
        raise ValueError(
            f"Dimension mismatch: expected {expected.width}x{expected.height}, got {actual.width}x{actual.height}"
        )

    changed_pixels = 0
    max_channel_diff = 0
    diff_rgba = bytearray(len(expected.rgba)) if diff_path else None
    for offset in range(0, len(expected.rgba), 4):
        er, eg, eb, ea = expected.rgba[offset:offset + 4]
        ar, ag, ab, aa = actual.rgba[offset:offset + 4]
        channel_diff = max(abs(er - ar), abs(eg - ag), abs(eb - ab), abs(ea - aa))
        if channel_diff <= channel_tolerance:
            if diff_rgba is not None:
                diff_rgba[offset:offset + 4] = bytes((0, 0, 0, 0))
            continue
        changed_pixels += 1
        max_channel_diff = max(max_channel_diff, channel_diff)
        if diff_rgba is not None:
            diff_rgba[offset:offset + 4] = bytes((255, 0, 255, 255))

    total_pixels = expected.width * expected.height
    changed_ratio = changed_pixels / total_pixels if total_pixels else 0.0
    if diff_path is not None and changed_pixels:
        write_png(diff_path, expected.width, expected.height, bytes(diff_rgba))

    return DiffStats(
        changed_pixels=changed_pixels,
        total_pixels=total_pixels,
        changed_ratio=changed_ratio,
        max_channel_diff=max_channel_diff,
        diff_path=diff_path if changed_pixels else None,
    )


def compare_scene(
    scene: str,
    expected_path: Path,
    actual_path: Path,
    diff_dir: Path,
    region_specs: list[RegionSpec],
    channel_tolerance: int,
) -> ComparisonResult:
    expected_blob = expected_path.read_bytes()
    actual_blob = actual_path.read_bytes()
    expected = read_png(expected_path)
    actual = read_png(actual_path)

    scene_diff_path = diff_dir / f"{scene}.diff.png"
    scene_result = SceneResult(
        scene=scene,
        width=expected.width,
        height=expected.height,
        md5_expected=md5_bytes(expected_blob),
        md5_actual=md5_bytes(actual_blob),
        diff=compare_images(expected, actual, scene_diff_path, channel_tolerance),
    )

    region_results: list[RegionResult] = []
    for spec in region_specs:
        x, y, width, height = region_bounds(expected, spec)
        expected_crop = crop_image(expected, x, y, width, height)
        actual_crop = crop_image(actual, x, y, width, height)
        diff_path = diff_dir / f"{scene}__{spec.name}.diff.png"
        region_results.append(
            RegionResult(
                scene=scene,
                name=spec.name,
                x=x,
                y=y,
                width=width,
                height=height,
                md5_expected=md5_bytes(expected_crop.rgba),
                md5_actual=md5_bytes(actual_crop.rgba),
                diff=compare_images(expected_crop, actual_crop, diff_path, channel_tolerance),
            )
        )

    return ComparisonResult(scene=scene_result, regions=region_results)


def write_manifest(path: Path, scenes: list[str], source_dir: Path, region_specs_by_scene: dict[str, list[RegionSpec]]) -> None:
    manifest: dict[str, object] = {
        "window": {
            "logical_width": int(os.environ.get("HOLDEM_UI_WINDOW_WIDTH", "1440")),
            "logical_height": int(os.environ.get("HOLDEM_UI_WINDOW_HEIGHT", "900")),
        },
        "region_config": str(REGION_CONFIG_PATH.relative_to(REPO_ROOT)) if REGION_CONFIG_PATH.exists() else None,
        "scenes": scenes,
        "files": {},
    }
    files: dict[str, object] = {}
    for scene in scenes:
        image_path = source_dir / f"{scene}.png"
        image = read_png(image_path)
        file_info: dict[str, object] = {
            "path": image_path.name,
            "pixel_width": image.width,
            "pixel_height": image.height,
            "md5": md5_bytes(image_path.read_bytes()),
        }
        specs = region_specs_by_scene.get(scene, [])
        if specs:
            region_info: dict[str, object] = {}
            for spec in specs:
                x, y, width, height = region_bounds(image, spec)
                crop = crop_image(image, x, y, width, height)
                region_info[spec.name] = {
                    "x": x,
                    "y": y,
                    "width": width,
                    "height": height,
                    "md5": md5_bytes(crop.rgba),
                }
            file_info["regions"] = region_info
        files[scene] = file_info
    manifest["files"] = files
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n")


def write_diff_index(diff_dir: Path, results: list[ComparisonResult], current_dir: Path, baseline_dir: Path) -> None:
    lines = [
        "# Layout Snapshot Diff Report",
        "",
        f"- Baseline dir: `{baseline_dir}`",
        f"- Current dir: `{current_dir}`",
        "",
    ]

    scene_mismatches = [result for result in results if result.scene.diff.changed_pixels > 0]
    region_mismatches = [
        region
        for result in results
        for region in result.regions
        if region.diff.changed_pixels > 0
    ]

    if not scene_mismatches:
        lines.append("All full-scene snapshots matched their approved baselines exactly.")
    else:
        lines.append(f"Full-scene mismatches: `{len(scene_mismatches)}`")
        lines.append("")
        for result in scene_mismatches:
            scene = result.scene
            lines.append(f"## Scene {scene.scene}")
            lines.append("")
            lines.append(
                f"- Changed pixels: `{scene.diff.changed_pixels}/{scene.diff.total_pixels}` ({scene.diff.changed_ratio * 100.0:.4f}%)"
            )
            lines.append(f"- Max channel diff: `{scene.diff.max_channel_diff}`")
            lines.append(f"- Expected md5: `{scene.md5_expected}`")
            lines.append(f"- Actual md5: `{scene.md5_actual}`")
            lines.append("")
            lines.append(f"Expected: ![expected](../layout_snapshots/{scene.scene}.png)")
            lines.append("")
            if scene.diff.diff_path is not None:
                lines.append(f"Diff mask: ![diff]({scene.diff.diff_path.name})")
                lines.append("")

    lines.append("## Critical Regions")
    lines.append("")
    if not region_mismatches:
        lines.append("All configured region assertions matched their approved baselines exactly.")
    else:
        lines.append(f"Region mismatches: `{len(region_mismatches)}`")
        lines.append("")
        for region in region_mismatches:
            lines.append(f"### {region.scene}.{region.name}")
            lines.append("")
            lines.append(
                f"- Bounds: `x={region.x}, y={region.y}, w={region.width}, h={region.height}`"
            )
            lines.append(
                f"- Changed pixels: `{region.diff.changed_pixels}/{region.diff.total_pixels}` ({region.diff.changed_ratio * 100.0:.4f}%)"
            )
            lines.append(f"- Max channel diff: `{region.diff.max_channel_diff}`")
            lines.append(f"- Expected md5: `{region.md5_expected}`")
            lines.append(f"- Actual md5: `{region.md5_actual}`")
            lines.append("")
            if region.diff.diff_path is not None:
                lines.append(f"Diff mask: ![diff]({region.diff.diff_path.name})")
                lines.append("")

    diff_dir.mkdir(parents=True, exist_ok=True)
    (diff_dir / "index.md").write_text("\n".join(lines) + "\n")


def bless(current_dir: Path, baseline_dir: Path, scenes: list[str], region_specs_by_scene: dict[str, list[RegionSpec]]) -> None:
    baseline_dir.mkdir(parents=True, exist_ok=True)
    for scene in scenes:
        src = current_dir / f"{scene}.png"
        if not src.exists():
            raise SystemExit(f"Missing rendered snapshot for bless: {src}")
        shutil.copy2(src, baseline_dir / src.name)
    write_manifest(baseline_dir / MANIFEST_NAME, scenes, baseline_dir, region_specs_by_scene)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare deterministic layout snapshots against approved baselines."
    )
    parser.add_argument("--current-dir", type=Path, default=DEFAULT_CURRENT_DIR)
    parser.add_argument("--baseline-dir", type=Path, default=BASELINE_DIR)
    parser.add_argument("--diff-dir", type=Path, default=DEFAULT_DIFF_DIR)
    parser.add_argument("--scene", action="append", help="Limit to one or more specific scene names")
    parser.add_argument("--rewrite", action="store_true", help="Bless current snapshots as the approved baseline")
    parser.add_argument(
        "--max-changed-pixels",
        type=int,
        default=0,
        help="Allow up to this many changed pixels before failing (default: 0)",
    )
    parser.add_argument(
        "--max-changed-ratio",
        type=float,
        default=0.0,
        help="Allow up to this changed-pixel ratio before failing (default: 0.0)",
    )
    parser.add_argument(
        "--channel-tolerance",
        type=int,
        default=2,
        help="Ignore per-channel differences up to this value to absorb capture jitter (default: 2)",
    )
    args = parser.parse_args()

    scenes = args.scene or DEFAULT_SCENES
    region_specs_by_scene = load_region_specs()
    if args.rewrite:
        bless(args.current_dir, args.baseline_dir, scenes, region_specs_by_scene)
        print(f"Blessed {len(scenes)} scenes into {args.baseline_dir}")
        return 0

    missing = [scene for scene in scenes if not (args.baseline_dir / f"{scene}.png").exists()]
    if missing:
        msg = textwrap.dedent(
            f"""
            Missing approved baseline snapshots for: {', '.join(missing)}
            Render and bless them first:
              ./scripts/render_layout_snapshots.sh {args.current_dir}
              python3 ./scripts/check_layout_snapshots.py --rewrite --current-dir {args.current_dir}
            """
        ).strip()
        print(msg, file=sys.stderr)
        return 1

    args.diff_dir.mkdir(parents=True, exist_ok=True)
    results: list[ComparisonResult] = []
    failures = 0
    for scene in scenes:
        expected_path = args.baseline_dir / f"{scene}.png"
        actual_path = args.current_dir / f"{scene}.png"
        if not actual_path.exists():
            print(f"Missing rendered snapshot: {actual_path}", file=sys.stderr)
            failures += 1
            continue

        try:
            result = compare_scene(
                scene,
                expected_path,
                actual_path,
                args.diff_dir,
                region_specs_by_scene.get(scene, []),
                args.channel_tolerance,
            )
        except ValueError as exc:
            print(f"mismatch {scene}: {exc}", file=sys.stderr)
            failures += 1
            continue

        results.append(result)
        scene_diff = result.scene.diff
        over_pixels = scene_diff.changed_pixels > args.max_changed_pixels
        over_ratio = scene_diff.changed_ratio > args.max_changed_ratio
        scene_regions_changed = [region for region in result.regions if region.diff.changed_pixels > 0]

        if over_pixels or over_ratio:
            failures += 1
            print(
                f"scene mismatch {scene}: {scene_diff.changed_pixels}/{scene_diff.total_pixels} pixels changed ({scene_diff.changed_ratio * 100.0:.4f}%), max channel diff {scene_diff.max_channel_diff}",
                file=sys.stderr,
            )
        else:
            region_note = ""
            if result.regions:
                region_note = f" (regions: {', '.join(region.name for region in result.regions)})"
            print(f"ok {scene}{region_note}")

        for region in scene_regions_changed:
            failures += 1
            print(
                f"region mismatch {scene}.{region.name}: {region.diff.changed_pixels}/{region.diff.total_pixels} pixels changed ({region.diff.changed_ratio * 100.0:.4f}%), max channel diff {region.diff.max_channel_diff}",
                file=sys.stderr,
            )

    write_diff_index(args.diff_dir, results, args.current_dir, args.baseline_dir)
    if failures:
        print(f"Diff artifacts: {args.diff_dir}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
