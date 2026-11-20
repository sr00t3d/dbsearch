# DBSearch

Readme: [EN](README.md)

![License](https://img.shields.io/github/license/sr00t3d/dbsearch) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" alt="DBSearch" src="dbsearch-cover.webp" />

Utilitário CLI em Bash rápido e seguro para pesquisar termos ou expressões regulares em todas as tabelas e colunas de bancos MySQL ou MariaDB. Projetado para SysAdmins e equipes de hospedagem (cPanel/WHM, Plesk, DirectAdmin, HestiaPanel ou servidores Linux dedicados), detecta credenciais automaticamente, protege contra varreduras acidentais em tabelas gigantes e gera saída em tabela resumida, linhas completas, JSON ou CSV.

## Funcionalidades (v2.0.0)

* **Auto-detecção Universal de Credenciais:** Lê automaticamente `/root/.my.cnf` (`pass=` e `password=`), `~/.my.cnf`, Plesk (`/etc/psa/.psa.shadow`), DirectAdmin (`/usr/local/directadmin/conf/mysql.conf`), HestiaPanel (`/usr/local/hestia/conf/mysql.conf`) ou autenticação via `unix_socket`.
* **Filtro Inteligente de Colunas e Proteção de Tabelas Grandes:** Varre apenas colunas textuais, JSON, `enum` e `set` por padrão (evitando leitura inútil de `BLOB`/binários, com `--include-numeric` opcional) e pula automaticamente tabelas maiores que `1024 MB` (`--max-table-mb`) a menos que `-f, --force` seja informado.
* **Modos Flexíveis de Busca:** Substring (`LIKE` com escape seguro de aspas e wildcards), correspondência exata (`-x, --exact`), expressão regular MySQL (`-r, --regex`), sensível a maiúsculas (`-C, --case-sensitive`), tabela única (`-t`) ou todos os bancos (`-A, --all-databases`).
* **Saída Estruturada (`default`, `table`/`-l`, `json`, `csv`):** Tabela resumida com preview, linhas completas (`-v`), CSV RFC-4180 e JSON pronto para resposta a incidentes e auditorias forenses (ex.: caçar injeções `eval(base64_decode` em bancos WordPress).

## Pré-requisitos

* `bash` 4.0+
* Cliente CLI `mysql` ou `mariadb`
* `python3` (opcional; necessário apenas para `-o json`)

## Exemplos Práticos

**Tabela resumida procurando um domínio antigo em um banco WordPress:**
```bash
./dbsearch.sh -d wordpress_db -l "old-domain.example.com"
```

**Exibir linhas completas encontradas em uma tabela específica:**
```bash
./dbsearch.sh -d wordpress_db -t wp_options -v "siteurl"
```

**Caçar payloads PHP ofuscados em todos os bancos e exportar JSON:**
```bash
./dbsearch.sh -A -r -o json "eval\\(base64_decode" > malware-hits.json
```

**Exportar busca multi-banco em CSV:**
```bash
./dbsearch.sh -A -o csv "old-domain.example.com" > migration-audit.csv
```

## Exemplo de Saída Real

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

## Tutorial Detalhado

Confira o guia completo no blog: [**Realizar uma Busca Aprimorada em Bancos de Dados**](https://perciocastelo.com.br/blog/perform-an-enhanced-search-in-databases.html)

## Licença

Este projeto é distribuído sob a licença [Apache License 2.0](LICENSE).

---
Autor: **Percio Castelo**  
Contato: [contato@perciocastelo.com.br](mailto:contato@perciocastelo.com.br)  
Website: [https://perciocastelo.com.br](https://perciocastelo.com.br)
