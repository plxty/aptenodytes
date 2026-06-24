#!/usr/bin/env python3

import json
import os
import sys
from textwrap import dedent as _dedent, indent as _indent
from collections.abc import Callable
from io import StringIO
from ipaddress import IPv4Network
from typing import Any, Dict, List, Optional, Self, Tuple, ItemsView


class MultiDict:
    _elem: Dict[Any, List[Any]]

    def __init__(self: Self) -> None:
        self._elem = dict()

    def get(self: Self, key: Any, which: Optional[int] = None) -> List[Any] | Any:
        value = self._elem[key]
        if which is not None:
            return value[which]
        return value

    def get1(self: Self, key: Any) -> Any:
        return self.get(key, 0)

    def set(
        self: Self,
        key: Any,
        value: List[Any] | Any,
        which: Optional[int] = None,
        allow_multi: bool = True,
    ) -> Self:
        if type(value) is not list:
            value = [value]
        if key not in self._elem:
            self._elem[key] = value
        elif allow_multi:
            self._elem[key] += value
        else:
            assert which is not None
            assert len(value) == 1
            self._elem[key][which].update(value[0])
        return self

    def set1(self: Self, key: Any, value: Any) -> Self:
        return self.set(key, value, 0, False)

    def items(self: Self) -> ItemsView[Any, List[Any]]:
        return self._elem.items()

    def items1(self: Self) -> List[Tuple[Any, Any]]:
        # TODO: make ItemsView[.., ..]
        result: List[Tuple[Any, Any]] = list()
        for key, values in self.items():
            for value in values:
                result.append((key, value))
        return result

    def __contains__(self: Self, key: Any) -> bool:
        return key in self._elem

    def __delitem__(self: Self, key: Any) -> None:
        del self._elem[key]


class MultiDictEncoder(json.JSONEncoder):
    def default(self: Self, o: Any) -> Any:
        if type(o) is MultiDict:
            return o._elem
        return super().default(o)


def dedent(text: str) -> str:
    # dedent + remove first/tail empty lines:
    return _dedent(text.strip("\n"))


def indent(text: str, level: int) -> str:
    # indent based on level, 4 space:
    return _indent(text, "    " * level)


# (Network -> Attribute) -> (Collect -> Config) -> Generate
type Attribute = MultiDict[str, Any]  # key -> [value]
type Network = Dict[str, Attribute]  # iface -> Attribute
type Config = MultiDict[str, Dict[str, Any] | Any]  # section -> [key -> value]
type Collect = Dict[str, Config]  # filename -> Config
type Generate = Dict[str, str]  # filename -> content


# arg helpers, note default parameters are like "static" variable:
def make_arg_type(typ: str, fetch: bool, types: Dict[str, Any]) -> Any:
    # TODO: type hints... complex...
    if fetch:
        if typ == "*":
            return list(types.values())
        if typ in types:
            return [types[typ]]
        return list()

    def inner(func):
        types[typ] = func
        return func

    return inner


def arg_type_collect(
    typ: str, fetch: bool = False, types: Dict[str, Any] = dict()
) -> Any:
    return make_arg_type(typ, fetch, types)


def arg_type_collect_per_iface(
    typ: str, fetch: bool = False, types: Dict[str, Any] = dict()
) -> Any:
    return make_arg_type(typ, fetch, types)


def arg_type_generate(
    typ: str, fetch: bool = False, types: Dict[str, Any] = dict()
) -> Any:
    return make_arg_type(typ, fetch, types)


@arg_type_collect_per_iface("networkd")
def collect_networkd(network: Network, iface: str) -> Collect:
    result: Collect = dict()
    attrs = network[iface]

    if "mac" in attrs:
        result[f"{iface}.link"] = (
            MultiDict()
            .set1("Match", {"MACAddress": attrs.get1("mac")})
            .set1(
                "Link",
                {
                    "MACAddressPolicy": "persistent",
                    "Name": iface,
                },
            )
        )

    network_config: Config = (
        MultiDict()
        .set1("Match", {"Name": iface})
        .set1("Link", {"RequiredForOnline": "carrier"})
        .set1("Network", {"LinkLocalAddressing": "no"})
    )

    dhcp = "yes" if "dhcp" in attrs else "no"
    network_config.set1("Network", {"DHCP": dhcp})

    if "dhcp6pd" in attrs:
        prefix = attrs.get1("dhcp6pd")
        if prefix == "":
            (
                network_config.set1(
                    "Network",
                    {
                        "DHCPPrefixDelegation": "yes",
                        "LinkLocalAddressing": "ipv6",
                        "IPv6AcceptRA": "no",
                        "IPv6SendRA": "yes",
                    },
                )
                .set1("DHCPPrefixDelegation", {"Token": "::1"})
                .set1(
                    "IPv6SendRA",
                    {
                        "Managed": "yes",
                        "OtherInformation": "yes",
                    },
                )
            )
        else:
            (
                network_config.set1(
                    "Network",
                    {
                        "DHCP": "ipv6",
                        "LinkLocalAddressing": "ipv6",
                    },
                ).set1(
                    "DHCPv6",
                    {
                        "PrefixDelegationHint": prefix,
                        "UseDNS": "no",
                        "UseHostname": "no",
                        "WithoutRA": "solicit",
                    },
                )
            )

    if "inet" in attrs:
        network_config.set1("Network", {"Address": attrs.get1("inet")})

    if "bridge" in attrs:
        master = attrs.get1("bridge")
        if master == "":
            result[f"{iface}.netdev"] = MultiDict().set1(
                "NetDev",
                {
                    "Kind": "bridge",
                    "Name": iface,
                },
            )
        else:
            (
                network_config.set1(
                    "Link",
                    {"RequiredForOnline": "enslaved"},
                ).set1(
                    "Network",
                    {"Bridge": master},
                )
            )

    # proxy, special, hmmm
    if "tproxy" in attrs:
        dest, _, fwmark, table = attrs.get1("tproxy").split(",")
        network_config.set(
            "Route",
            [
                {
                    "Type": "local",
                    "Destination": dest,
                },
                {
                    "Type": "local",
                    "Destination": "0.0.0.0/0",
                    "Table": table,
                },
            ],
        )
        network_config.set1(
            "RoutingPolicyRule",
            {
                "FirewallMark": fwmark,
                "Priority": "100",
                "Table": table,
            },
        )

    # TODO: optimize...
    for _, ppp_value in network.items():
        if "pppoe" not in ppp_value:
            continue
        if ppp_value.get1("pppoe") == iface:
            network_config.set1(
                "Network",
                {
                    "DefaultRouteOnDevice": "yes",
                    "KeepConfiguration": "static",
                },
            )
            # TODO: make a explicit online attribute?
            del network_config["Link"]
        break

    if "unmanaged" not in attrs:
        result[f"{iface}.network"] = network_config
    return result


@arg_type_collect("dnsmasq")
def collect_dnsmasq(network: Network) -> Collect:
    result: Collect = dict()

    # FIXME: Make per-iface?
    for iface, attrs in network.items():
        if "dnsmasq" in attrs and "inet" in attrs:
            break
    else:
        return result

    # TODO: ipv6 support?
    ctor, *dns = attrs.get1("dnsmasq").split(",")
    addr, prefix = attrs.get1("inet").split("/")
    hostname = os.environ["IGLU_ID"]
    domain = hostname.split(".", maxsplit=1)[-1]

    # ranges:
    rang = IPv4Network(f"{addr}/{prefix}", False)
    hosts = [str(ip) for ip in rang.hosts()]
    start = hosts[hosts.index(addr) + 1]
    end = hosts[-1]

    # TODO: auto restart dnsmasq when pppd and mihomo start/stop?
    dnsmasq_config = (
        MultiDict()
        .set1("address", f"/{hostname}/{addr}")
        .set1("bind-dynamic", "")
        .set1("cache-size", "10000")
        .set1("dhcp-authoritative", "")
        .set1("domain", domain)
        .set1("enable-ra", "")
        .set1("local", f"/{domain}/")
        .set1("strict-order", "")
        .set(
            "dhcp-option",
            [
                f"interface:{iface},1,{rang.netmask}",
                f"interface:{iface},3,{addr}",
                f"interface:{iface},6,{addr}",
            ],
        )
        .set(
            "dhcp-range",
            [
                f"interface:{iface},{start},{end},72h",
                f"interface:{iface},::,constructor:{ctor},slaac,ra-stateless,ra-names,72h",
            ],
        )
        .set(
            "interface",
            [
                f"{iface}",
                "lo",
            ],
        )
    )

    for _, ppp_value in network.items():
        if "pppoe" not in ppp_value:
            continue
        dnsmasq_config.set1("resolv-file", "/etc/ppp/resolv.conf")
        break

    if len(dns) != 0:
        dnsmasq_config.set("server", dns[0])
    dnsmasq_config.set(
        "server",
        [
            "223.5.5.5",
            "119.29.29.29",
        ],
    )

    result["dnsmasq.conf"] = dnsmasq_config
    return result


@arg_type_collect_per_iface("pppoe")
def collect_pppoe(network: Network, iface: str) -> Collect:
    result: Collect = dict()
    attrs = network[iface]

    if "pppoe" not in attrs:
        return result

    ppp_iface = attrs.get1("pppoe")
    result[ppp_iface] = (
        MultiDict()
        .set1("plugin", "pppoe.so")
        .set1("ifname", ppp_iface)
        .set1(f"nic-{iface}", "")
        .set1("file", f"/etc/ppp/keys/{ppp_iface}")
        .set1("persist", "")
        .set1("maxfail", "0")
        .set1("holdoff", "10")
        .set1("+ipv6", "ipv6cp-use-ipaddr")
        .set1("defaultroute", "")
        .set1("usepeerdns", "")
        .set1("noipdefault", "")
    )

    return result


@arg_type_collect("sysctl")
def collect_sysctl(network: Network) -> Collect:
    result: Collect = dict()

    for _, attrs in network.items():
        if "bridge" in attrs and "inet" in attrs:
            break
    else:
        return result

    result["00-router.conf"] = (
        MultiDict()
        .set1("net.ipv4.conf.all.forwarding", "1")
        .set1("net.ipv6.conf.all.forwarding", "1")
    )

    return result


@arg_type_collect("nftables")
def collect_nftables(network: Network) -> Collect:
    result: Collect = dict()

    # accept dhcpv4 client/server, @see nixos-fw :)
    firewall_rpfilter_pre = dedent("""
        type filter hook prerouting priority mangle + 10; policy drop;
        meta nfproto ipv4 udp sport . udp dport { 67 . 68, 68 . 67 } accept
        fib saddr . mark . iif oif exists accept
    """)
    firewall_rpfilter: List[str] = list()

    # blocking outer wilds:
    firewall_input_pre = dedent("""
        type filter hook input priority filter; policy drop;
        iifname { "lo" } accept
    """)
    firewall_input: List[str] = list()
    firewall_input_post = dedent("""
        ct state vmap {
            invalid : drop,
            established : accept,
            related : accept,
            new : jump input-allow,
            untracked : jump input-allow,
        }
        tcp flags syn / fin,syn,rst,ack log level info prefix "[nftables] refused: "
    """)

    # allow ping by default:
    firewall_input_allow: List[str] = list()
    firewall_input_allow_post = dedent("""
        icmp type echo-request accept
        icmpv6 type != { nd-redirect, 139 } accept
        ip6 daddr fe80::/64 udp dport 546 accept
    """)

    # masquerade...
    nat_pre = "type nat hook prerouting priority dstnat;"
    nat_post_pre = "type nat hook postrouting priority srcnat;"
    nat_post: List[str] = list()
    nat_out = "type nat hook output priority mangle;"

    rules: Config = MultiDict().set(
        "table inet mss-clamping",
        {
            "chain forward": dedent("""
                type filter hook forward priority filter; policy accept;
                tcp flags syn tcp option maxseg size set rt mtu
            """)
        },
    )

    for iface, attrs in network.items():
        if "trusted" in attrs:
            firewall_input.append(f'iifname {{ "{iface}" }} accept')

        if "masquerade" in attrs:
            iifname = attrs.get1("masquerade")
            nat_post.append(f'iifname {{ "{iifname}" }} oifname "{iface}" masquerade')

        if "tproxy" in attrs:
            dest, tproxy, fwmark, _ = attrs.get1("tproxy").split(",")
            rules.set(
                "table inet tproxy",
                {
                    "set proxy": dedent(f"""
                        typeof ip daddr
                        flags interval
                        auto-merge
                        elements = {{ {dest} }}
                    """),
                    # to debug, append end: meta nftrace set 0
                    "chain prerouting": dedent(f"""
                        type filter hook prerouting priority mangle;
                        ip daddr @proxy meta l4proto {{ tcp, udp }} mark set {fwmark} \\
                            tproxy ip to {tproxy} counter
                    """),
                },
            )
            accept_rule = f"meta mark {fwmark} accept"
            firewall_rpfilter.append(accept_rule)
            firewall_input_allow.append(accept_rule)

    # assemble them up:
    def concat(content: List[str | List[str]]) -> str:
        result = StringIO()
        for lines in content:
            if type(lines) is list:
                result.write("\n".join(lines))
            elif type(lines) is str:  # trick ruff
                result.write(lines)
            result.write("\n")
        return result.getvalue()

    rules.set(
        "table inet firewall",
        [
            {"chain rpfilter": concat([firewall_rpfilter_pre, firewall_rpfilter])},
            {
                "chain input": concat(
                    [firewall_input_pre, firewall_input, firewall_input_post]
                )
            },
            {
                "chain input-allow": concat(
                    [firewall_input_allow, firewall_input_allow_post]
                )
            },
        ],
    )

    if len(nat_post) != 0:
        nat_rules = [
            {"chain pre": concat([nat_pre])},
            {"chain post": concat([nat_post_pre, nat_post])},
            {"chain out": concat([nat_out])},
        ]
        rules.set("table ip nat", nat_rules)
        rules.set("table ip6 nat", nat_rules)

    result["00-route.rules"] = rules
    return result


@arg_type_generate("networkd")
def generate_networkd(collect: Collect) -> Generate:
    result: Generate = dict()

    # please do avoid 80+, as it ships with default networkd:
    netdev_i = 0
    link_i = 30
    network_i = 50

    for filename, config in collect.items():
        typ = filename.rsplit(".", maxsplit=1)[-1]
        if typ == "netdev":
            i = netdev_i
            netdev_i += 1
        elif typ == "link":
            i = link_i
            link_i += 1
        elif typ == "network":
            i = network_i
            network_i += 1
        else:
            continue

        builder = StringIO()
        for section, key_value in config.items1():
            builder.write(f"[{section}]\n")
            for key, value in key_value.items():
                builder.write(f"{key}={value}\n")
            builder.write("\n")

        # no last \n\n:
        result[f"{i:02}-{filename}"] = builder.getvalue()[:-1]

    return result


@arg_type_generate("dnsmasq")
def generate_dnsmasq(collect: Collect) -> Generate:
    result: Generate = dict()

    filename = "dnsmasq.conf"
    if filename not in collect:
        return result

    config = collect[filename]
    builder = StringIO()
    for key, value in config.items1():
        builder.write(key)
        if value != "":
            builder.write(f"={value}")
        builder.write("\n")

    result[filename] = builder.getvalue()
    return result


@arg_type_generate("pppoe")
def generate_pppoe(collect: Collect) -> Generate:
    result: Generate = dict()

    for filename, config in collect.items():
        if not filename.startswith("ppp-") or "." in filename:
            continue

        builder = StringIO()
        for key, value in config.items1():
            builder.write(key)
            if value != "":
                builder.write(f" {value}")
            builder.write("\n")
        result[filename] = builder.getvalue()

    return result


@arg_type_generate("sysctl")
def generate_sysctl(collect: Collect) -> Generate:
    result: Generate = dict()

    filename = "00-router.conf"
    if filename not in collect:
        return result

    config = collect[filename]
    builder = StringIO()
    for key, value in config.items1():
        builder.write(f"{key} = {value}\n")

    result[filename] = builder.getvalue()
    return result


@arg_type_generate("nftables")
def generate_nftables(collect: Collect) -> Generate:
    result: Generate = dict()

    filename = "00-route.rules"
    if filename not in collect:
        return result

    # `/usr/libexec/nftables/nftables.sh load` will do the flush for us:
    config = collect[filename]
    builder = StringIO()
    for table, chain_rules in config.items():
        builder.write(f"{table} {{\n")
        for chain_rule in chain_rules:
            for chain, rules in chain_rule.items():
                builder.write(indent(f"{chain} {{\n", 1))
                builder.write(indent(rules, 2))
                builder.write(indent("}\n", 1))
            builder.write("\n")
        builder.write("}\n\n")

    result[filename] = builder.getvalue()[:-1]
    return result


# dead simple declarative config for network
def main() -> None:
    network: Network = dict()
    for line in os.environ["IGLU_NETWORK"].split(";"):
        attrs: Attribute = MultiDict()
        iface, *raw = line.strip().split()
        for attr in raw:
            key, *raw_value = attr.split("=")
            assert len(raw_value) <= 1
            if len(raw_value) == 0:
                value = ""
            else:
                value = raw_value[0]
            attrs.set(key, value)
        network[iface] = attrs

    # deduce from decorator:
    typ, output = sys.argv[1:]
    collect_fns: List[Callable[[Network], Collect]] = arg_type_collect(typ, True)
    collect_per_iface_fns: List[Callable[[Network, str], Collect]] = (
        arg_type_collect_per_iface(typ, True)
    )
    generate_fns: List[Callable[[Collect], Generate]] = arg_type_generate(typ, True)

    # stage collect:
    collect: Collect = dict()
    for cfn in collect_fns:
        collect.update(cfn(network))
    for iface in network.keys():
        for cpifn in collect_per_iface_fns:
            collect.update(cpifn(network, iface))

    # stage generate:
    generate: Generate = dict()
    for gfn in generate_fns:
        generate.update(gfn(collect))

    # output to stdout or else:
    for filename, content in generate.items():
        if output == "stdout":
            print(f">>> Exposing {filename}...")
            print(content)
            continue

        os.makedirs(output, exist_ok=True)
        with open(f"{output}/{filename}", "w") as writer:
            writer.write(content)


if __name__ == "__main__":
    main()
