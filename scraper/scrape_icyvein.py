#!/usr/bin/env python3
"""
scrape_icyvein.py v2.1
======================
Extracción avanzada de builds:
- Soporte para contextos: Overall, Raid, Mythic+
- Extracción de Talent Strings desde páginas específicas.
- Extracción de BiS Gear (Best in Slot) categorizado.
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

REQUEST_DELAY = 1.0

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
        "Restoration": "https://www.icy-veins.com/wow/restoration-druid-pve-healing-guide",
    },
    "Evoker": {
        "Devastation":  "https://www.icy-veins.com/wow/devastation-evoker-pve-dps-guide",
        "Preservation": "https://www.icy-veins.com/wow/preservation-evoker-pve-healing-guide",
        "Augmentation": "https://www.icy-veins.com/wow/augmentation-evoker-pve-dps-guide",
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
        "Mistweaver":  "https://www.icy-veins.com/wow/mistweaver-monk-pve-healing-guide",
        "Windwalker":  "https://www.icy-veins.com/wow/windwalker-monk-pve-dps-guide",
    },
    "Paladin": {
        "Holy":       "https://www.icy-veins.com/wow/holy-paladin-pve-healing-guide",
        "Protection": "https://www.icy-veins.com/wow/protection-paladin-pve-tank-guide",
        "Retribution":"https://www.icy-veins.com/wow/retribution-paladin-pve-dps-guide",
    },
    "Priest": {
        "Discipline": "https://www.icy-veins.com/wow/discipline-priest-pve-healing-guide",
        "Holy":       "https://www.icy-veins.com/wow/holy-priest-pve-healing-guide",
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
        "Restoration":  "https://www.icy-veins.com/wow/restoration-shaman-pve-healing-guide",
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
#  FUNCIONES DE APOYO
# ─────────────────────────────────────────────────────────

def fetch_page(url: str) -> BeautifulSoup | None:
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "lxml")
    except Exception as e:
        print(f"  ERROR: {e}")
        return None

def clean_text(text: str) -> str:
    return re.sub(r'\s+', ' ', text).strip()

def extract_summary(soup: BeautifulSoup) -> str:
    intro_section = soup.find(id="introduction")
    if intro_section:
        p = intro_section.find_next("p")
        if p: return p.get_text(strip=True)
    article = soup.find("article") or soup.find("div", class_="content")
    if article:
        p = article.find("p")
        if p: return p.get_text(strip=True)
    return "Consulte Icy Veins."

def extract_stats(soup: BeautifulSoup) -> list[str]:
    stats = []
    section = soup.find(id="stat-priority") or soup.find(id="stats")
    if section:
        ol = section.find_next(["ol", "ul"])
        if ol:
            for li in ol.find_all("li", limit=6):
                text = re.sub(r"\s*\(.*?\)", "", li.get_text(strip=True)).strip()
                if text: stats.append(text)
    if not stats:
        text = soup.get_text()
        match = re.search(r"stat priority[:\s]+([A-Za-z ,>≥=]+?)(?:\n|\.|;)", text, re.IGNORECASE)
        if match:
            stats = [s.strip() for s in re.split(r"[,>]", match.group(1)) if s.strip()]
    return stats[:6]

# ─────────────────────────────────────────────────────────
#  EXTRACCIÓN DE TALENTOS
# ─────────────────────────────────────────────────────────

def extract_talents_from_page(url: str) -> dict:
    data = {"Overall": "", "Raid": "", "Mythic+": ""}
    soup = fetch_page(url)
    if not soup: return data

    all_strings = []
    # Usar regex para encontrar strings de talentos válidos
    pattern = re.compile(r"[A-Za-z0-9+/=]{50,1000}")
    
    # Buscar en elementos con clases comunes de Icy Veins
    for tag in soup.find_all(["code", "textarea", "span", "div"]):
        text = tag.get_text(strip=True)
        if pattern.fullmatch(text) and not text.startswith('Alchemy'):
            all_strings.append(text)
    
    # Eliminar duplicados manteniendo orden
    seen = set()
    unique_strings = [x for x in all_strings if not (x in seen or seen.add(x))]

    if not unique_strings: return data

    data["Raid"] = unique_strings[0]
    data["Overall"] = unique_strings[0]
    if len(unique_strings) > 1:
        data["Mythic+"] = unique_strings[1]
    else:
        data["Mythic+"] = unique_strings[0]
        
    return data

# ─────────────────────────────────────────────────────────
#  EXTRACCIÓN DE EQUIPO (BiS)
# ─────────────────────────────────────────────────────────

def extract_gear_table(soup: BeautifulSoup) -> str:
    table = soup.find("table")
    if not table: return ""
    
    rows = []
    for tr in table.find_all("tr"):
        cols = tr.find_all(["td", "th"])
        if len(cols) >= 2:
            slot = clean_text(cols[0].get_text())
            item = clean_text(cols[1].get_text())
            if slot and item and slot.lower() != "slot":
                rows.append(f"{slot}: {item}")
    
    return "\n".join(rows)

def fetch_bis_gear(base_url: str) -> dict:
    gear_url = base_url.replace("-guide", "-gear-best-in-slot")
    # Limpiar posibles terminaciones de rol
    results = {"Overall": "", "Raid": "", "Mythic+": ""}
    
    areas = {
        "Overall":  gear_url + "?area=area_1",
        "Raid":     gear_url + "?area=area_2",
        "Mythic+":  gear_url + "?area=area_3"
    }
    
    for context, url in areas.items():
        print(f"    - Fetching gear {context}...")
        soup = fetch_page(url)
        if soup:
            results[context] = extract_gear_table(soup)
        time.sleep(0.3)
            
    return results

# ─────────────────────────────────────────────────────────
#  PROCESAMIENTO DE ESPECIFICACIÓN
# ─────────────────────────────────────────────────────────

def process_spec(class_name, spec_name, main_url):
    print(f"--- [{class_name}] {spec_name} ---")
    
    soup_main = fetch_page(main_url)
    summary = "Consulte Icy Veins."
    stats = []
    if soup_main:
        summary = extract_summary(soup_main)
        stats = extract_stats(soup_main)
    
    talents_url = main_url.replace("-guide", "-spec-builds-talents")
    print(f"  -> {talents_url}")
    talents_data = extract_talents_from_page(talents_url)
    
    print(f"  -> Gear Search...")
    gear_data = fetch_bis_gear(main_url)
    
    return {
        "summary": summary,
        "stats": stats,
        "url": main_url,
        "builds": {
            "Overall":  {"talents": talents_data["Overall"],  "gear": gear_data["Overall"]},
            "Raid":     {"talents": talents_data["Raid"],     "gear": gear_data["Raid"]},
            "Mythic+":  {"talents": talents_data["Mythic+"], "gear": gear_data["Mythic+"]},
        }
    }

# ─────────────────────────────────────────────────────────
#  GENERACIÓN LUA
# ─────────────────────────────────────────────────────────

def build_lua_file(data):
    today = datetime.date.today().isoformat()
    lines = [
        "-- BuildViewerData v2.1",
        f"-- Última actualización: {today}",
        "BuildViewerData = {",
    ]
    
    def lua_str(s):
        s = (s or "").replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{s}"'

    for cls in sorted(data.keys()):
        lines.append(f'    [{lua_str(cls)}] = {{')
        for spec in sorted(data[cls].keys()):
            build = data[cls][spec]
            lines.append(f'        [{lua_str(spec)}] = {{')
            lines.append(f'            summary = {lua_str(build["summary"])},')
            lines.append(f'            stats   = {{' + ", ".join([lua_str(s) for s in build["stats"]]) + '},')
            lines.append(f'            url     = {lua_str(build["url"])},')
            lines.append(f'            builds  = {{')
            for ctx, b in build["builds"].items():
                lines.append(f'                [{lua_str(ctx)}] = {{')
                lines.append(f'                    talents = {lua_str(b["talents"])},')
                lines.append(f'                    gear    = {lua_str(b["gear"])},')
                lines.append(f'                }},')
            lines.append(f'            }},')
            lines.append(f'        }},')
        lines.append(f'    }},')
    lines.append("}")
    return "\n".join(lines)

# ─────────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────────

def main():
    all_data = {}
    for cls, specs in GUIDES.items():
        all_data[cls] = {}
        for spec, url in specs.items():
            all_data[cls][spec] = process_spec(cls, spec, url)
            time.sleep(REQUEST_DELAY)
            
    lua_content = build_lua_file(all_data)
    OUTPUT_FILE.write_text(lua_content, encoding="utf-8")
    print("\n¡Proceso completado con éxito!")

if __name__ == "__main__":
    main()
