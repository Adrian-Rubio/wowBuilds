# scrape_icyvein.py - v3.5 (Flexible Midnight Edition)
import requests
from bs4 import BeautifulSoup
import re
import time
import os

# Configuración
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
}

# Mapeo de Clases y Specs (Icy Veins URLs)
CLASSES = {
    "Death Knight": {
        "Blood": "https://www.icy-veins.com/wow/blood-death-knight-pve-tank-guide",
        "Frost": "https://www.icy-veins.com/wow/frost-death-knight-pve-dps-guide",
        "Unholy": "https://www.icy-veins.com/wow/unholy-death-knight-pve-dps-guide"
    },
    "Demon Hunter": {
        "Havoc": "https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-guide",
        "Vengeance": "https://www.icy-veins.com/wow/vengeance-demon-hunter-pve-tank-guide"
    },
    "Druid": {
        "Balance": "https://www.icy-veins.com/wow/balance-druid-pve-dps-guide",
        "Feral": "https://www.icy-veins.com/wow/feral-druid-pve-dps-guide",
        "Guardian": "https://www.icy-veins.com/wow/guardian-druid-pve-tank-guide",
        "Restoration": "https://www.icy-veins.com/wow/restoration-druid-pve-healing-guide"
    },
    "Evoker": {
        "Augmentation": "https://www.icy-veins.com/wow/augmentation-evoker-pve-dps-guide",
        "Devastation": "https://www.icy-veins.com/wow/devastation-evoker-pve-dps-guide",
        "Preservation": "https://www.icy-veins.com/wow/preservation-evoker-pve-healing-guide"
    },
    "Hunter": {
        "Beast Mastery": "https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-guide",
        "Marksmanship": "https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-guide",
        "Survival": "https://www.icy-veins.com/wow/survival-hunter-pve-dps-guide"
    },
    "Mage": {
        "Arcane": "https://www.icy-veins.com/wow/arcane-mage-pve-dps-guide",
        "Fire": "https://www.icy-veins.com/wow/fire-mage-pve-dps-guide",
        "Frost": "https://www.icy-veins.com/wow/frost-mage-pve-dps-guide"
    },
    "Monk": {
        "Brewmaster": "https://www.icy-veins.com/wow/brewmaster-monk-pve-tank-guide",
        "Mistweaver": "https://www.icy-veins.com/wow/mistweaver-monk-pve-healing-guide",
        "Windwalker": "https://www.icy-veins.com/wow/windwalker-monk-pve-dps-guide"
    },
    "Paladin": {
        "Holy": "https://www.icy-veins.com/wow/holy-paladin-pve-healing-guide",
        "Protection": "https://www.icy-veins.com/wow/protection-paladin-pve-tank-guide",
        "Retribution": "https://www.icy-veins.com/wow/retribution-paladin-pve-dps-guide"
    },
    "Priest": {
        "Discipline": "https://www.icy-veins.com/wow/discipline-priest-pve-healing-guide",
        "Holy": "https://www.icy-veins.com/wow/holy-priest-pve-healing-guide",
        "Shadow": "https://www.icy-veins.com/wow/shadow-priest-pve-dps-guide"
    },
    "Rogue": {
        "Assassination": "https://www.icy-veins.com/wow/assassination-rogue-pve-dps-guide",
        "Outlaw": "https://www.icy-veins.com/wow/outlaw-rogue-pve-dps-guide",
        "Subtlety": "https://www.icy-veins.com/wow/subtlety-rogue-pve-dps-guide"
    },
    "Shaman": {
        "Elemental": "https://www.icy-veins.com/wow/elemental-shaman-pve-dps-guide",
        "Enhancement": "https://www.icy-veins.com/wow/enhancement-shaman-pve-dps-guide",
        "Restoration": "https://www.icy-veins.com/wow/restoration-shaman-pve-healing-guide"
    },
    "Warlock": {
        "Affliction": "https://www.icy-veins.com/wow/affliction-warlock-pve-dps-guide",
        "Demonology": "https://www.icy-veins.com/wow/demonology-warlock-pve-dps-guide",
        "Destruction": "https://www.icy-veins.com/wow/destruction-warlock-pve-dps-guide"
    },
    "Warrior": {
        "Arms": "https://www.icy-veins.com/wow/arms-warrior-pve-dps-guide",
        "Fury": "https://www.icy-veins.com/wow/fury-warrior-pve-dps-guide",
        "Protection": "https://www.icy-veins.com/wow/protection-warrior-pve-tank-guide"
    }
}

SLOT_MAP = {
    "head": "Head", "helm": "Head",
    "neck": "Neck",
    "shoulder": "Shoulder", "shoulders": "Shoulder",
    "back": "Back", "cloak": "Back",
    "chest": "Chest",
    "wrist": "Wrist", "wrists": "Wrist", "bracers": "Wrist",
    "hands": "Hands", "gloves": "Hands",
    "waist": "Waist", "belt": "Waist",
    "legs": "Legs",
    "feet": "Feet", "boots": "Feet",
    "finger": "Finger1", "ring": "Finger1",
    "trinket": "Trinket1",
    "weapon": "MainHand", "hand": "MainHand",
    "off-hand": "OffHand", "shield": "OffHand",
}

def fetch_page(url: str):
    try:
        r = requests.get(url, headers=HEADERS, timeout=15)
        r.raise_for_status()
        return BeautifulSoup(r.text, "lxml")
    except: return None

def clean(t): return re.sub(r'\s+', ' ', t).strip()

def extract_gear(soup):
    if not soup: return {}
    gear = {}
    
    # Buscar tablas con encabezados "Slot" o que contengan palabras clave
    for table in soup.find_all("table"):
        found_rows = False
        for tr in table.find_all("tr"):
            cols = tr.find_all(["td", "th"])
            if len(cols) < 2: continue
            
            orig_slot_text = clean(cols[0].get_text()).lower()
            slot = None
            
            # Intento de matching robusto
            for key, val in SLOT_MAP.items():
                if key in orig_slot_text:
                    slot = val
                    break
            
            if not slot: continue
            
            # Manejar duplicados de Finger y Trinket (Finger #1, Ring 1, etc)
            if slot == "Finger1" and ("#2" in orig_slot_text or "2" in orig_slot_text): slot = "Finger2"
            elif slot == "Trinket1" and ("#2" in orig_slot_text or "2" in orig_slot_text): slot = "Trinket2"

            items = []
            for span in cols[1].find_all("span", attrs={'data-wowhead': True}):
                attr = span.get('data-wowhead', '')
                m = re.search(r'item=(\d+)', attr)
                if m:
                    items.append({"id": int(m.group(1)), "name": clean(span.get_text())})
            
            if items:
                gear[slot] = items
                found_rows = True
        
        if found_rows and len(gear) > 5: return gear # Encontramos la tabla buena
    
    return gear

def scrape():
    print("Iniciando Scraper v3.5...")
    final_data = {}
    
    for cls, specs in CLASSES.items():
        final_data[cls] = {}
        for spec, url in specs.items():
            print(f"Scrapeando {cls} - {spec}...")
            main_soup = fetch_page(url)
            
            summary = "Consulte Icy Veins."
            stats = []
            if main_soup:
                intro = main_soup.find(id="introduction")
                if intro:
                    p = intro.find_next("p")
                    if p: summary = p.get_text(strip=True)
                
                stat_sec = main_soup.find(id="stat-priority")
                if stat_sec:
                    ol = stat_sec.find_next(["ol", "ul"])
                    if ol:
                        for li in ol.find_all("li", limit=6):
                            s_text = re.sub(r"\(.*?\)", "", li.get_text(strip=True)).strip()
                            if s_text: stats.append(s_text)

            # Gear extraction
            gear_url = url.replace("-guide", "-gear-best-in-slot")
            builds = {}
            contexts = {"Overall": gear_url + "?area=area_1", "Raid": gear_url + "?area=area_2", "Mythic+": gear_url + "?area=area_3"}
            
            for ctx, c_url in contexts.items():
                s = fetch_page(c_url)
                builds[ctx] = {"talents": "", "gear": extract_gear(s)}
                time.sleep(0.2)
            
            final_data[cls][spec] = {
                "summary": summary,
                "stats": stats,
                "url": url,
                "builds": builds
            }
            time.sleep(0.5)

    # Write to Builds.lua
    with open("data/Builds.lua", "w", encoding="utf-8") as f:
        f.write("-- BuildViewerData v3.5 (Midnight Fix)\n")
        f.write("BuildViewerData = {\n")
        for cls, specs in final_data.items():
            f.write(f'    ["{cls}"] = {{\n')
            for spec, data in specs.items():
                f.write(f'        ["{spec}"] = {{\n')
                f.write(f'            summary = "{data["summary"].replace(chr(34), chr(39))}",\n')
                f.write(f'            stats   = {{ {", ".join([chr(34)+s+chr(34) for s in data["stats"]])} }},\n')
                f.write(f'            url     = "{data["url"]}",\n')
                f.write(f'            builds  = {{\n')
                for ctx, b in data["builds"].items():
                    f.write(f'                ["{ctx}"] = {{\n')
                    f.write(f'                    talents = "{b["talents"]}",\n')
                    f.write(f'                    gear    = {{\n')
                    for slot, items in b["gear"].items():
                        items_str = ", ".join([f'{{ id = {i["id"]}, name = "{i["name"].replace(chr(34), chr(39))}" }}' for i in items])
                        f.write(f'                        ["{slot}"] = {{ {items_str} }},\n')
                    f.write(f'                    }},\n')
                    f.write(f'                }},\n')
                f.write(f'            }},\n')
                f.write(f'        }},\n')
            f.write(f'    }},\n')
        f.write("}\n")
    print("Scraper finalizado con éxito.")

if __name__ == "__main__":
    scrape()
