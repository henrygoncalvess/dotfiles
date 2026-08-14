#!/usr/bin/env python3
import subprocess, json, sys, os, re

def get_icon(stars):
    s = stars.strip()
    if s == "****": return "󰤨"
    elif s == "***": return "󰤥"
    elif s == "**": return "󰤢"
    elif s == "*": return "󰤟"
    return "󰤯"

def main():
    try:
        # sysfs check
        if not os.path.exists('/sys/class/net'):
            raise Exception("no net")
        
        interfaces = [f for f in os.listdir('/sys/class/net') if os.path.exists(f'/sys/class/net/{f}/wireless')]
        if not interfaces:
            print(json.dumps({"present": False, "power": "off", "connected": None, "networks": []}))
            return
            
        iface = interfaces[0]
        
        # Check power
        try:
            operstate = open(f'/sys/class/net/{iface}/operstate').read().strip()
        except:
            operstate = "down"
            
        # iwd state
        try:
            show_out = subprocess.check_output(['iwctl', 'station', iface, 'show'], text=True)
            show_out = re.sub(r'\x1b\[[0-9;]*m', '', show_out)
        except:
            show_out = ""
            
        is_powered = "off"
        if "State" in show_out:
            is_powered = "on"
            
        connected_network = None
        for line in show_out.split('\n'):
            if "Connected network" in line:
                parts = re.split(r'\s{2,}', line.strip())
                if len(parts) >= 2:
                    ssid = parts[1].strip()
                    
                    ip = "No IP"
                    try:
                        ip_out = subprocess.check_output(['ip', '-4', 'addr', 'show', 'dev', iface], text=True)
                        match = re.search(r'inet\s+(\d+\.\d+\.\d+\.\d+)', ip_out)
                        if match: ip = match.group(1)
                    except: pass
                    
                    freq = "Unknown"
                    try:
                        iw_out = subprocess.check_output(['iw', 'dev', iface, 'link'], text=True)
                        match = re.search(r'freq:\s+(\d+)', iw_out)
                        if match: freq = f"{match.group(1)} MHz"
                    except: pass
                    
                    connected_network = {
                        "id": ssid,
                        "ssid": ssid,
                        "icon": "󰤨",
                        "signal": "100",
                        "security": "",
                        "ip": ip,
                        "freq": freq
                    }

        networks = []
        try:
            net_out = subprocess.check_output(['iwctl', 'station', iface, 'get-networks'], text=True)
            net_out = re.sub(r'\x1b\[[0-9;]*m', '', net_out)
            
            lines = net_out.split('\n')
            for i, line in enumerate(lines):
                if i <= 4: continue
                if not line.strip(): continue
                
                # Check for active >
                is_active = line.startswith('>')
                if is_active: line = line[1:]
                
                parts = re.split(r'\s{2,}', line.strip())
                if len(parts) >= 3:
                    ssid = parts[0].strip()
                    sec = parts[1].strip()
                    stars = parts[2].strip()
                    
                    if connected_network and connected_network["ssid"] == ssid:
                        connected_network["security"] = sec
                        connected_network["icon"] = get_icon(stars)
                        continue
                        
                    networks.append({
                        "id": ssid,
                        "ssid": ssid,
                        "icon": get_icon(stars),
                        "signal": str(len(stars) * 25),
                        "security": sec
                    })
        except:
            pass
            
        print(json.dumps({
            "present": True,
            "power": is_powered,
            "connected": connected_network,
            "networks": networks
        }))
        
    except Exception as e:
        print(json.dumps({"present": False, "power": "off", "connected": None, "networks": []}))

if __name__ == "__main__":
    main()
