"""One import path for the suite: every plane that holds importable Python."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for plane in ("tools", "oracles", "reference", "kernel"):
    sys.path.insert(0, str(ROOT / plane))
