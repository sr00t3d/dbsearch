#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   DBSearch — MySQL / MariaDB Full-Database Search Utility v2.0.0          ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Autor:   Percio Castelo                                                 ║
# ║   Contato: percio@evolya.com.br | contato@perciocastelo.com.br            ║
# ║   Web:     https://perciocastelo.com.br                                   ║
# ║                                                                           ║
# ║   Função:  Fast, safe CLI to search terms or regex across all tables and  ║
# ║            columns of MySQL/MariaDB databases (cPanel, Plesk, DirectAdmin,║
# ║            HestiaPanel, standalone) with table/JSON/CSV output.           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -uo pipefail
export LC_ALL=C

readonly VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "$0")"

# =============================================================================
# Defaults
# =============================================================================
DB_HOST=""
DB_PORT=""
DB_SOCKET=""
DB_USER=""
DB_PASS=""
DB_NAME=""
ALL_DBS=false
TABLE_FILTER=""
SEARCH_TERM=""

MATCH_MODE="like"        # like | exact | regex
CASE_SENSITIVE=false
INCLUDE_NUMERIC=false
SHOW_VALUE=false
TABLE_LAYOUT=false
OUTPUT_FORMAT="default"  # default | table | json | csv
PREVIEW_LIMIT=60
MAX_ROWS=5
MAX_TABLE_MB=1024
FORCE=false
QUIET=false
NO_COLOR=false

TMP_DIR=""
RESULTS_TSV=""

cleanup() {
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT INT TERM

# =============================================================================
# Colors
# =============================================================================
C_RESET=""
C_BOLD=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_CYAN=""
C_DIM=""

init_colors() {
    if [[ "$NO_COLOR" == false && "$OUTPUT_FORMAT" != "json" && "$OUTPUT_FORMAT" != "csv" && -t 1 ]]; then
        C_RESET=$'\033[0m'
        C_BOLD=$'\033[1m'
        C_DIM=$'\033[2m'
        C_RED=$'\033[0;31m'
        C_GREEN=$'\033[0;32m'
        C_YELLOW=$'\033[0;33m'
        C_BLUE=$'\033[0;34m'
        C_CYAN=$'\033[0;36m'
    fi
}

log_info() { [[ "$QUIET" == false && "$OUTPUT_FORMAT" != "json" && "$OUTPUT_FORMAT" != "csv" ]] && echo -e "${C_CYAN}[→]${C_RESET} $*" >&2; }
log_warn() { [[ "$QUIET" == false ]] && echo -e "${C_YELLOW}[!]${C_RESET} $*" >&2; }
log_err()  { echo -e "${C_RED}[✗] Error:${C_RESET} $*" >&2; }

# =============================================================================
# Help
# =============================================================================
show_help() {
    cat <<EOF
DBSearch v${VERSION}
Fast, safe full-database search CLI for MySQL and MariaDB.

Usage:
  ${SCRIPT_NAME} [OPTIONS] <search_term>

Connection Options:
  -d, --database <db>       Database to search (required unless -A is set)
  -A, --all-databases       Search across all non-system databases
  -t, --table <table>       Search only within the specified table
  -H, --host <host>         MySQL/MariaDB host (default: local socket / localhost)
  -P, --port <port>         MySQL/MariaDB TCP port (default: 3306)
  -S, --socket <path>       Unix socket path
  -u, --user <user>         Username (auto-detected from cPanel/Plesk/DirectAdmin/Hestia)
  -p, --password <pass>     Password (or set MYSQL_PWD env var)

Search & Safety Options:
  -r, --regex               Treat search term as a MySQL REGEXP pattern
  -x, --exact               Exact value match (=) instead of substring (LIKE)
  -C, --case-sensitive      Force case-sensitive comparison (BINARY)
      --include-numeric     Also scan numeric/date columns (default: text/JSON/enum only)
      --max-table-mb <n>    Skip tables larger than N MB unless -f is set (default: 1024)
  -f, --force               Force scan on large tables (> --max-table-mb)

Output Options:
  -l, --list                Summary table layout (alias for -o table)
  -v, --value               Show full matching rows (up to --max-rows per column)
  -o, --output <fmt>        Output format: default, table, json, csv
      --limit <n>           Preview truncation length in table mode (default: 60)
      --max-rows <n>        Max rows printed per column in -v mode (default: 5)
  -q, --quiet               Suppress header and progress messages
      --no-color            Disable ANSI colors
  -V, --version             Show version and exit
      --help                Show this help message and exit

Examples:
  ${SCRIPT_NAME} -d wordpress_db -l "https://old-domain.com"
  ${SCRIPT_NAME} -d wordpress_db -t wp_options -v "siteurl"
  ${SCRIPT_NAME} -A -o json "eval(base64_decode" > malware-hits.json
  ${SCRIPT_NAME} -d app_db --regex -o csv "^[a-z0-9._%+-]+@example\\.com$"
EOF
}

# =============================================================================
# Argument Parsing
# =============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--database)        [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; DB_NAME="$2"; shift 2 ;;
            -A|--all-databases)   ALL_DBS=true; shift ;;
            -t|--table)           [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; TABLE_FILTER="$2"; shift 2 ;;
            -H|--host)            [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; DB_HOST="$2"; shift 2 ;;
            -h)
                if [[ $# -ge 2 && "$2" != -* && -z "$DB_HOST" && ( -n "$DB_NAME" || "$ALL_DBS" == true || $# -gt 2 ) ]]; then
                    DB_HOST="$2"; shift 2
                else
                    show_help; exit 0
                fi ;;
            -P|--port)            [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; DB_PORT="$2"; shift 2 ;;
            -S|--socket)          [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; DB_SOCKET="$2"; shift 2 ;;
            -u|--user)            [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; DB_USER="$2"; shift 2 ;;
            -p|--password)        [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; DB_PASS="$2"; shift 2 ;;
            -r|--regex)           MATCH_MODE="regex"; shift ;;
            -x|--exact)           MATCH_MODE="exact"; shift ;;
            -C|--case-sensitive)  CASE_SENSITIVE=true; shift ;;
            --include-numeric)    INCLUDE_NUMERIC=true; shift ;;
            --max-table-mb)       [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; MAX_TABLE_MB="$2"; shift 2 ;;
            -f|--force)           FORCE=true; shift ;;
            -l|--list|-c)         TABLE_LAYOUT=true; OUTPUT_FORMAT="table"; shift ;;
            -v|--value)           SHOW_VALUE=true; shift ;;
            -o|--output)          [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; OUTPUT_FORMAT="$2"; shift 2 ;;
            --limit)              [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; PREVIEW_LIMIT="$2"; shift 2 ;;
            --max-rows)           [[ $# -lt 2 ]] && { log_err "$1 requires a value"; exit 1; }; MAX_ROWS="$2"; shift 2 ;;
            -q|--quiet)           QUIET=true; shift ;;
            --no-color)           NO_COLOR=true; shift ;;
            -V|--version)         echo "DBSearch v${VERSION}"; exit 0 ;;
            --help)               show_help; exit 0 ;;
            --)                   shift; [[ $# -gt 0 && -z "$SEARCH_TERM" ]] && SEARCH_TERM="$1"; break ;;
            -*)                   log_err "Unknown option: $1 (use --help)"; exit 1 ;;
            *)
                if [[ -z "$SEARCH_TERM" ]]; then
                    SEARCH_TERM="$1"
                else
                    log_err "Unexpected extra argument: $1"
                    exit 1
                fi
                shift ;;
        esac
    done

    if [[ "$ALL_DBS" == false && -z "$DB_NAME" ]]; then
        log_err "No database specified. Use -d <database> or -A (--all-databases)."
        exit 1
    fi
    if [[ -z "$SEARCH_TERM" ]]; then
        log_err "No search term specified. Use --help for usage."
        exit 1
    fi
    case "$OUTPUT_FORMAT" in
        default|table|json|csv) ;;
        *) log_err "--output must be default, table, json, or csv (got: $OUTPUT_FORMAT)"; exit 1 ;;
    esac
    [[ "$OUTPUT_FORMAT" == "table" ]] && TABLE_LAYOUT=true
}

# =============================================================================
# Credentials Auto-Detection (cPanel / Plesk / DirectAdmin / HestiaPanel)
# =============================================================================
MYSQL_CMD=()
CRED_SOURCE="cli"

setup_mysql_client() {
    local bin=""
    if command -v mariadb >/dev/null 2>&1; then
        bin="mariadb"
    elif command -v mysql >/dev/null 2>&1; then
        bin="mysql"
    else
        log_err "Neither 'mariadb' nor 'mysql' client binary was found in PATH."
        exit 1
    fi

    if [[ -z "$DB_USER" && -z "${MYSQL_PWD:-}" && -z "$DB_PASS" ]]; then
        if [[ -r "/root/.my.cnf" ]]; then
            CRED_SOURCE="/root/.my.cnf"
            DB_USER=$(awk -F= '/^[[:space:]]*user[[:space:]]*=/ {gsub(/^[[:space:]'\''"]+|[[:space:]'\''"]+$/, "", $2); print $2; exit}' /root/.my.cnf 2>/dev/null || true)
            DB_PASS=$(awk -F= '/^[[:space:]]*pass(word)?[[:space:]]*=/ {gsub(/^[[:space:]'\''"]+|[[:space:]'\''"]+$/, "", $2); print $2; exit}' /root/.my.cnf 2>/dev/null || true)
        elif [[ -r "${HOME}/.my.cnf" ]]; then
            CRED_SOURCE="${HOME}/.my.cnf"
            DB_USER=$(awk -F= '/^[[:space:]]*user[[:space:]]*=/ {gsub(/^[[:space:]'\''"]+|[[:space:]'\''"]+$/, "", $2); print $2; exit}' "${HOME}/.my.cnf" 2>/dev/null || true)
            DB_PASS=$(awk -F= '/^[[:space:]]*pass(word)?[[:space:]]*=/ {gsub(/^[[:space:]'\''"]+|[[:space:]'\''"]+$/, "", $2); print $2; exit}' "${HOME}/.my.cnf" 2>/dev/null || true)
        elif [[ -r "/etc/psa/.psa.shadow" ]]; then
            CRED_SOURCE="Plesk (.psa.shadow)"
            DB_USER="admin"
            DB_PASS=$(cat /etc/psa/.psa.shadow 2>/dev/null || true)
        elif [[ -r "/usr/local/directadmin/conf/mysql.conf" ]]; then
            CRED_SOURCE="DirectAdmin (mysql.conf)"
            DB_USER=$(awk -F= '/^user=/ {print $2; exit}' /usr/local/directadmin/conf/mysql.conf 2>/dev/null || true)
            DB_PASS=$(awk -F= '/^passwd=/ {print $2; exit}' /usr/local/directadmin/conf/mysql.conf 2>/dev/null || true)
        elif [[ -r "/usr/local/hestia/conf/mysql.conf" ]]; then
            CRED_SOURCE="HestiaPanel (mysql.conf)"
            DB_USER=$(grep -oE "USER='[^']+'" /usr/local/hestia/conf/mysql.conf 2>/dev/null | head -1 | cut -d"'" -f2 || true)
            DB_PASS=$(grep -oE "PASSWORD='[^']+'" /usr/local/hestia/conf/mysql.conf 2>/dev/null | head -1 | cut -d"'" -f2 || true)
        else
            CRED_SOURCE="unix_socket (root)"
        fi
    fi

    [[ -n "$DB_PASS" ]] && export MYSQL_PWD="$DB_PASS"

    MYSQL_CMD=("$bin" "--batch")
    [[ -n "$DB_HOST" ]] && MYSQL_CMD+=("-h" "$DB_HOST")
    [[ -n "$DB_PORT" ]] && MYSQL_CMD+=("-P" "$DB_PORT")
    [[ -n "$DB_SOCKET" ]] && MYSQL_CMD+=("-S" "$DB_SOCKET")
    [[ -n "$DB_USER" ]] && MYSQL_CMD+=("-u" "$DB_USER")

    if ! "${MYSQL_CMD[@]}" -N -e "SELECT 1;" >/dev/null 2>&1; then
        log_err "Failed to connect to MySQL/MariaDB (${CRED_SOURCE}). Check credentials or service status."
        exit 1
    fi
}

# =============================================================================
# SQL Escaping Helpers
# =============================================================================
sql_escape_str() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\'/\'\'}"
    printf '%s' "$s"
}

sql_escape_like() {
    local s
    s=$(sql_escape_str "$1")
    s="${s//%/\\%}"
    s="${s//_/\\_}"
    printf '%s' "$s"
}

sql_quote_ident() {
    local id="$1"
    id="${id//\`/\`\`}"
    printf '`%s`' "$id"
}

build_where_clause() {
    local col_ident="$1"
    local prefix=""
    [[ "$CASE_SENSITIVE" == true ]] && prefix="BINARY "

    case "$MATCH_MODE" in
        exact)
            local esc
            esc=$(sql_escape_str "$SEARCH_TERM")
            printf "%s%s = '%s'" "$prefix" "$col_ident" "$esc" ;;
        regex)
            local esc
            esc=$(sql_escape_str "$SEARCH_TERM")
            if [[ "$CASE_SENSITIVE" == true ]]; then
                printf "CAST(%s AS CHAR) REGEXP BINARY '%s'" "$col_ident" "$esc"
            else
                printf "CAST(%s AS CHAR) REGEXP '%s'" "$col_ident" "$esc"
            fi ;;
        like|*)
            local esc
            esc=$(sql_escape_like "$SEARCH_TERM")
            printf "%sCAST(%s AS CHAR) LIKE '%%%s%%'" "$prefix" "$col_ident" "$esc" ;;
    esac
}

# =============================================================================
# Main Search Engine
# =============================================================================
run_search() {
    TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dbsearch.XXXXXX")
    RESULTS_TSV="${TMP_DIR}/results.tsv"
    : > "$RESULTS_TSV"

    local dbs=()
    if [[ "$ALL_DBS" == true ]]; then
        while IFS= read -r d; do
            [[ -n "$d" ]] && dbs+=("$d")
        done < <("${MYSQL_CMD[@]}" -N -e "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema','mysql','performance_schema','sys') ORDER BY schema_name;" 2>/dev/null)
    else
        dbs=("$DB_NAME")
    fi

    if [[ ${#dbs[@]} -eq 0 ]]; then
        log_err "No searchable databases found."
        exit 1
    fi

    local col_types="'char','varchar','tinytext','text','mediumtext','longtext','enum','set','json'"
    if [[ "$INCLUDE_NUMERIC" == true ]]; then
        col_types="${col_types},'tinyint','smallint','mediumint','int','bigint','decimal','float','double','date','datetime','timestamp'"
    fi

    if [[ "$OUTPUT_FORMAT" == "default" || "$OUTPUT_FORMAT" == "table" ]]; then
        if [[ "$QUIET" == false ]]; then
            local target_label="$DB_NAME"
            [[ "$ALL_DBS" == true ]] && target_label="ALL (${#dbs[@]} DBs)"
            local cs_label=""
            [[ "$CASE_SENSITIVE" == true ]] && cs_label=" (case-sensitive)"
            echo "===================================================================================================="
            echo " DBSEARCH v${VERSION} - Mode: ${MATCH_MODE^^}${cs_label} | Target: ${target_label}"
            echo " Host: ${DB_HOST:-local-socket} | User: ${DB_USER:-auto} (${CRED_SOURCE}) | Term: '${SEARCH_TERM}'"
            echo "===================================================================================================="
        fi
        if [[ "$OUTPUT_FORMAT" == "table" ]]; then
            printf "%-20s | %-24s | %-22s | %-6s | %s\n" "DATABASE" "TABLE" "COLUMN" "MATCH" "PREVIEW"
            printf "%s\n" "---------------------+--------------------------+------------------------+--------+-------------------------------------"
        fi
    fi

    local total_tables=0 skipped_tables=0 match_columns=0 total_hits=0
    local db esc_db tbl size_mb col where_sql cnt preview

    for db in "${dbs[@]}"; do
        esc_db=$(sql_escape_str "$db")
        local tbl_query="SELECT table_name, ROUND(IFNULL(data_length + index_length, 0) / 1048576, 1) FROM information_schema.tables WHERE table_schema = '${esc_db}' AND table_type = 'BASE TABLE'"
        if [[ -n "$TABLE_FILTER" ]]; then
            local esc_tf
            esc_tf=$(sql_escape_str "$TABLE_FILTER")
            tbl_query="${tbl_query} AND table_name = '${esc_tf}'"
        fi
        tbl_query="${tbl_query} ORDER BY table_name;"

        while IFS=$'\t' read -r tbl size_mb; do
            [[ -z "$tbl" ]] && continue
            ((total_tables++))

            # Safety guard for huge tables (> MAX_TABLE_MB)
            if [[ "$FORCE" == false ]] && awk -v s="${size_mb:-0}" -v m="$MAX_TABLE_MB" 'BEGIN { exit !(s > m) }'; then
                ((skipped_tables++))
                log_warn "Skipping large table ${db}.${tbl} (${size_mb} MB > ${MAX_TABLE_MB} MB; use -f to force)"
                continue
            fi

            local esc_tbl
            esc_tbl=$(sql_escape_str "$tbl")
            local cols=()
            while IFS= read -r c; do
                [[ -n "$c" ]] && cols+=("$c")
            done < <("${MYSQL_CMD[@]}" -N -e "SELECT column_name FROM information_schema.columns WHERE table_schema = '${esc_db}' AND table_name = '${esc_tbl}' AND data_type IN (${col_types}) ORDER BY ordinal_position;" 2>/dev/null)

            [[ ${#cols[@]} -eq 0 ]] && continue

            local db_id tbl_id col_id
            db_id=$(sql_quote_ident "$db")
            tbl_id=$(sql_quote_ident "$tbl")

            for col in "${cols[@]}"; do
                col_id=$(sql_quote_ident "$col")
                where_sql=$(build_where_clause "$col_id")
                cnt=$("${MYSQL_CMD[@]}" -N -e "SELECT COUNT(*) FROM ${db_id}.${tbl_id} WHERE ${where_sql};" 2>/dev/null || echo "0")

                if [[ "$cnt" =~ ^[0-9]+$ ]] && (( cnt > 0 )); then
                    ((match_columns++))
                    ((total_hits += cnt))
                    preview=$("${MYSQL_CMD[@]}" -N -e "SELECT LEFT(CAST(${col_id} AS CHAR), 240) FROM ${db_id}.${tbl_id} WHERE ${where_sql} LIMIT 1;" 2>/dev/null | tr '\t\r\n' '   ' | tr -s ' ' || true)

                    printf "%s\t%s\t%s\t%s\t%s\n" "$db" "$tbl" "$col" "$cnt" "$preview" >> "$RESULTS_TSV"

                    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
                        local short_prev="$preview"
                        if (( ${#short_prev} > PREVIEW_LIMIT )); then
                            short_prev="${short_prev:0:$PREVIEW_LIMIT}..."
                        fi
                        printf "%-20s | %-24s | %-22s | %6d | %s\n" \
                            "${db:0:20}" "${tbl:0:24}" "${col:0:22}" "$cnt" "$short_prev"
                    elif [[ "$OUTPUT_FORMAT" == "default" ]]; then
                        echo -e "${C_GREEN}[MATCH]${C_RESET} ${C_BOLD}${db}.${tbl}.${col}${C_RESET} (${cnt} row(s))"
                        if [[ "$SHOW_VALUE" == true ]]; then
                            "${MYSQL_CMD[@]}" -t -e "SELECT * FROM ${db_id}.${tbl_id} WHERE ${where_sql} LIMIT ${MAX_ROWS};" 2>/dev/null | sed 's/^/  /'
                        else
                            "${MYSQL_CMD[@]}" -N -e "SELECT LEFT(CAST(${col_id} AS CHAR), 200) FROM ${db_id}.${tbl_id} WHERE ${where_sql} LIMIT ${MAX_ROWS};" 2>/dev/null | sed 's/^/  > /'
                        fi
                    fi
                fi
            done
        done < <("${MYSQL_CMD[@]}" -N -e "$tbl_query" 2>/dev/null)
    done

    case "$OUTPUT_FORMAT" in
        json)
            if command -v python3 >/dev/null 2>&1; then
                python3 - "$RESULTS_TSV" "$VERSION" "$SEARCH_TERM" "$MATCH_MODE" "$total_tables" "$skipped_tables" "$match_columns" "$total_hits" <<'PYEOF'
import json, sys, datetime
tsv, ver, term, mode, t_tbl, s_tbl, m_col, t_hits = sys.argv[1:9]
matches = []
with open(tsv, encoding="utf-8") as fh:
    for line in fh:
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 5:
            matches.append({
                "database": parts[0],
                "table": parts[1],
                "column": parts[2],
                "match_count": int(parts[3]),
                "preview": parts[4],
            })
print(json.dumps({
    "version": ver,
    "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "search_term": term,
    "mode": mode,
    "summary": {
        "tables_checked": int(t_tbl),
        "tables_skipped": int(s_tbl),
        "matching_columns": int(m_col),
        "total_matching_rows": int(t_hits),
    },
    "matches": matches,
}, indent=2))
PYEOF
            else
                log_err "python3 is required for -o json output."
                exit 1
            fi ;;
        csv)
            echo "database,table,column,match_count,preview"
            awk -F'\t' '{
                p = $5; gsub(/"/, "\"\"", p)
                printf "\"%s\",\"%s\",\"%s\",%s,\"%s\"\n", $1, $2, $3, $4, p
            }' "$RESULTS_TSV" ;;
        *)
            if [[ "$QUIET" == false ]]; then
                echo "===================================================================================================="
                if (( match_columns == 0 )); then
                    echo -e " ${C_YELLOW}No matches found for '${SEARCH_TERM}'.${C_RESET} Checked ${total_tables} table(s) (skipped: ${skipped_tables})."
                else
                    echo -e " ${C_GREEN}Found ${total_hits} matching row(s) across ${match_columns} column(s).${C_RESET} Checked ${total_tables} table(s) (skipped: ${skipped_tables})."
                fi
                echo "===================================================================================================="
            fi ;;
    esac
}

# =============================================================================
# Main
# =============================================================================
main() {
    parse_args "$@"
    init_colors
    setup_mysql_client
    run_search
}

main "$@"
