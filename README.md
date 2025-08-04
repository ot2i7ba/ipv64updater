# ipv64updater
This script provides an automated and reliable solution for updating dynamic DNS entries with ipv64.net from a Synology NAS system. It detects the current public IPv4 and IPv6 addresses (including the IPv6 prefix), and sends updates to ipv64.net only when necessary—either when the addresses have changed or after a configurable interval. To improve robustness, the script incorporates fallback mechanisms for IP detection and maintains a rotating log of all update activities. It is fully compatible with Synology’s DSM Task Scheduler and requires minimal configuration.

> [!CAUTION]
> This script is specifically written for use with ipv64.net Dynamic DNS updates on Synology NAS systems. I have not tested it in other environments or with other dynamic DNS providers, so I cannot guarantee its compatibility or performance outside of the context described here. Please note that this script is still under development, and I cannot guarantee flawless or fully reliable operation in every environment. It is tailored to meet specific requirements and personal needs at this stage. Use it with caution—especially in situations where continuous network availability or operational reliability is mission-critical.

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
    - Falls back to `https://ifconfig.co` if necessary using IPv4 (`curl -4`).

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

> [!TIP]
> The script sends the current public IP/PREFIX values to ipv64.net using the following update URL format:
>
> ```
> https://ipv64.net/update.php?key=<key>&domain=<domain>&ip=<ipaddr>&ip6=<ip6addr>&ipv6prefix=<ip6lanprefix>
> ```
>
> | Placeholder       | Description                        |
> |-------------------|------------------------------------|
> | `<key>`           | Your personal ipv64.net key        |
> | `<domain>`        | Your ipv64.net domain              |
> | `<ipaddr>`        | Current public IPv4 address        |
> | `<ip6addr>`       | Current public IPv6 address        |
> | `<ip6lanprefix>`  | IPv6 LAN prefix (optional)         |

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

# Conclusion
I make no claim of correctness or full functionality. As I am not particularly experienced with Bash, this script may contain errors, and I accept no warranty of any kind. This script was created out of necessity to help my friend **Straight Shooter** solve a DDNS issue involving the excellent service from [ipv64.net](https://ipv64.net). It is designed to be called regularly via the Synology NAS Task Scheduler. I have attempted to implement several fallback routines – whether for repeated invocations or for fetching IP addresses. For my needs the script works: IPv4, IPv6, and IPv6 prefix are correctly passed to ipv64.net. However, you may need to adjust the script for your specific setup. It is also possible that I have implemented some unnecessary logic in the code; please consider this a playful part of my self-study journey.
