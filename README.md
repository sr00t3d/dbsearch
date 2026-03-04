# Database Search Utility

Read me: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/dbsearch) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="dbsearch-cover.webp" />

> **Bash rewrite of the original dbsearch.pl utility in Perl by Michael Karr (HostGator)**

An agile and secure Bash script to search for specific terms across all tables and columns of a MySQL or MariaDB database. Designed to make life easier for sysadmins, support analysts, and developers when investigating data, performing migrations, or debugging CMSs (such as WordPress).

## Features

* **Global or Specific Search:** Search the entire database or restrict the search to a specific table.
* **Summary Layout (`-l` or `-c`):** Displays results in a formatted table, showing the number of occurrences and a preview of the found data.
* **Full Row View (`-v`):** Renders the entire row (all fields) in the native MySQL table format when a match is found (limited to 5 results to avoid cluttering the screen).
* **Preview Control (`--limit`):** Adjust the preview text size in the summary table.
* **Credential Security:** Uses the `MYSQL_PWD` environment variable behind the scenes to prevent the password from being exposed in the CLI or triggering security alerts in bash history.
* **Auto-Detection:** Capable of automatically detecting credentials via `~/.my.cnf` or Plesk shadow files (`/etc/psa/.psa.shadow`), eliminating the need to use `-u` and `-p` on already authenticated servers.

## Installation

Download and make it executable

```bash
curl -O https://raw.githubusercontent.com/sr00t3d/dbsearch/refs/heads/main/dbsearch.sh
chmod +x dbsearch.sh

# Run
./dbsearch.sh [options] <search term>
```

## Options and Parameters

```text
Usage: ./dbsearch.sh [options] <search term>

Options:
    -d, --database <db>  Target database (REQUIRED)
    -t, --table <table>  Search only in the specified table
    -h, --host <host>    MySQL host (default: localhost)
    -u, --user <user>    MySQL user (default: root, or auto-detected)
    -p, --password <pw>  MySQL password
    -l, --list, -c       Displays results in a summary table (with count)
    -v, --value          Displays the FULL ROW in native MySQL format
    --limit <n>          Limits the preview text size in -l mode (default: 50)
    -f, --force          Forces the search by ignoring warnings about very large tables
```

## Complete Usage Examples

### 1. Simple Global Search (Unformatted)

Scans the entire database looking for the string "siteurl". Useful to see exactly where data is scattered during a migration.

```bash
./dbsearch.sh -d database -u username -p 'password' siteurl
```

### 2. Global Search with Formatted Summary (`-l`)

Shows a table summary of all tables and columns that contain the search term across the entire database.

```bash
./dbsearch.sh -d database -u username -p 'password' -l "https://domain"

Database: database
Host: localhost
User: username
Password: ************

Searching for 'siteurl'...

Results Summary:

Table                     | Column                    | Count | Preview
--------------------------+---------------------------+-------+--------------------------------
wp_options                | option_name               | 1     | siteurl 
wp_posts                  | post_content              | 2     | O WordPress utiliza duas variáveis principais para...
wp_posts                  | post_excerpt              | 2     | Aprenda a alterar a URL do WordPress via WP-CLI, b...
```

### 3. Extracting the exact value from a table (`-t` and `-v`)

Use the `-v` flag to view all data from the matching row, perfect for checking the `option_value` without having to open the MySQL prompt:

```bash
./dbsearch.sh -d database -u username -p 'password' -t wp_options -v siteurl

Database: database
Host: localhost
User: username
Password: ************

Searching for 'siteurl'...

Table: wp_actionscheduler_actions [no match]
Table: wp_actionscheduler_claims [no match]
Table: wp_actionscheduler_groups [no match]
Table: wp_actionscheduler_logs [no match]
Table: wp_admin_columns [no match]
Table: wp_bricks_filters_element [no match]
Table: wp_bricks_filters_index [no match]
Table: wp_bricks_filters_index_job [no match]
Table: wp_commentmeta [no match]
Table: wp_comments [no match]
Table: wp_fea_emails [no match]
Table: wp_fea_plans [no match]
Table: wp_fea_submissions [no match]
Table: wp_fea_subscriptions [no match]
Table: wp_ilj_linkindex [no match]
Table: wp_links [no match]
Table: wp_options 
  FOUND in column 'option_name' (Showing full row):
    +-----------+-------------+----------------------+----------+
    | option_id | option_name | option_value         | autoload |
    +-----------+-------------+----------------------+----------+
    |         2 | siteurl     | https://domain.com   | on       |
    +-----------+-------------+----------------------+----------+
Table: wp_post_smtp_logmeta [no match]
Table: wp_post_smtp_logs [no match]
Table: wp_post_views [no match]
Table: wp_postmeta [no match]
Table: wp_posts 
  FOUND in column 'post_content' (Showing full row):
```

### 4. Adjusting the preview size (`--limit`)

If the text you are searching for contains very large content and is breaking your screen formatting in summary mode, you can reduce the preview (e.g., 20 characters):

```bash
./dbsearch.sh -d database -u root -p 'password' -l --limit 20 "long_term"

Database: database
Host: localhost
User: username
Password: ************

Searching for 'siteurl'...

Results Summary:

Table                     | Column                    | Count | Preview
--------------------------+---------------------------+-------+--------------------------------
wp_options                | option_name               | 1     | siteurl 
wp_posts                  | post_content              | 2     | O WordPress utiliza ...
wp_posts                  | post_excerpt              | 2     | Aprenda a alterar a ...

Found matches in 3 column(s).
Checked 61 table(s).
```

### 5. Connecting to a remote server (`-h`)

To search data in a database that is not on `localhost`:

```bash
./dbsearch.sh -h 192.168.1.100 -d production_db -u admin -p 'password' -l "error500"
```

### 6. Ignoring limits on huge databases (`-f`)

If the database is very large and the script displays a size limit warning, force a full scan:

```bash
./dbsearch.sh -d huge_database -l -f "old_record"
```

### 7. Quick Use with Auto-Detection (Root/Plesk)

If you are already logged in as root and have the `~/.my.cnf` file configured (or are on a Plesk server), simply omit the credentials:

```bash
./dbsearch.sh -d database -l "admin@email.com"
```

### 8. Listing values of a table

```bash
./dbsearch.sh -d database -t wp_options -l siteurl

Database: database
Host: localhost
User: username
Password: ************

Searching for 'siteurl'...

Results Summary:

Table                     | Column                    | Count | Preview
--------------------------+---------------------------+-------+--------------------------------
wp_options                | option_name               | 1     | siteurl 
```

### 9. Extracting values from table

```bash
./dbsearch.sh -d database -t wp_options -v siteurl

Database: database
Host: localhost
User: username
Password: ************

Searching for 'siteurl'...

Table: wp_options 
  FOUND in column 'option_name' (Showing full row):
    +-----------+-------------+----------------------+----------+
    | option_id | option_name | option_value         | autoload |
    +-----------+-------------+----------------------+----------+
    |         2 | siteurl     | https://domain.com   | on       |
    +-----------+-------------+----------------------+----------+

Found matches in 1 column(s).
Checked 1 table(s).
```

## Technical Details

* The script queries `information_schema.columns` to map the database structure before starting the scan, ensuring it does not attempt to search in non-existent columns.
* In list mode (`-l`), the script uses `SELECT COUNT(*)` to improve performance when counting in large tables, extracting only a text sample via `LIMIT 1` for the preview.
* The search term automatically escapes single quotes (`'`) to prevent SQL syntax errors or unwanted breaks during database reading.

## Important Notes

1. **Requires root** - Needs to read files in `/etc/`
2. **Bash Only** - Does not work in `sh` or `zsh` without modification
3. **Specific to cPanel** - Designed for cPanel/Plesk servers

## Credits

- **Original Author**: Michael Karr (HostGator)
- **Original Date**: 2012
- **Original Version**: 0.3.4
- **Bash Rewrite**: 2026
- **Purpose**: Administrative tool for searching specific terms across all tables and columns of a MySQL or MariaDB database.

## Links

- Original HostGator Wiki: `https://gatorwiki.hostgator.com/Security/DBSearch`
- Original Repository: `http://git.toolbox.hostgator.com/dbsearch`

## Legal Notice

> [!WARNING]
> This software is provided "as is". Always ensure you have explicit permission before running it. The author is not responsible for any misuse, legal consequences, or data impact caused by this tool.

## Detailed Tutorial

For a complete step-by-step guide, check out my full article:

👉 [**Perform an enhanced search in databases**](https://perciocastelo.com.br/blog/perform-an-enhanced search-in-databases.html)

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for more details.

---

**Note**: This is an unofficial rewrite and is not supported/sponsored by HostGator.