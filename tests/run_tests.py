"""
run_tests.py
============
Runner principal que ejecuta todos los tests del proyecto BuildViewer:
  1. Validación de data/Builds.lua (Python, sin dependencias externas)
  2. Tests unitarios de lógica Lua (requiere Lua 5.1 o LuaJIT instalado)

Uso:
    python tests/run_tests.py              # ejecuta todo
    python tests/run_tests.py --only=lua   # solo tests Lua
    python tests/run_tests.py --only=data  # solo validación de datos

Ejecutar desde la raíz del proyecto BuildViewer/
"""

import subprocess
import sys
import shutil
import argparse
from pathlib import Path

# ── Colores ───────────────────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

# ── Helpers ───────────────────────────────────────────────────

def header(title: str):
    line = "═" * 60
    print(f"\n{BOLD}{CYAN}{line}{RESET}")
    print(f"{BOLD}{CYAN}  {title}{RESET}")
    print(f"{BOLD}{CYAN}{line}{RESET}\n")


def run_step(label: str, cmd: list[str], cwd: Path) -> bool:
    """Ejecuta un comando, imprime su salida y devuelve True si tuvo éxito."""
    print(f"{BOLD}▶ {label}{RESET}")
    print(f"  Comando: {' '.join(cmd)}\n")

    result = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=False,   # mostrar salida en tiempo real
        text=True,
    )

    if result.returncode == 0:
        print(f"\n{GREEN}✓ {label} — PASÓ{RESET}")
    else:
        print(f"\n{RED}✗ {label} — FALLÓ (código de salida: {result.returncode}){RESET}")

    return result.returncode == 0


def find_lua() -> str | None:
    """Busca el ejecutable de Lua en el PATH. Prefiere LuaJIT > lua5.1 > lua."""
    for candidate in ["luajit", "lua5.1", "lua51", "lua"]:
        if shutil.which(candidate):
            return candidate
    return None


# ── Main ──────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Runner de tests de BuildViewer")
    parser.add_argument(
        "--only",
        choices=["lua", "data"],
        help="Ejecutar solo un subconjunto de tests"
    )
    args = parser.parse_args()

    # Raíz del proyecto = directorio padre de tests/
    project_root = Path(__file__).parent.parent.resolve()

    header("BuildViewer — Test Runner")
    print(f"Raíz del proyecto: {project_root}\n")

    results = {}

    # ── PASO 1: Validación de Builds.lua (Python) ─────────────
    if not args.only or args.only == "data":
        print(f"{BOLD}{'─' * 60}{RESET}")
        ok = run_step(
            "Validación de data/Builds.lua",
            [sys.executable, "tests/validate_data.py"],
            cwd=project_root
        )
        results["data"] = ok
        print()

    # ── PASO 2: Tests unitarios Lua ───────────────────────────
    if not args.only or args.only == "lua":
        print(f"{BOLD}{'─' * 60}{RESET}")
        lua_exe = find_lua()
        if lua_exe:
            print(f"  Lua encontrado: {lua_exe} ({shutil.which(lua_exe)})")
            ok = run_step(
                "Tests unitarios Lua (test_logic.lua)",
                [lua_exe, "tests/test_logic.lua"],
                cwd=project_root
            )
            results["lua"] = ok
        else:
            print(f"{YELLOW}⚠ Lua no encontrado en el PATH.{RESET}")
            print(  "  Instala Lua para ejecutar los tests de lógica:")
            print(  "    Windows:  https://luabinaries.sourceforge.net/  (lua-5.1.x_Win64_bin.zip)")
            print(  "    o bien:   winget install DEVCOM.Lua")
            print(  "    macOS:    brew install lua@5.1")
            print(  "    Linux:    sudo apt install lua5.1")
            results["lua"] = None  # skipped

    # ── Resumen final ─────────────────────────────────────────
    header("Resumen final")

    all_ok = True
    for step, ok in results.items():
        if ok is True:
            print(f"  {GREEN}✓  {step}{RESET}")
        elif ok is False:
            print(f"  {RED}✗  {step}{RESET}")
            all_ok = False
        else:
            print(f"  {YELLOW}⏭  {step} (omitido — Lua no instalado){RESET}")

    if not results:
        print(f"  {YELLOW}No se ejecutó ningún test.{RESET}")
        sys.exit(0)

    if all_ok:
        print(f"\n{GREEN}{BOLD}¡Todos los tests pasaron! ✓{RESET}")
        sys.exit(0)
    else:
        print(f"\n{RED}{BOLD}Algunos tests fallaron. Revisa los errores de arriba.{RESET}")
        sys.exit(1)


if __name__ == "__main__":
    main()
