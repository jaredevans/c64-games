"""Run every tests/test_*.py; exit non-zero if any fails."""
import subprocess
import sys
from pathlib import Path

here = Path(__file__).resolve().parent
failed = []
for t in sorted(here.glob('test_*.py')):
    print(f'== {t.name}')
    if subprocess.run([sys.executable, str(t)]).returncode != 0:
        failed.append(t.name)
print('FAILED: ' + ', '.join(failed) if failed else 'ALL PASS')
sys.exit(1 if failed else 0)
