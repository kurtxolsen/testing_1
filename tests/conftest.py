"""Make each tool package importable straight from the repo checkout,
without pip-installing them first (that's how CI runs pytest)."""

import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
for tool in ("stormtrack", "obj", "adjprep", "inspecto"):
    sys.path.insert(0, str(ROOT / tool))
