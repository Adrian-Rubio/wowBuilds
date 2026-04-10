#!/usr/bin/env python3
"""
scrape_icyvein.py
=================
Descarga las guías de builds de Icy Veins para WoW retail y genera
el archivo data/Builds.lua que usa el addon BuildViewer.

Uso:
    pip install requests beautifulsoup4 lxml
    python scraper/scrape_icyvein.py

El archivo data/Builds.lua se sobreescribe con los datos frescos.
"""

import re
import time
import datetime
from pathlib import Path
import requests
from bs4 import BeautifulSoup

# ─────────────────────────────────────────────────────────
#  CONFIGURACIÓN
# ─────────────────────────────────────────────────────────

OUTPUT_FILE = Path(__file__).parent.parent / "data" / "Builds.lua"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    )
}

# Delay entre peticiones para no sobrecargar el servidor (segundos)
REQUEST_DELAY = 1.5

# Mapa de clase → spec → URL de la guía en Icy Veins
# Actualiza estas URLs si Icy Veins cambia la estructura para una nueva expansión.
GUIDES = {
    "Death Knight": {
        "Blood":  "https://www.icy-veins.com/wow/blood-death-knight-pve-tank-guide",
        "Frost":  "https://www.icy-veins.com/wow/frost-death-knight-pve-dps-guide",
        "Unholy": "https://www.icy-veins.com/wow/unholy-death-knight-pve-dps-guide",
    },
    "Demon Hunter": {
        "Havoc":      "https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-guide",
        "Vengeance":  "https://www.icy-veins.com/wow/vengeance-demon-hunter-pve-tank-guide",
    },
    "Druid": {
        "Balance":     "https://www.icy-veins.com/wow/balance-druid-pve-dps-guide",
        "Feral":       "https://www.icy-veins.com/wow/feral-druid-pve-dps-guide",
        "Guardian":    "https://www.icy-veins.com/wow/guardian-druid-pve-tank-guide",
        "Restoration": "https://www.icy-veins.com/wow/restoration-druid-pve-healer-guide",
    },
    "Evoker": {
        "Devastation":  "https://www.icy-veins.com/wow/devastation-evoker-pve-dps-guide",
        "Preservation": "https://www.icy-veins.com/wow/preservation-evoker-pve-healer-guide",
        "Augmentation": "https://www.icy-veins.com/wow/augmentation-evoker-pve-support-guide",
    },
    "Hunter": {
        "Beast Mastery":   "https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-guide",
        "Marksmanship":    "https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-guide",
        "Survival":        "https://www.icy-veins.com/wow/survival-hunter-pve-dps-guide",
    },
    "Mage": {
        "Arcane": "https://www.icy-veins.com/wow/arcane-mage-pve-dps-guide",
        "Fire":   "https://www.icy-veins.com/wow/fire-mage-pve-dps-guide",
        "Frost":  "https://www.icy-veins.com/wow/frost-mage-pve-dps-guide",
    },
    "Monk": {
        "Brewmaster":  "https://www.icy-veins.com/wow/brewmaster-monk-pve-tank-guide",
        "Mistweaver":  "https://www.icy-veins.com/wow/mistweaver-monk-pve-healer-guide",
        "Windwalker":  "https://www.icy-veins.com/wow/windwalker-monk-pve-dps-guide",
    },
    "Paladin": {
        "Holy":       "https://www.icy-veins.com/wow/holy-paladin-pve-healer-guide",
        "Protection": "https://www.icy-veins.com/wow/protection-paladin-pve-tank-guide",
        "Retribution":"https://www.icy-veins.com/wow/retribution-paladin-pve-dps-guide",
    },
    "Priest": {
        "Discipline": "https://www.icy-veins.com/wow/discipline-priest-pve-healer-guide",
        "Holy":       "https://www.icy-veins.com/wow/holy-priest-pve-healer-guide",
        "Shadow":     "https://www.icy-veins.com/wow/shadow-priest-pve-dps-guide",
    },
    "Rogue": {
        "Assassination": "https://www.icy-veins.com/wow/assassination-rogue-pve-dps-guide",
        "Outlaw":        "https://www.icy-veins.com/wow/outlaw-rogue-pve-dps-guide",
        "Subtlety":      "https://www.icy-veins.com/wow/subtlety-rogue-pve-dps-guide",
    },
    "Shaman": {
        "Elemental":    "https://www.icy-veins.com/wow/elemental-shaman-pve-dps-guide",
        "Enhancement":  "https://www.icy-veins.com/wow/enhancement-shaman-pve-dps-guide",
        "Restoration":  "https://www.icy-veins.com/wow/restoration-shaman-pve-healer-guide",
    },
    "Warlock": {
        "Affliction":   "https://www.icy-veins.com/wow/affliction-warlock-pve-dps-guide",
        "Demonology":   "https://www.icy-veins.com/wow/demonology-warlock-pve-dps-guide",
        "Destruction":  "https://www.icy-veins.com/wow/destruction-warlock-pve-dps-guide",
    },
    "Warrior": {
        "Arms":       "https://www.icy-veins.com/wow/arms-warrior-pve-dps-guide",
        "Fury":       "https://www.icy-veins.com/wow/fury-warrior-pve-dps-guide",
        "Protection": "https://www.icy-veins.com/wow/protection-warrior-pve-tank-guide",
    },
}

# ─────────────────────────────────────────────────────────
#  FUNCIONES DE SCRAPING
# ─────────────────────────────────────────────────────────

def fetch_page(url: str) -> BeautifulSoup | None:
    """Descarga una página y devuelve un objeto BeautifulSoup."""
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "lxml")
    except requests.RequestException as e:
        print(f"  ERROR al descargar {url}: {e}")
        return None


def extract_summary(soup: BeautifulSoup) -> str:
    """
    Extrae el párrafo de introducción/resumen de la guía.
    Icy Veins suele tener el resumen en el primer párrafo de la sección
    con id 'introduction' o dentro del primer <p> del article.
    """
    # Intentar la sección de introducción
    intro_section = soup.find(id="introduction")
    if intro_section:
        p = intro_section.find_next("p")
        if p:
            return p.get_text(strip=True)

    # Fallback: primer párrafo del article principal
    article = soup.find("article") or soup.find("div", class_="content")
    if article:
        p = article.find("p")
        if p:
            return p.get_text(strip=True)

    return "Consulta la guía en Icy Veins para el resumen completo."


def extract_stats(soup: BeautifulSoup) -> list[str]:
    """
    Extrae la prioridad de estadísticas de la guía.
    Icy Veins suele listarlas en una sección con id 'stat-priority'
    o en una lista ordenada (<ol>) cerca de esa sección.
    """
    stats = []

    # Buscar la sección de stats
    section = soup.find(id="stat-priority") or soup.find(id="stats")
    if section:
        # Buscar lista ordenada (ol) o desordenada (ul) cercana
        ol = section.find_next(["ol", "ul"])
        if ol:
            for li in ol.find_all("li", limit=6):
                text = li.get_text(strip=True)
                # Limpiar texto (quitar notas entre paréntesis largas)
                text = re.sub(r"\s*\(.*?\)", "", text).strip()
                if text:
                    stats.append(text)

    # Fallback: buscar en el texto "stat priority" con regex
    if not stats:
        text = soup.get_text()
        match = re.search(
            r"stat priority[:\s]+([A-Za-z ,>≥=]+?)(?:\n|\.|;)",
            text,
            re.IGNORECASE,
        )
        if match:
            raw = match.group(1)
            stats = [s.strip() for s in re.split(r"[,>]", raw) if s.strip()]

    return stats[:6]  # máximo 6 stats


def extract_talents(soup: BeautifulSoup) -> str:
    """
    Busca un talent string importable (cadena larga en base64-like).
    En Icy Veins, estos suelen aparecer en bloques <code> o <textarea>
    cerca de la sección de talentos.
    """
    # Buscar la sección de talentos
    talent_section = (
        soup.find(id="talent-builds")
        or soup.find(id="talents")
        or soup.find(id="builds")
    )

    search_root = talent_section or soup

    # Buscar en elementos <code>, <textarea>, o divs con clase específica
    for tag in search_root.find_all(["code", "textarea", "span", "div"], limit=30):
        text = tag.get_text(strip=True)
        # Un talent string de WoW tiene ~60-80 caracteres alfanuméricos+/+=
        if re.fullmatch(r"[A-Za-z0-9+/=]{50,120}", text):
            return text

    return ""


def extract_gems_enchants(soup: BeautifulSoup) -> tuple[str, str]:
    """
    Extrae información de gemas y encantamientos.
    """
    gems = ""
    enchants = ""

    gem_section = soup.find(id="gems") or soup.find(id="gemming")
    if gem_section:
        p = gem_section.find_next("p")
        if p:
            gems = p.get_text(strip=True)[:200]

    enchant_section = soup.find(id="enchants") or soup.find(id="enchanting")
    if enchant_section:
        p = enchant_section.find_next("p")
        if p:
            enchants = p.get_text(strip=True)[:200]

    return gems, enchants


def scrape_guide(url: str) -> dict:
    """Descarga y parsea una guía de Icy Veins. Devuelve un dict con los datos."""
    print(f"  -> {url}")
    soup = fetch_page(url)
    if not soup:
        return {
            "summary": "No se pudo cargar la guía.",
            "talents": "",
            "stats": [],
            "gems": "",
            "enchants": "",
            "url": url,
        }

    summary  = extract_summary(soup)
    stats    = extract_stats(soup)
    talents  = extract_talents(soup)
    gems, enchants = extract_gems_enchants(soup)

    return {
        "summary":  summary,
        "talents":  talents,
        "stats":    stats,
        "gems":     gems,
        "enchants": enchants,
        "url":      url,
    }

# ─────────────────────────────────────────────────────────
#  GENERACIÓN DEL ARCHIVO LUA
# ─────────────────────────────────────────────────────────

def escape_lua_string(s: str) -> str:
    """Escapa una cadena para usarla de forma segura dentro de [[...]] o comillas Lua."""
    if s is None:
        return ""
    # Usar long strings de Lua [[ ]] para evitar problemas con comillas y backslashes.
    # Si la cadena contiene ]] tenemos que usar un nivel: [=[ ... ]=]
    if "]]" in s:
        return s.replace("\\", "\\\\").replace('"', '\\"')
    return s


def lua_string(s: str) -> str:
    """Envuelve una cadena en comillas Lua escapando lo necesario."""
    s = (s or "").replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{s}"'


def lua_string_list(items: list[str]) -> str:
    """Convierte una lista de strings a una tabla Lua: { "a", "b", "c" }"""
    escaped = [lua_string(i) for i in items]
    return "{ " + ", ".join(escaped) + " }"


def build_lua_file(data: dict) -> str:
    """Genera el contenido completo del archivo Builds.lua."""
    today = datetime.date.today().isoformat()
    lines = [
        "-- BuildViewerData: datos de builds de Icy Veins embebidos como tablas Lua.",
        "-- Este archivo es generado automáticamente por scraper/scrape_icyvein.py",
        f"-- Última actualización: {today}",
        "--",
        "-- Estructura:",
        "--   BuildViewerData[clase][spec] = {",
        "--     summary  = string,",
        "--     talents  = string,   -- talent string importable en WoW",
        "--     stats    = { string, ... },",
        "--     gems     = string,",
        "--     enchants = string,",
        "--     url      = string,",
        "--   }",
        "",
        "BuildViewerData = {",
    ]

    for class_name in sorted(data.keys()):
        specs = data[class_name]
        lines.append(f'    [{lua_string(class_name)}] = {{')
        for spec_name in sorted(specs.keys()):
            build = specs[spec_name]
            lines.append(f'        [{lua_string(spec_name)}] = {{')
            lines.append(f'            summary  = {lua_string(build.get("summary", ""))},')
            lines.append(f'            talents  = {lua_string(build.get("talents", ""))},')
            lines.append(f'            stats    = {lua_string_list(build.get("stats", []))},')
            lines.append(f'            gems     = {lua_string(build.get("gems", ""))},')
            lines.append(f'            enchants = {lua_string(build.get("enchants", ""))},')
            lines.append(f'            url      = {lua_string(build.get("url", ""))},')
            lines.append(f'        }},')
        lines.append(f'    }},')

    lines.append("}")
    lines.append("")
    return "\n".join(lines)

# ─────────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("BuildViewer — Scraper de Icy Veins")
    print("=" * 60)
    print(f"Output: {OUTPUT_FILE}")
    print()

    all_data = {}

    for class_name, specs in GUIDES.items():
        print(f"[{class_name}]")
        all_data[class_name] = {}
        for spec_name, url in specs.items():
            build_data = scrape_guide(url)
            all_data[class_name][spec_name] = build_data
            time.sleep(REQUEST_DELAY)
        print()

    print("Generando Builds.lua...", end=" ")
    lua_content = build_lua_file(all_data)
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(lua_content, encoding="utf-8")
    print("OK")
    print(f"\nArchivo generado: {OUTPUT_FILE}")
    print("\nPróximos pasos:")
    print("  1. Copia la carpeta BuildViewer/ a WoW\\Interface\\AddOns\\")
    print("  2. Entra en el juego y escribe /reload")
    print("  3. Escribe /bv para abrir el addon")


if __name__ == "__main__":
    main()
