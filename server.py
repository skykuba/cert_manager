import http.server
import ssl

HOST = "127.0.0.1"
PORT = 9443

handler = http.server.SimpleHTTPRequestHandler
httpd = http.server.HTTPServer((HOST, PORT), handler)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)

# Użyj certyfikatu z SAN
context.load_cert_chain(
    certfile="./server/server.cert.pem", keyfile="./server/server.key.pem"
)

# Ważne opcje bezpieczeństwa
context.options |= (
    ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1
)  # Wyłącz niebezpieczne wersje TLS
context.set_ciphers(
    "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
)  # Nowoczesne szyfry

httpd.socket = context.wrap_socket(
    httpd.socket,
    server_side=True
)

print(f"🔐 Serwer HTTPS działa pod adresem https://{HOST}:{PORT}")
print("Certyfikat zawiera SAN dla:")
print(" - localhost (DNS)")
print(" - 127.0.0.1 (IP)")
httpd.serve_forever()
