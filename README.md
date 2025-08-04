# ipv64updater
## Synology NAS Dynamic DNS Updater for ipv64.net

> [!NOTE]
> I make no claim of correctness or full functionality. As I am not particularly experienced with Bash, this script may contain errors, and I accept no warranty of any kind. This script was created out of necessity to help my friend Straight Shooter solve a DDNS issue involving the excellent service from [ipv64.net](https://ipv64.net). It is designed to be called regularly via the Synology NAS Task Scheduler. I have attempted to implement several fallback routines – whether for repeated invocations or for fetching IP addresses. For my needs the script works: IPv4, IPv6, and IPv6 prefix are correctly passed to ipv64.net. However, you may need to adjust the script for your specific setup. It is also possible that I have implemented some unnecessary logic in the code; please consider this a playful part of my self-study journey.

---

## Features

- Fully Bash-based, ready for use on Synology NAS with DSM Task Scheduler.
- Dynamically updates both IPv4 and IPv6 (including prefix) to ipv64.net.
- Flexible: independent toggles for IPv4/IPv6 updates.
- Robust: automatic fallback to alternative public IP detection services if the first attempt fails.
- Log rotation to avoid oversized logs.
- Minimal external dependencies (uses standard Linux tools and curl).

## How it works

1. **IPv4 Detection**:  
    - Checks `https://checkip.synology.com` for the public IPv4.
    - Falls back to `https://ifconfig.co` if necessary.

2. **IPv6 Detection**:  
    - Tries to read the global IPv6 directly from the specified NAS network interface.
    - If no global IPv6 is configured or detected, falls back to `https://ifconfig.co` using IPv6 (`curl -6`).

3. **Updates to ipv64.net**:  
    - Only pushes an update if the IP(s) has changed or if a minimum interval (e.g., 3 hours) has passed.
    - IPv4, IPv6, and (where possible) IPv6 prefix are sent to the service according to official ipv64.net API schema.

4. **Logging**:  
    - Each update/result is recorded in a persistent log file.
    - Automatic log rotation prevents uncontrolled growth.

---

## Usage

1. Edit the configuration section at the top of the script (key, domain, interface, logging path, etc.).
2. Place the script onto your Synology NAS, for example under `/volume1/docker/ipv64updater.sh`.

> [!NOTE]
> I personally use the `docker` directory as an example because this folder should generally not be encrypted. This ensures the script is always accessible to the DSM Task Scheduler and prevents issues that can arise if the NAS restarts and encrypted shares are not yet mounted or unlocked.

3. Create a scheduled task in DSM Task Scheduler that invokes the script at your desired interval (recommended: not more than once every 3 houers).

---

## Warning & Customization

- The script may require adaption to your network, your version of Synology/DSM, or your personal workflow.
- Please verify correct IPv6 interface selection and adjust `NET_IFACE` accordingly.
- Carefully review log outputs for troubleshooting.

---

# License
This project is licensed under the **[MIT license](https://github.com/ot2i7ba/ipv64updater/blob/main/LICENSE)**, providing users with flexibility and freedom to use and modify the software according to their needs.

# Contributing
Contributions are welcome! Please fork the repository and submit a pull request for review.

# Disclaimer
This project is provided without warranties. Users are advised to review the accompanying license for more information on the terms of use and limitations of liability.
