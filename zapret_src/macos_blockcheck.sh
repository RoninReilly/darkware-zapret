#!/bin/bash
#
# Darkware Zapret - macOS Diagnostics
# Диагностика блокировок и тестирование стратегий (tpws + ciadpi)
#

# Конфигурация
ZAPRET_BASE="${ZAPRET_BASE:-/opt/darkware-zapret}"
TPWS="${ZAPRET_BASE}/tpws/tpws"
CIADPI="${ZAPRET_BASE}/byedpi/ciadpi"
CURL_TIMEOUT="${CURL_TIMEOUT:-5}"
SOCKS_PORT="${SOCKS_PORT:-19999}"
DOMAIN="${DOMAIN:-discord.com}"
TEST_URL="https://${DOMAIN}"
HTTP_URL="http://${DOMAIN}"

# Результаты
declare -a WORKING_STRATEGIES
ENGINE_PID=""

# Очистка при выходе
cleanup() {
    if [ -n "$ENGINE_PID" ] && kill -0 "$ENGINE_PID" 2>/dev/null; then
        kill "$ENGINE_PID" 2>/dev/null || true
        wait "$ENGINE_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# Проверка системы
check_system() {
    echo "=== SYSTEM INFO ==="
    echo "macOS: $(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
    echo "Arch: $(uname -m)"
    echo "curl: $(curl --version 2>/dev/null | head -1 | cut -d' ' -f1-2)"
    
    if [ -x "$TPWS" ]; then
        echo "tpws: OK"
    else
        echo "tpws: NOT FOUND"
        echo "ERROR: Install Darkware Zapret first"
        exit 1
    fi
    
    if [ -x "$CIADPI" ]; then
        echo "ciadpi: OK"
    else
        echo "ciadpi: NOT FOUND"
    fi
    
    # Найти свободный порт
    for p in $(seq 19999 20010); do
        if ! nc -z 127.0.0.1 $p 2>/dev/null; then
            SOCKS_PORT=$p
            break
        fi
    done
    echo ""
}

# Проверка DNS
check_dns() {
    echo "=== DNS CHECK ==="
    
    local ips=$(dig +short "$DOMAIN" A 2>/dev/null | head -3)
    if [ -z "$ips" ]; then
        echo "DNS: FAILED - cannot resolve $DOMAIN"
        return 1
    fi
    
    echo "DNS: OK"
    for ip in $ips; do
        echo "  $DOMAIN -> $ip"
    done
    echo ""
}

# Проверка портов
check_ports() {
    echo "=== PORT CHECK ==="
    
    local ips=$(dig +short "$DOMAIN" A 2>/dev/null | head -2)
    local all_ok=1
    
    for ip in $ips; do
        if nc -z -w 2 "$ip" 443 2>/dev/null; then
            echo "$ip:443 - OPEN"
        else
            echo "$ip:443 - BLOCKED/TIMEOUT"
            all_ok=0
        fi
    done
    echo ""
}

# Тест без обхода
check_direct() {
    echo "=== DIRECT CONNECTION (no bypass) ==="
    
    # HTTP
    local http_code
    http_code=$(curl -s --max-time "$CURL_TIMEOUT" -o /dev/null -w "%{http_code}" "$HTTP_URL" 2>&1)
    local http_exit=$?
    
    if [ $http_exit -eq 0 ] && echo "$http_code" | grep -q "^[23]"; then
        echo "HTTP: OK"
    else
        echo "HTTP: BLOCKED (Code: $http_code)"
    fi
    
    # HTTPS
    local https_code
    https_code=$(curl -s --max-time "$CURL_TIMEOUT" -o /dev/null -w "%{http_code}" "$TEST_URL" 2>&1)
    local https_exit=$?
    
    if [ $https_exit -eq 0 ] && echo "$https_code" | grep -q "^[23]"; then
        echo "HTTPS: OK"
        echo "NOTE: Connection works without bypass!"
    else
        if [ $https_exit -eq 28 ]; then
            echo "HTTPS: BLOCKED (Timeout)"
        else
            echo "HTTPS: BLOCKED (Curl exit code: $https_exit, HTTP code: $https_code)"
        fi
    fi
    echo ""
}

# Функция теста стратегии (общая логика)
test_strategy_generic() {
    local engine_bin="$1"
    local engine_name="$2"
    local strategy_name="$3"
    local args="$4"
    
    # Запуск движка
    # >/dev/null 2>&1 убрано (если нужно дебажить, но для юзера лучше убрать мусор)
    $engine_bin $args >/dev/null 2>&1 &
    ENGINE_PID=$!
    
    # Дать время на старт
    sleep 0.5
    
    if ! kill -0 "$ENGINE_PID" 2>/dev/null; then
        echo "  $strategy_name: FAILED TO START ($engine_name crashed)"
        ENGINE_PID=""
        return 1
    fi
    
    local result
    # Используем socks5h для удаленного DNS резолва
    result=$(curl -s --max-time "$CURL_TIMEOUT" \
        --proxy "socks5h://127.0.0.1:$SOCKS_PORT" \
        -o /dev/null -w "%{http_code}" "$TEST_URL" 2>&1)
    local code=$?
    
    if [ -n "$ENGINE_PID" ]; then
        kill "$ENGINE_PID" 2>/dev/null || true
        wait "$ENGINE_PID" 2>/dev/null || true
        ENGINE_PID=""
    fi
    
    if [ $code -eq 0 ] && echo "$result" | grep -q "^[23]"; then
        echo "  $strategy_name: OK"
        WORKING_STRATEGIES+=("$engine_name: $strategy_name")
        return 0
    else
        if [ $code -eq 28 ]; then
            echo "  $strategy_name: TIMEOUT"
        else
            echo "  $strategy_name: FAILED"
        fi
        return 1
    fi
}

# Тестирование TPWS
test_tpws_strategy() {
    local name="$1"
    local args="$2"
    # tpws needs --socks --port
    test_strategy_generic "$TPWS" "tpws" "$name" "--socks --port $SOCKS_PORT $args"
}

# Тестирование CIADPI
test_ciadpi_strategy() {
    local name="$1"
    local args="$2"
    # ciadpi needs -p port
    test_strategy_generic "$CIADPI" "ciadpi" "$name" "-p $SOCKS_PORT $args"
}

# Тестирование стратегий
test_strategies() {
    echo "=== TPWS STRATEGIES ==="
    test_tpws_strategy "Split+Disorder" "--split-pos=1,midsld --disorder"
    test_tpws_strategy "TLSRec+Split" "--tlsrec=sniext --split-pos=1,midsld --disorder"
    test_tpws_strategy "TLSRec MidSLD" "--tlsrec=midsld --split-pos=midsld --disorder"
    test_tpws_strategy "TLSRec+OOB" "--tlsrec=sniext --split-pos=1,midsld --disorder --hostdot"
    echo ""
    
    if [ -x "$CIADPI" ]; then
        echo "=== CIADPI STRATEGIES ==="
        test_ciadpi_strategy "Disorder (Simple)" "-d 1"
        test_ciadpi_strategy "Disorder (SNI)" "-d 1+s"
        test_ciadpi_strategy "Fake Packets" "-d 1 -f -1 -t 6"
        test_ciadpi_strategy "Auto (Torst)" "-A torst -d 1"
        echo ""
    fi
}

# Итоги
print_summary() {
    echo "=== SUMMARY ==="
    
    local count=${#WORKING_STRATEGIES[@]}
    
    if [ $count -gt 0 ]; then
        echo "Working strategies: $count"
        for s in "${WORKING_STRATEGIES[@]}"; do
            echo "  + $s"
        done
        echo ""
        echo "RECOMMENDED: Select one of the working strategies above."
        
        # Попытка парсинга первой рабочей стратегии для рекомендации
        local first_working="${WORKING_STRATEGIES[0]}"
        if [[ "$first_working" == "tpws:"* ]]; then
             echo "Default Engine: tpws"
        elif [[ "$first_working" == "ciadpi:"* ]]; then
             echo "Default Engine: ciadpi"
        fi
        
    else
        echo "NO WORKING STRATEGIES FOUND"
        echo ""
        echo "Possible reasons:"
        echo "  - ISP blocks by IP, not DPI"
        echo "  - Need custom parameters"
        echo "  - Try using a VPN"
    fi
    
    echo ""
    echo "=== END ==="
}

# Main
main() {
    echo "Darkware Zapret Diagnostics"
    echo "Domain: $DOMAIN"
    echo ""
    
    # Парсинг аргументов
    while [ $# -gt 0 ]; do
        case "$1" in
            --domain=*)
                DOMAIN="${1#*=}"
                TEST_URL="https://${DOMAIN}"
                HTTP_URL="http://${DOMAIN}"
                ;;
            SCANLEVEL=*)
                # Игнорируем legacy параметр
                ;;
            *)
                ;;
        esac
        shift
    done
    
    check_system
    check_dns
    check_ports
    check_direct
    test_strategies
    print_summary
}

main "$@"
