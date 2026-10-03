import ipaddress
import os
import re
import ssl
from urllib.parse import urlencode, urljoin
from urllib.error import URLError
from urllib.request import Request, urlopen

from bs4 import BeautifulSoup


VPN_GATE_URL = "https://www.vpngate.net/en/"
FLAG_ICON = re.compile(r"/flags/", re.IGNORECASE)
IPV4 = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
L2TP_IPSEC_CELL = 5
SUPPORTED_ICON = re.compile(r"/yes_33\.png$", re.IGNORECASE)


def _ipv4_address(text):
	for candidate in IPV4.findall(text):
		try:
			return str(ipaddress.IPv4Address(candidate))
		except ipaddress.AddressValueError:
			continue
	return None


def _ssl_context():
	cafiles = []
	try:
		import certifi
	except ImportError:
		pass
	else:
		cafiles.append(certifi.where())

	cafiles.extend(
		(
			os.environ.get("SSL_CERT_FILE"),
			ssl.get_default_verify_paths().openssl_cafile,
			"/etc/ssl/cert.pem",
			"/private/etc/ssl/cert.pem",
		)
	)
	for cafile in cafiles:
		if cafile and os.path.isfile(cafile):
			return ssl.create_default_context(cafile=cafile)
	return ssl.create_default_context()


def _open_page(request):
	try:
		with urlopen(request, timeout=30, context=_ssl_context()) as response:
			return response.read().decode("utf-8", errors="replace")
	except URLError as error:
		if "CERTIFICATE_VERIFY_FAILED" not in str(error):
			raise
		insecure = ssl._create_unverified_context()
		with urlopen(request, timeout=30, context=insecure) as response:
			return response.read().decode("utf-8", errors="replace")


def _fetch_page():
	user_agent = "Mozilla/5.0 (compatible; VPNGateIP scraper)"
	request = Request(VPN_GATE_URL, headers={"User-Agent": user_agent})
	page = _open_page(request)
	soup = BeautifulSoup(page, "html.parser")
	form = soup.find("form")
	if form is None:
		return page

	form_fields = []
	for control in form.find_all("input"):
		name = control.get("name")
		control_type = control.get("type", "text").lower()
		if not name:
			continue
		if control_type == "hidden":
			form_fields.append((name, control.get("value", "")))
		elif control_type == "checkbox" and name == "C_L2TP":
			form_fields.append((name, control.get("value", "on")))

	submit = form.find("input", attrs={"type": "submit", "name": "Button3"})
	if submit is None:
		return page
	form_fields.append((submit["name"], submit.get("value", "")))
	post_request = Request(
		urljoin(VPN_GATE_URL, form.get("action") or VPN_GATE_URL),
		data=urlencode(form_fields).encode(),
		headers={
			"User-Agent": user_agent,
			"Content-Type": "application/x-www-form-urlencoded",
			"Referer": VPN_GATE_URL,
		},
	)
	return _open_page(post_request)


def _server_list_rows(page):
	soup = BeautifulSoup(page, "html.parser")
	server_rows = []

	for table in soup.find_all("table"):
		rows = [
			row
			for row in table.find_all("tr")
			if row.find_parent("table") is table
		]
		is_server_table = any(
			_is_server_header_row(row.find_all("td", recursive=False))
			for row in rows
		)
		if is_server_table:
			server_rows.extend(rows)

	return server_rows


def _is_header_row(cells):
	return any(
		"vg_table_header" in (cell.get("class") or [])
		or "country (physical location)" in cell.get_text(" ", strip=True).lower()
		for cell in cells
	)


def _is_server_header_row(cells):
	if len(cells) <= L2TP_IPSEC_CELL:
		return False
	return (
		cells[0].get_text(" ", strip=True).lower().startswith("country")
		and "l2tp/ipsec" in cells[L2TP_IPSEC_CELL].get_text(" ", strip=True).lower()
	)


def _supports_l2tp_ipsec(cells):
	return len(cells) > L2TP_IPSEC_CELL and cells[L2TP_IPSEC_CELL].find(
		"img", src=SUPPORTED_ICON
	) is not None


def _country(cells):
	flag_cell = next(
		(cell for cell in cells if cell.find("img", src=FLAG_ICON)),
		None,
	)
	if flag_cell is None:
		return None
	return flag_cell.get_text(" ", strip=True) or None


def get_vpn_servers():
	page = _fetch_page()
	servers_by_ip = {}

	for row in _server_list_rows(page):
		cells = row.find_all("td", recursive=False)
		if len(cells) < 2 or _is_header_row(cells) or not _supports_l2tp_ipsec(cells):
			continue

		country = _country(cells)
		ip_source = cells[1] if len(cells) > 1 else cells[0]
		ip_address = _ipv4_address(ip_source.get_text(" ", strip=True)) or _ipv4_address(
			" ".join(cell.get_text(" ", strip=True) for cell in cells)
		)
		if ip_address and country:
			servers_by_ip[ip_address] = country

	return [
		{"ip": ip_address, "country": country}
		for ip_address, country in servers_by_ip.items()
	]


def main():
	try:
		servers = get_vpn_servers()
	except (URLError, TimeoutError) as error:
		print(f"Could not retrieve the VPN Gate server list: {error}")
		return

	if not servers:
		print("No L2TP/IPsec VPN servers were found on the page.")
		return

	print(f"Found {len(servers)} L2TP/IPsec VPN servers:")
	for server in servers:
		print(f"{server['ip']} - {server['country']}")


if __name__ == "__main__":
	main()
