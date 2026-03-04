#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   Database Search Utility v1.0.0                                          ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Author:   Percio Castelo                                                ║
# ║   Contact:  percio@evolya.com.br | contato@perciocastelo.com.br           ║
# ║   Web:      https://perciocastelo.com.br                                  ║
# ║                                                                           ║
# ║   Function: An agile and secure Bash script to search for specific terms  ║
# ║             across all tables and columns of a MySQL or MariaDB database  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

DB_HOST="localhost"
DB_USER=""
DB_PASS=""
DB_NAME=""
SEARCH_TERM=""
TABLE=""
TABLE_LAYOUT=0
SHOW_VALUE=0
LIMIT=50
FORCE=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $0 [options] <search term>

Options:
    -d, --database <db>  Database to search within (REQUIRED)
    -t, --table <table>  Search only within specified table
    -h, --host <host>    MySQL host (default: localhost)
    -u, --user <user>    MySQL username (default: root, auto-detected)
    -p, --password <pw>  MySQL password (auto-detected)
    -l, --list           Display results in a formatted summary table
    -v, --value          Display the FULL ROW data when a match is found
    --limit <n>          Limit the character length of the preview in -l (default: 50)
    -f, --force          Force search on large tables (>1GB)

Examples:
    $0 -d mydb -l "search term"
    $0 -u user -p pass -d mydb -t wp_options -v "siteurl"
EOF
    exit 1
}

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

get_auto_credentials() {
    if [[ -n "$DB_USER" ]]; then
        return 0
    fi
    
    if [[ -f "/root/.my.cnf" ]]; then
        DB_USER=$(grep -E '^user\s*=' /root/.my.cnf 2>/dev/null | head -1 | sed -E "s/^user\s*=\s*['\"]?([^'\"]+)['\"]?/\1/")
        DB_PASS=$(grep -E '^pass\s*=' /root/.my.cnf 2>/dev/null | head -1 | sed -E "s/^pass\s*=\s*['\"]?([^'\"]+)['\"]?/\1/")
    fi
    
    if [[ -z "$DB_USER" && -f "/etc/psa/.psa.shadow" ]]; then
        DB_USER="admin"
        DB_PASS=$(cat /etc/psa/.psa.shadow 2>/dev/null)
    fi
    
    [[ -z "$DB_USER" ]] && DB_USER="root"
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--database) DB_NAME="$2"; shift 2 ;;
        -t|--table)    TABLE="$2"; shift 2 ;;
        -h|--host)     DB_HOST="$2"; shift 2 ;;
        -u|--user)     DB_USER="$2"; shift 2 ;;
        -p|--password) DB_PASS="$2"; shift 2 ;;
        -l|--list|-c)  TABLE_LAYOUT=1; shift 1 ;;
        -v|--value)    SHOW_VALUE=1; shift 1 ;;
        --limit)       LIMIT="$2"; shift 2 ;;
        -f|--force)    FORCE=1; shift 1 ;;
        -*)            echo -e "${RED}Unknown option: $1${NC}"; usage ;;
        *)
            if [[ -z "$SEARCH_TERM" ]]; then
                SEARCH_TERM="$1"
            fi
            shift 1
            ;;
    esac
done

[[ -z "$DB_NAME" ]] && error "No database specified! Use -d <database>"
[[ -z "$SEARCH_TERM" ]] && error "No search term specified!"

get_auto_credentials

# Export the password securely (Fixes access denied bug due to quotes)
[[ -n "$DB_PASS" ]] && export MYSQL_PWD="$DB_PASS"

# Build mysql base command
MYSQL_BASE="mysql -h $DB_HOST -u $DB_USER"

# Test connection
if ! $MYSQL_BASE -e "SELECT 1" > /dev/null 2>&1; then
    error "Failed to connect to MySQL. Check credentials."
fi

echo -e "${BLUE}Database:${NC} $DB_NAME"
echo -e "${BLUE}Host:${NC} $DB_HOST"
echo -e "${BLUE}User:${NC} $DB_USER"
[[ -n "$DB_PASS" ]] && echo -e "${BLUE}Password:${NC} ************" || echo -e "${BLUE}Password:${NC} (none)"
echo ""
echo -e "${BLUE}Searching for '${SEARCH_TERM}'...${NC}\n"

TOTAL_TABLES=0
MATCH_COUNT=0

if [[ $TABLE_LAYOUT -eq 1 ]]; then
    echo -e "Results Summary:\n"
    printf "%-25s | %-25s | %-5s | %s\n" "Table" "Column" "Count" "Preview"
    printf "%s\n" "--------------------------+---------------------------+-------+--------------------------------"
fi

if [[ -n "$TABLE" ]]; then
    TABLES="$TABLE"
else
    TABLES=$($MYSQL_BASE -N -e "SELECT table_name FROM information_schema.tables WHERE table_schema='$DB_NAME'" 2>/dev/null)
fi

for table in $TABLES; do
    [[ -z "$table" ]] && continue
    ((TOTAL_TABLES++))
    
    [[ $TABLE_LAYOUT -eq 0 ]] && echo -n "Table: $table "
    
    COLUMNS=$($MYSQL_BASE -N -e "SELECT column_name FROM information_schema.columns WHERE table_schema='$DB_NAME' AND table_name='$table'" 2>/dev/null)
    
    if [[ -z "$COLUMNS" ]]; then
        [[ $TABLE_LAYOUT -eq 0 ]] && echo -e "${YELLOW}[no columns]${NC}"
        continue
    fi
    
    FOUND=0
    
    for column in $COLUMNS; do
        ESCAPED_TERM="${SEARCH_TERM//\'/\'\'}"
        
        if [[ $TABLE_LAYOUT -eq 1 ]]; then
            # Summary mode (-l)
            COUNT=$($MYSQL_BASE -D "$DB_NAME" -N -e "SELECT COUNT(*) FROM \`$table\` WHERE \`$column\` LIKE '%${ESCAPED_TERM}%'" 2>/dev/null)
            
            if [[ -n "$COUNT" && "$COUNT" -gt 0 ]]; then
                ((MATCH_COUNT++))
                PREVIEW=$($MYSQL_BASE -D "$DB_NAME" -N -e "SELECT \`$column\` FROM \`$table\` WHERE \`$column\` LIKE '%${ESCAPED_TERM}%' LIMIT 1" 2>/dev/null | tr '\n' ' ' | tr -s ' ')
                
                if [[ ${#PREVIEW} -gt $LIMIT ]]; then
                    PREVIEW="${PREVIEW:0:$LIMIT}..."
                fi
                
                printf "%-25s | %-25s | %-5s | %s\n" "${table:0:25}" "${column:0:25}" "$COUNT" "$PREVIEW"
            fi
        else
            # Default Mode and Value Mode (-v)
            if [[ $SHOW_VALUE -eq 1 ]]; then
                # Fetch the entire row formatted in native MySQL table (-t) (Limited to 5 results to avoid clutter)
                RESULT=$($MYSQL_BASE -D "$DB_NAME" -t -e "SELECT * FROM \`$table\` WHERE \`$column\` LIKE '%${ESCAPED_TERM}%' LIMIT 5" 2>/dev/null)
            else
                # Only fetch the matching column
                RESULT=$($MYSQL_BASE -D "$DB_NAME" -N -e "SELECT \`$column\` FROM \`$table\` WHERE \`$column\` LIKE '%${ESCAPED_TERM}%'" 2>/dev/null)
            fi
            
            if [[ -n "$RESULT" ]]; then
                TRIMMED=$(echo "$RESULT" | tr -d '[:space:]')
                if [[ -n "$TRIMMED" ]]; then
                    ((MATCH_COUNT++))
                    FOUND=1
                    
                    if [[ $SHOW_VALUE -eq 1 ]]; then
                        echo -e "\n  ${GREEN}FOUND in column '$column' (Showing full row):${NC}"
                        # Indent the MySQL table to make it visually nested inside the current table
                        echo "$RESULT" | sed 's/^/    /' 
                    else
                        echo -e "\n  ${GREEN}FOUND in column '$column':${NC}"
                        echo "$RESULT" | while read -r line; do
                            [[ -n "$line" ]] && echo "    $line"
                        done
                    fi
                fi
            fi
        fi
    done
    
    if [[ $TABLE_LAYOUT -eq 0 ]]; then
        [[ $FOUND -eq 0 ]] && echo -e "${BLUE}[no match]${NC}"
    fi
done

echo ""
if [[ $MATCH_COUNT -eq 0 ]]; then
    echo -e "${YELLOW}No matches found for '${SEARCH_TERM}'.${NC}"
else
    echo -e "${GREEN}Found matches in $MATCH_COUNT column(s).${NC}"
fi
echo "Checked $TOTAL_TABLES table(s)."

exit 0