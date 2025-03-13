#!/usr/bin/env python3
import requests
import json
import argparse
from typing import List, Dict
import re

class ModInfo:
    def __init__(self, name: str, url: str, version: str, description: str):
        self.name = name
        self.url = url
        self.version = version
        self.description = description

    def to_terraform(self) -> str:
        return f'''  {{
    name        = "{self.name}"
    url         = "{self.url}"
    version     = "{self.version}"
    description = "{self.description}"
  }}'''

def parse_minecraft_version(forge_version: str) -> str:
    """Extract Minecraft version from Forge version string."""
    match = re.match(r'(\d+\.\d+\.\d+)-\d+\.\d+\.\d+', forge_version)
    if match:
        return match.group(1)
    return None

def get_curseforge_mods(minecraft_version: str, api_key: str) -> List[ModInfo]:
    """Fetch mods from CurseForge API."""
    headers = {
        'x-api-key': api_key,
        'Content-Type': 'application/json'
    }
    
    url = "https://api.curseforge.com/v1/mods/search"
    params = {
        'gameId': 432,  # Minecraft
        'classId': 6,   # Mods
        'sortField': 2, # Popularity
        'sortOrder': 'desc',
        'pageSize': 50
    }
    
    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
        
        mods = []
        for mod in data['data']:
            # Find the latest file compatible with the Minecraft version
            for file in mod['latestFiles']:
                if minecraft_version in file['gameVersions']:
                    mods.append(ModInfo(
                        name=mod['slug'],
                        url=file['downloadUrl'],
                        version=file['displayName'],
                        description=mod['summary']
                    ))
                    break
        
        return mods
    except Exception as e:
        print(f"Error fetching from CurseForge: {e}")
        return []

def get_modrinth_mods(minecraft_version: str) -> List[ModInfo]:
    """Fetch mods from Modrinth API."""
    url = "https://api.modrinth.com/v2/search"
    params = {
        'facets': f'[["project_type:mod"],["versions:{minecraft_version}"]]',
        'limit': 50
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        
        mods = []
        for hit in data['hits']:
            # Get the latest version
            version_url = f"https://api.modrinth.com/v2/project/{hit['project_id']}/version"
            version_response = requests.get(version_url)
            version_data = version_response.json()
            
            if version_data:
                latest_version = version_data[0]
                mods.append(ModInfo(
                    name=hit['slug'],
                    url=latest_version['files'][0]['url'],
                    version=latest_version['version_number'],
                    description=hit['description']
                ))
        
        return mods
    except Exception as e:
        print(f"Error fetching from Modrinth: {e}")
        return []

def main():
    parser = argparse.ArgumentParser(description='List compatible mods for a Forge version')
    parser.add_argument('forge_version', help='Forge version (e.g., 1.20.1-47.2.0)')
    parser.add_argument('--output', '-o', help='Output file for Terraform configuration')
    parser.add_argument('--curseforge-key', '-k', help='CurseForge API key (required for CurseForge mods)')
    args = parser.parse_args()

    minecraft_version = parse_minecraft_version(args.forge_version)
    if not minecraft_version:
        print("Invalid Forge version format")
        return

    print(f"Fetching mods compatible with Minecraft {minecraft_version}...")
    
    # Fetch mods from both sources
    curseforge_mods = []
    if args.curseforge_key:
        curseforge_mods = get_curseforge_mods(minecraft_version, args.curseforge_key)
    else:
        print("Skipping CurseForge mods (no API key provided)")
    
    modrinth_mods = get_modrinth_mods(minecraft_version)
    
    # Combine and deduplicate mods
    all_mods = {mod.name: mod for mod in curseforge_mods + modrinth_mods}.values()
    
    # Generate Terraform configuration
    terraform_config = '''variable "mods" {
  description = "List of mods to install on the server"
  type = list(object({
    name        = string
    url         = string
    version     = string
    description = string
  }))
  default = [
'''
    
    for mod in all_mods:
        terraform_config += mod.to_terraform() + ",\n"
    
    terraform_config += '''  ]
}'''
    
    if args.output:
        with open(args.output, 'w') as f:
            f.write(terraform_config)
        print(f"Configuration written to {args.output}")
    else:
        print(terraform_config)

if __name__ == "__main__":
    main() 