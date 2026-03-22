#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
FIXTURE_DIR = REPO_ROOT / 'tests' / 'fixtures' / 'report_cases'

sys.path.insert(0, str(SCRIPT_DIR))
from generate_latest_session_report import _latest_session_id, _load_jsonl, generate_report  # type: ignore

DEFAULT_DATE = '2026-03-07'
DEFAULT_CANONICAL_LABEL = 'fixture:play_events_canonical.json'


def render_fixture(raw_log: Path) -> str:
    events = _load_jsonl(raw_log)
    sid, _ = _latest_session_id(events)
    return generate_report(
        events,
        sid,
        generated_date=DEFAULT_DATE,
        raw_log_label=f'fixture:{raw_log.name}',
        canonical_bundle_label=DEFAULT_CANONICAL_LABEL,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description='Check fixture-backed local report outputs.')
    parser.add_argument('--rewrite', action='store_true', help='Rewrite expected markdown files from current output.')
    parser.add_argument('--case', action='append', help='Limit to specific fixture stem(s), e.g. schema_migration')
    args = parser.parse_args()

    cases = sorted(FIXTURE_DIR.glob('*.jsonl'))
    if args.case:
        wanted = set(args.case)
        cases = [case for case in cases if case.stem in wanted]

    if not cases:
        print('No report fixtures found.', file=sys.stderr)
        return 1

    failures = 0
    for raw_log in cases:
        expected_path = raw_log.with_suffix('.expected.md')
        actual = render_fixture(raw_log)

        if args.rewrite:
            expected_path.write_text(actual)
            print(f'rewrote {expected_path}')
            continue

        if not expected_path.exists():
            print(f'missing expected file: {expected_path}', file=sys.stderr)
            failures += 1
            continue

        expected = expected_path.read_text()
        if actual != expected:
            failures += 1
            print(f'fixture mismatch: {raw_log.name}', file=sys.stderr)
            diff = difflib.unified_diff(
                expected.splitlines(),
                actual.splitlines(),
                fromfile=str(expected_path),
                tofile=f'{raw_log.name}:actual',
                lineterm=''
            )
            for line in diff:
                print(line, file=sys.stderr)
        else:
            print(f'ok {raw_log.name}')

    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
