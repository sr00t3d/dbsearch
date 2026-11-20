# DBSearch

Readme: [PT-BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/dbsearch) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" alt="DBSearch" src="dbsearch-cover.webp" />

A fast, safe Bash CLI utility to search for strings or regular expressions across all tables and columns of MySQL or MariaDB databases. Designed for SysAdmins and hosting teams (cPanel/WHM, Plesk, DirectAdmin, HestiaPanel, or standalone Linux servers), it auto-detects panel credentials, skips binary/oversized tables safely, and outputs summary tables, full matching rows, JSON, or CSV.

## Features (v2.0.0)

* **Universal Panel Credential Auto-Detection:** Reads `/root/.my.cnf` (`pass=` and `password=`), `~/.my.cnf`, Plesk (`/etc/psa/.psa.shadow`), DirectAdmin (`/usr/local/directadmin/conf/mysql.conf`), HestiaPanel (`/usr/local/hestia/conf/mysql.conf`), or Unix socket auth automatically.
* **Smart Column Filtering & Large-Table Guard:** Scans text, JSON, enum, and set columns by default (avoiding wasted scans on BLOB/binary columns, with `--include-numeric` optional) and automatically skips tables larger than `1024 MB` (`--max-table-mb`) unless `-f, --force` is passed.
* **Flexible Search Modes:** Substring (`LIKE` with proper wildcard/quote escaping), exact match (`-x, --exact`), MySQL regular expressions (`-r, --regex`), case-sensitive (`-C, --case-sensitive`), single table (`-t`), or multi-database (`-A, --all-databases`).
* **Structured Output (`default`, `table`/`-l`, `json`, `csv`):** Print compact summary tables, full MySQL rows (`-v`), RFC-4180 CSV, or structured JSON ready for incident response and forensic audits (e.g., hunting `eval(base64_decode` injections across WordPress databases).

## Prerequisites

* `bash` 4.0+
* `mysql` or `mariadb` CLI client
* `python3` (optional; required only for `-o json`)

## Usage & Options

```text
DBSearch v2.0.0
Fast, safe full-database search CLI for MySQL and MariaDB.

Usage:
  dbsearch.sh [OPTIONS] <search_term>

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
```

## Practical Examples

**Summary table search for an old domain across a WordPress database:**
```bash
./dbsearch.sh -d wordpress_db -l "old-domain.example.com"
```

**Inspect full matching rows in a specific table:**
```bash
./dbsearch.sh -d wordpress_db -t wp_options -v "siteurl"
```

**Hunt obfuscated PHP payloads across all databases and export JSON:**
```bash
./dbsearch.sh -A -r -o json "eval\\(base64_decode" > malware-hits.json
```

**Export multi-database search results to CSV:**
```bash
./dbsearch.sh -A -o csv "old-domain.example.com" > migration-audit.csv
```

## Real Output Example

```text
====================================================================================================
 DBSEARCH v2.0.0 - Mode: LIKE | Target: dbsearch_lab
 Host: local-socket | User: auto (unix_socket (root)) | Term: 'old-domain.example.com'
====================================================================================================
DATABASE             | TABLE                    | COLUMN                 | MATCH  | PREVIEW
---------------------+--------------------------+------------------------+--------+-------------------------------------
dbsearch_lab         | wp_options               | option_value           |      3 | https://old-domain.example.com
dbsearch_lab         | wp_posts                 | post_content           |      1 | Visit https://old-domain.example.com/docs for details.
dbsearch_lab         | wp_posts                 | guid                   |      2 | https://old-domain.example.com/?p=1
====================================================================================================
 Found 6 matching row(s) across 3 column(s). Checked 2 table(s) (skipped: 0).
====================================================================================================
```

## Detailed Tutorial

Read the full walkthrough: [**Perform an Enhanced Search in Databases**](https://perciocastelo.com.br/blog/perform-an-enhanced-search-in-databases.html)

## License

This project is licensed under the [Apache License 2.0](LICENSE).

---
Author: **Percio Castelo**  
Contact: [contato@perciocastelo.com.br](mailto:contato@perciocastelo.com.br)  
Website: [https://perciocastelo.com.br](https://perciocastelo.com.br)
