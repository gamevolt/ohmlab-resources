
BLACKLISTS=(
	"http://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=1.1.1.1"	# TOR Exit Nodes
	"http://www.maxmind.com/en/anonymous_proxies"				# MaxMind GeoIP Anonymous Proxies
	"http://danger.rulez.sk/projects/bruteforceblocker/blist.php"		# BruteForceBlocker IP List
	"http://www.spamhaus.org/drop/drop.lasso"				# Spamhaus Dont Route Or Peer List (DROP)
	"http://cinsscore.com/list/ci-badguys.txt"				# C.I. Army Malicious IP List
	"http://lists.blocklist.de/lists/all.txt"				# blocklist.de attackers
	"https://raw.githubusercontent.com/DXC-0/respect-my-internet/refs/heads/main/blocklist/ip/firehol_level3.netset"
	"https://raw.githubusercontent.com/DXC-0/respect-my-internet/refs/heads/main/blocklist/ip/ip-protection.txt"
	"https://raw.githubusercontent.com/DXC-0/malicious-robots/refs/heads/main/malicious-robots-daily.csv"
	" https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt"
	"https://raw.githubusercontent.com/duggytuxy/Data-Shield_IPv4_Blocklist/refs/heads/main/prod_data-shield_ipv4_blocklist.txt"
	    "https://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot Directory of Dictionary Attacker IPs
    "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=1.1.1.1"  # TOR Exit Nodes
    "https://www.maxmind.com/en/high-risk-ip-sample-list" # MaxMind GeoIP Anonymous Proxies
    "http://danger.rulez.sk/projects/bruteforceblocker/blist.php" # BruteForceBlocker IP List
    "https://www.spamhaus.org/drop/drop.lasso" # Spamhaus Don't Route Or Peer List (DROP)
    "http://cinsscore.com/list/ci-badguys.txt" # C.I. Army Malicious IP List
    "https://lists.blocklist.de/lists/all.txt" # blocklist.de attackers
    "https://www.myip.ms/files/blacklist/csf/latest_blacklist_users_submitted.txt" #myip.ms
    "https://rules.emergingthreats.net/blockrules/compromised-ips.txt" #
    "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt" #
    "http://www.abuseat.org/iotcc.txt" #
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/cybercrime.ipset" #
    "https://ransomwaretracker.abuse.ch/downloads/CW_PS_IPBL.txt"
    "https://ransomwaretracker.abuse.ch/downloads/LY_PS_IPBL.txt"
    "https://ransomwaretracker.abuse.ch/downloads/RW_IPBL.txt"
    "https://ransomwaretracker.abuse.ch/downloads/TC_PS_IPBL.txt"
    "https://ransomwaretracker.abuse.ch/downloads/TL_C2_IPBL.txt"
    "https://ransomwaretracker.abuse.ch/downloads/TL_PS_IPBL.txt"
    "https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt"
    "https://zeustracker.abuse.ch/blocklist.php?download=badips"
    "http://blocklist.greensnow.co/greensnow.txt" # GreenSnow
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset" # Firehol Level 1
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level2.netset" # Firehol Level 1
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level3.netset" # Firehol Level 1
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level4.netset" # Firehol Level 1
    "http://www.malwaredomainlist.com/hostslist/ip.txt"
    "http://sanyalnet-cloud-vps.freeddns.org/blocklist.txt"
    "http://sanyalnet-cloud-vps.freeddns.org/mirai-ips.txt"
    "http://sanyalnet-cloud-vps2.freeddns.org/blocklist.txt"
    "http://wbri.duckdns.org/blocklist.txt"
    "http://yiradio.duckdns.org/blocklist.txt"
    "http://glewlwyd.duckdns.org/blocklist.txt"
    "http://www.openbl.org/lists/base_7days.txt" #
    "http://malc0de.com/bl/IP_Blacklist.txt" #
    "https://feodotracker.abuse.ch/blocklist/?download=ipblocklist" #
    "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/stopforumspam_7d.ipset"
)

ipset=/usr/sbin/ipset
iptables=/usr/sbin/iptables

# Create ipset blacklist table if not exist
if ! $ipset list blacklist >/dev/null 2>&1; then
	$ipset create blacklist hash:net hashsize 2000000 maxelem 6000000 && $iptables -I INPUT -m set --match-set blacklist src -j DROP
fi

$ipset flush blacklist

wget -q -O - ${BLACKLISTS[@]} | \
grep -Po '([0-2]?[0-9][0-9]\.){3}\d{1,3}(?:/\d{1,2})?' | \
sort -n | \
uniq | \
while read ip; do
        $ipset add blacklist $ip
done	
