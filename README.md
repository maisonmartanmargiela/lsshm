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
  { "name": "SNR-S4550-MAIN", "address": "10.110.231.74" },
  { "name": "SNR-S4550-BRANCH", "address": "10.110.231.75" }
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
