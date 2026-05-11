# lsshm

A lightweight Bash tool for quickly connecting to network devices via SSH using a searchable interactive menu.

## Setup

```bash
chmod +x ssh-connect.sh
```

## Usage

```bash
./lsshm.sh
```

## Files

**devices.json** — list of devices:
```json
[
  { "name": "Device 1", "address": "192.168.1.1" },
  { "name": "Device 2", "address": "192.168.1.2" }
]
```

**user.json** — credentials:
```json
{
  "login": "admin",
  "password": "yourpassword"
}
```

## Controls

| Key | Action |
|-----|--------|
| Type | Filter devices |
| ↑ ↓ | Navigate |
| Enter | Connect |
| Esc | Exit |
