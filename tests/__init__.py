import importlib.machinery
import importlib.util
import pathlib

_COTMATE_PATH = pathlib.Path(__file__).resolve().parent.parent / "bin" / "cotmate"

_loader = importlib.machinery.SourceFileLoader("cotmate", str(_COTMATE_PATH))
_spec = importlib.util.spec_from_loader("cotmate", _loader)

if _spec is None or _spec.loader is None:
    raise RuntimeError(f"could not load {_COTMATE_PATH}")

cotmate = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cotmate)