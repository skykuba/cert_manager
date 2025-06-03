#!/bin/bash
set -e


COUNTRY="PL"
STATE="Pomorskie"
LOCALITY="Gdansk"
ORGANIZATION="MojaCA"
ORG_UNIT="Lab"
CA_COMMON_NAME="MojaCA"
SERVER_COMMON_NAME="server.example.com"
SAN="DNS:localhost,IP:127.0.0.1"  # Domyślne SAN
CA_BITS=4096
SERVER_BITS=2048
CA_DAYS=3650
SERVER_DAYS=375
OPENSSL_CONFIG="openssl-san.cnf"  # Plik konfiguracyjny SAN

# Ścieżki katalogów
CA_DIR="ca"
SERVER_DIR="server"

# Załaduj własną konfigurację jeśli istnieje
[ -f "config.sh" ] && source config.sh

# ----------------------------------------------
# Funkcje
# ----------------------------------------------

# Inicjalizacja struktur katalogów
init_dirs() {
  mkdir -p "${CA_DIR}" "${SERVER_DIR}"
  echo "Utworzono katalogi: ${CA_DIR}, ${SERVER_DIR}"
}

# Generowanie klucza prywatnego CA
generate_ca_key() {
  openssl genpkey -algorithm RSA \
    -out "${CA_DIR}/ca.key.pem" \
    -aes256 \
    -pkeyopt "rsa_keygen_bits:${CA_BITS}"
  chmod 400 "${CA_DIR}/ca.key.pem"
  echo "Wygenerowano klucz CA (${CA_BITS} bitów) w ${CA_DIR}/ca.key.pem"
}

# Generowanie certyfikatu CA
generate_ca_cert() {
  openssl req -x509 -new -nodes \
    -key "${CA_DIR}/ca.key.pem" \
    -sha256 -days "${CA_DAYS}" \
    -out "${CA_DIR}/ca.cert.pem" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${CA_COMMON_NAME}"
  chmod 444 "${CA_DIR}/ca.cert.pem"
  echo "Wygenerowano certyfikat CA ważny ${CA_DAYS} dni w ${CA_DIR}/ca.cert.pem"
}

# Generowanie klucza serwera
generate_server_key() {
  openssl genpkey -algorithm RSA \
    -out "${SERVER_DIR}/server.key.pem" \
    -pkeyopt "rsa_keygen_bits:${SERVER_BITS}"
  chmod 400 "${SERVER_DIR}/server.key.pem"
  echo "Wygenerowano klucz serwera (${SERVER_BITS} bitów) w ${SERVER_DIR}/server.key.pem"
}

verify_certs() {
  openssl verify -CAfile "${CA_DIR}/ca.cert.pem" "${SERVER_DIR}/server.cert.pem"
  if [ $? -eq 0 ]; then
    echo "Certyfikat serwera jest poprawny i zgodny z certyfikatem CA."
  else
    echo "Certyfikat serwera jest niepoprawny lub niezgodny z certyfikatem CA."
  fi
}



convert_formats() {
  echo "Rozpoczynanie konwersji formatów..."

  # PEM → DER (certyfikat)
  openssl x509 -in "${SERVER_DIR}/server.cert.pem" -outform DER -out "${SERVER_DIR}/server.cert.der"
  echo "Certyfikat PEM → DER: ${SERVER_DIR}/server.cert.der"

  # DER → PEM (certyfikat)
  openssl x509 -inform DER -in "${SERVER_DIR}/server.cert.der" -out "${SERVER_DIR}/server.cert.from_der.pem"
  echo "Certyfikat DER → PEM: ${SERVER_DIR}/server.cert.from_der.pem"

  # PEM → DER (klucz prywatny)
  openssl rsa -in "${SERVER_DIR}/server.key.pem" -outform DER -out "${SERVER_DIR}/server.key.der"
  echo "Klucz PEM → DER: ${SERVER_DIR}/server.key.der"

  # DER → PEM (klucz prywatny)
  openssl rsa -inform DER -in "${SERVER_DIR}/server.key.der" -out "${SERVER_DIR}/server.key.from_der.pem"
  echo "Klucz DER → PEM: ${SERVER_DIR}/server.key.from_der.pem"

  # PEM → PKCS#12 (.pfx)
  openssl pkcs12 -export \
    -inkey "${SERVER_DIR}/server.key.pem" \
    -in "${SERVER_DIR}/server.cert.pem" \
    -certfile "${CA_DIR}/ca.cert.pem" \
    -out "${SERVER_DIR}/server.pfx" \
    -passout pass:
  echo "Certyfikat + klucz → PFX: ${SERVER_DIR}/server.pfx (bez hasła)"

  # PKCS#12 → PEM (klucz + certyfikat)
  openssl pkcs12 -in "${SERVER_DIR}/server.pfx" -out "${SERVER_DIR}/unpacked_from_pfx.pem" -nodes -passin pass:
  echo "Rozpakowano PFX do PEM: ${SERVER_DIR}/unpacked_from_pfx.pem"

  echo "Konwersje zakończone."
}


# Tworzenie konfiguracji SAN
create_san_config() {
  cat > "${OPENSSL_CONFIG}" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = req_ext
prompt = no

[req_distinguished_name]
C = ${COUNTRY}
ST = ${STATE}
L = ${LOCALITY}
O = ${ORGANIZATION}
OU = ${ORG_UNIT}
CN = ${SERVER_COMMON_NAME}

[req_ext]
subjectAltName = ${SAN}
EOF
  echo "Utworzono konfigurację SAN w ${OPENSSL_CONFIG}"
}

# Generowanie żądania CSR z SAN
generate_server_csr() {
  [ ! -f "${OPENSSL_CONFIG}" ] && create_san_config

  openssl req -new \
    -key "${SERVER_DIR}/server.key.pem" \
    -out "${SERVER_DIR}/server.csr.pem" \
    -config "${OPENSSL_CONFIG}"
  echo "Wygenerowano CSR z SAN w ${SERVER_DIR}/server.csr.pem"
}

# Podpisywanie certyfikatu serwera przez CA
sign_server_cert() {
  [ ! -f "${OPENSSL_CONFIG}" ] && create_san_config

  openssl x509 -req \
    -in "${SERVER_DIR}/server.csr.pem" \
    -CA "${CA_DIR}/ca.cert.pem" \
    -CAkey "${CA_DIR}/ca.key.pem" \
    -CAcreateserial \
    -out "${SERVER_DIR}/server.cert.pem" \
    -days "${SERVER_DAYS}" \
    -sha256 \
    -extfile "${OPENSSL_CONFIG}" \
    -extensions req_ext
  chmod 444 "${SERVER_DIR}/server.cert.pem"
  echo "Podpisano certyfikat serwera ważny ${SERVER_DAYS} dni w ${SERVER_DIR}/server.cert.pem"
}

add_ca_to_trusted() {
  local CA_SYSTEM_PATH="/usr/local/share/ca-certificates/mojaca.crt"

  if [ -f "${CA_DIR}/ca.cert.pem" ]; then
    sudo cp "${CA_DIR}/ca.cert.pem" "${CA_SYSTEM_PATH}"
    sudo update-ca-certificates
    echo "Certyfikat CA został dodany do zaufanych certyfikatów systemowych."
  else
    echo "Certyfikat CA nie istnieje w ${CA_DIR}/ca.cert.pem. Upewnij się, że został wygenerowany."
    exit 1
  fi
}

# ----------------------------------------------
# Menu główne
# ----------------------------------------------
usage() {
  echo "Użycie: $0 [opcja]"
  echo "Opcje:"
  echo "  all             Wykonaj wszystkie kroki"
  echo "  init            Inicjalizuj katalogi"
  echo "  ca              Generuj CA (klucz + certyfikat)"
  echo "  server_key      Generuj klucz serwera"
  echo "  server_csr      Generuj CSR z SAN"
  echo "  sign            Podpisz certyfikat serwera"
  echo "  san_config      Tylko generuj plik konfiguracyjny SAN"
  ehco "  verify          Zweryfikuj certyfikat"
  echo "  add_ca          Dodaj certyfikat do zaufanych"
  echo "  convert_formats Zmien na inne formaty  "

}

case "$1" in
  all)
    init_dirs
    generate_ca_key
    generate_ca_cert
    generate_server_key
    create_san_config
    generate_server_csr
    sign_server_cert
    add_ca_to_trusted
    verify_certs
    ;;
  init)       init_dirs ;;
  ca)         generate_ca_key; generate_ca_cert ;;
  server_key) generate_server_key ;;
  server_csr) generate_server_csr ;;
  sign)       sign_server_cert ;;
  san_config) create_san_config ;;
  verify)     verify_certs ;;
  add_ca)    add_ca_to_trusted ;;
  convert_formats) convert_formats ;;

  *)
    usage
    exit 1
    ;;
esac
