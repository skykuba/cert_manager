# cert_manager

## Opis
`cert_manager` to narzędzie do zarządzania certyfikatami SSL/TLS, które umożliwia generowanie kluczy prywatnych, certyfikatów, żądań CSR oraz konfiguracji SAN. Projekt zawiera również prosty serwer HTTPS w Pythonie.

## Struktura projektu
- `cert.sh` - Skrypt Bash do generowania certyfikatów i kluczy.
- `openssl-san.cnf` - Plik konfiguracyjny dla OpenSSL z ustawieniami SAN.
- `server.py` - Serwer HTTPS w Pythonie wykorzystujący wygenerowane certyfikaty.
- `LICENSE` - Licencja projektu (MIT).
- `README.md` - Dokumentacja projektu.

## Wymagania
- OpenSSL
- Python 3.x
- Debian/Linux

## Instalacja
1. Upewnij się, że masz zainstalowany OpenSSL i Python 3.x.
2. Sklonuj repozytorium lub pobierz pliki projektu.

## Użycie
### Generowanie certyfikatów
Uruchom skrypt `cert.sh` w bash z odpowiednią opcją:
```bash
chmod +x cert.sh
./cert.sh 