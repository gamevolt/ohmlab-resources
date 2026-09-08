
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
