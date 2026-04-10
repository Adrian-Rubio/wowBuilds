"""
validate_data.py
================
Valida la estructura y contenido de data/Builds.lua sin necesitar WoW ni Lua.
Parsea el archivo Lua con expresiones regulares y comprueba:
  - Que todas las clases estén presentes
  - Que cada clase tenga sus specs correctas
  - Que los campos obligatorios existan y no estén vacíos
  - Que las URLs apunten a icy-veins.com
  - Que los talent strings sean del formato correcto (si están presentes)

Uso:  python tests/validate_data.py  (desde la raíz del proyecto)
"""

import re
import sys
import io
from pathlib import Path

# Forzar UTF-8 en la salida estándar (necesario en Windows con cp1252)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

# ── Colores para consola ─────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

PASS = f"{GREEN}✓{RESET}"
FAIL = f"{RED}✗{RESET}"
WARN = f"{YELLOW}⚠{RESET}"

# ── Estructura esperada ───────────────────────────────────────
EXPECTED_CLASSES = {
    "Death Knight":  {"Blood", "Frost", "Unholy"},
    "Demon Hunter":  {"Havoc", "Vengeance"},
    "Druid":         {"Balance", "Feral", "Guardian", "Restoration"},
    "Evoker":        {"Devastation", "Preservation", "Augmentation"},
    "Hunter":        {"Beast Mastery", "Marksmanship", "Survival"},
    "Mage":          {"Arcane", "Fire", "Frost"},
    "Monk":          {"Brewmaster", "Mistweaver", "Windwalker"},
    "Paladin":       {"Holy", "Protection", "Retribution"},
    "Priest":        {"Discipline", "Holy", "Shadow"},
    "Rogue":         {"Assassination", "Outlaw", "Subtlety"},
    "Shaman":        {"Elemental", "Enhancement", "Restoration"},
    "Warlock":       {"Affliction", "Demonology", "Destruction"},
    "Warrior":       {"Arms", "Fury", "Protection"},
}

REQUIRED_FIELDS  = ["summary", "talents", "stats", "url"]
OPTIONAL_FIELDS  = ["gems", "enchants"]

TALENT_STRING_RE = re.compile(r'^[A-Za-z0-9+/=]{40,120}$')
ICYVEIN_URL_RE   = re.compile(r'https?://www\.icy-veins\.com/wow/')

# ── Parser de Builds.lua ──────────────────────────────────────

def parse_builds_lua(filepath: Path) -> dict:
    """
    Extrae los datos de Builds.lua mediante regex.
    Devuelve un dict { clase: { spec: { campo: valor } } }
    """
    content = filepath.read_text(encoding="utf-8")

    result = {}

    # Extraer clases
    class_pattern = re.compile(
        r'\["([^"]+)"\]\s*=\s*\{(.*?)\n    \}',
        re.DOTALL
    )
    # Extraer specs dentro de una clase
    spec_pattern = re.compile(
        r'\["([^"]+)"\]\s*=\s*\{(.*?)\n        \}',
        re.DOTALL
    )
    # Extraer campos dentro de una spec
    field_str_pattern = re.compile(r'(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"')
    field_tbl_pattern = re.compile(r'(\w+)\s*=\s*\{([^}]*)\}')

    for class_match in class_pattern.finditer(content):
        class_name = class_match.group(1)
        class_body = class_match.group(2)
        result[class_name] = {}

        for spec_match in spec_pattern.finditer(class_body):
            spec_name = spec_match.group(1)
            spec_body = spec_match.group(2)
            build = {}

            # Campos de tipo string
            for m in field_str_pattern.finditer(spec_body):
                key = m.group(1)
                val = m.group(2).replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')
                build[key] = val

            # Campos de tipo tabla (stats)
            for m in field_tbl_pattern.finditer(spec_body):
                key = m.group(1)
                if key in build:
                    continue  # ya fue capturado como string
                items_raw = m.group(2)
                items = re.findall(r'"([^"]*)"', items_raw)
                build[key] = items

            result[class_name][spec_name] = build

    return result


# ── Runner de validaciones ────────────────────────────────────

class Validator:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.warnings = 0

    def ok(self, msg):
        print(f"  {PASS}  {msg}")
        self.passed += 1

    def fail(self, msg):
        print(f"  {FAIL}  {RED}{msg}{RESET}")
        self.failed += 1

    def warn(self, msg):
        print(f"  {WARN}  {YELLOW}{msg}{RESET}")
        self.warnings += 1

    def section(self, title):
        print(f"\n{BOLD}{CYAN}┌─ {title}{RESET}")

    def end_section(self):
        print(f"{CYAN}└─────────────────────────────────────────{RESET}")


def validate(data: dict, v: Validator):

    # ── 1. Clases presentes ────────────────────────────────
    v.section("Clases presentes")
    for cls in sorted(EXPECTED_CLASSES.keys()):
        if cls in data:
            v.ok(f"{cls}")
        else:
            v.fail(f"Clase no encontrada: {cls}")
    v.end_section()

    # ── 2. Clases extra (no esperadas) ─────────────────────
    v.section("Clases inesperadas (no deberían estar)")
    extra = set(data.keys()) - set(EXPECTED_CLASSES.keys())
    if extra:
        for cls in sorted(extra):
            v.warn(f"Clase extra encontrada: {cls}")
    else:
        v.ok("No hay clases extra")
    v.end_section()

    # ── 3. Specs por clase ─────────────────────────────────
    v.section("Specs por clase")
    for cls, expected_specs in sorted(EXPECTED_CLASSES.items()):
        if cls not in data:
            continue
        actual_specs = set(data[cls].keys())
        for spec in sorted(expected_specs):
            if spec in actual_specs:
                v.ok(f"{cls} > {spec}")
            else:
                v.fail(f"{cls} > {spec}  ← falta")
        extra_specs = actual_specs - expected_specs
        for spec in sorted(extra_specs):
            v.warn(f"{cls} > {spec}  ← spec extra no esperada")
    v.end_section()

    # ── 4. Campos obligatorios ─────────────────────────────
    v.section("Campos obligatorios por build")
    for cls in sorted(data.keys()):
        for spec in sorted(data[cls].keys()):
            build = data[cls][spec]
            ctx = f"{cls} > {spec}"
            for field in REQUIRED_FIELDS:
                if field not in build:
                    v.fail(f"{ctx}: falta campo '{field}'")
                elif isinstance(build[field], str) and build[field].strip() == "":
                    if field == "talents":
                        v.warn(f"{ctx}: 'talents' está vacío (sin talent string)")
                    else:
                        v.fail(f"{ctx}: campo '{field}' está vacío")
                elif isinstance(build[field], list) and len(build[field]) == 0:
                    v.fail(f"{ctx}: campo '{field}' es una lista vacía")
                else:
                    pass  # ok, no imprimir una línea por cada campo correcto
    v.ok("Todos los campos obligatorios validados")
    v.end_section()

    # ── 5. Validación de URLs ─────────────────────────────
    v.section("URLs de Icy Veins")
    bad_urls = []
    for cls in sorted(data.keys()):
        for spec in sorted(data[cls].keys()):
            url = data[cls][spec].get("url", "")
            if not ICYVEIN_URL_RE.match(url):
                bad_urls.append(f"{cls} > {spec}: {url!r}")
    if bad_urls:
        for b in bad_urls:
            v.fail(f"URL inválida: {b}")
    else:
        v.ok(f"Todas las URLs apuntan a icy-veins.com")
    v.end_section()

    # ── 6. Formato de talent strings ───────────────────────
    v.section("Formato de talent strings")
    bad_talents  = []
    empty_talents = []
    for cls in sorted(data.keys()):
        for spec in sorted(data[cls].keys()):
            t = data[cls][spec].get("talents", "")
            if not t or t.strip() == "":
                empty_talents.append(f"{cls} > {spec}")
            elif not TALENT_STRING_RE.match(t):
                bad_talents.append(f"{cls} > {spec}: {t!r}")
    if empty_talents:
        v.warn(f"{len(empty_talents)} specs sin talent string (se necesita scraper real)")
    if bad_talents:
        for b in bad_talents:
            v.fail(f"Talent string con formato inválido: {b}")
    if not bad_talents:
        v.ok("Ningún talent string tiene formato inválido")
    v.end_section()

    # ── 7. Stats ───────────────────────────────────────────
    v.section("Prioridad de stats")
    for cls in sorted(data.keys()):
        for spec in sorted(data[cls].keys()):
            stats = data[cls][spec].get("stats", [])
            if isinstance(stats, list) and len(stats) < 2:
                v.warn(f"{cls} > {spec}: menos de 2 stats ({stats})")
    v.ok("Validación de stats completada")
    v.end_section()


# ── Main ──────────────────────────────────────────────────────

def main():
    builds_path = Path("data/Builds.lua")

    print(f"\n{BOLD}{'=' * 60}{RESET}")
    print(f"{BOLD}  BuildViewer — Validador de data/Builds.lua{RESET}")
    print(f"{BOLD}{'=' * 60}{RESET}")

    if not builds_path.exists():
        print(f"\n{RED}ERROR: No se encontró el archivo {builds_path}{RESET}")
        print("Ejecuta este script desde la raíz del proyecto BuildViewer/")
        sys.exit(1)

    print(f"\nArchivo: {builds_path.resolve()}")
    print(f"Tamaño:  {builds_path.stat().st_size:,} bytes")

    print("\nParsando Builds.lua...")
    data = parse_builds_lua(builds_path)

    total_classes = len(data)
    total_specs   = sum(len(specs) for specs in data.values())
    print(f"Encontradas: {total_classes} clases, {total_specs} specs\n")

    v = Validator()
    validate(data, v)

    print(f"\n{BOLD}{'=' * 60}{RESET}")
    print(
        f"{BOLD}  RESULTADO: "
        f"{GREEN}{v.passed} pasados{RESET}  "
        f"{RED}{v.failed} fallados{RESET}  "
        f"{YELLOW}{v.warnings} avisos{RESET}"
        f"{BOLD}{RESET}"
    )
    print(f"{BOLD}{'=' * 60}{RESET}\n")

    sys.exit(1 if v.failed > 0 else 0)


if __name__ == "__main__":
    main()
