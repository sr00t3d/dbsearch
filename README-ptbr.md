# Database Search Utility

Leia-me: [EN](README.md)

![Licença](https://img.shields.io/github/license/sr00t3d/dbsearch) ![Script Shell](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="dbsearch-cover.webp" />

> **Reescrita em Bash do utilitário dbsearch.pl original em Perl por Michael Karr (HostGator)**

Um script em Bash ágil e seguro para buscar termos específicos em todas as tabelas e colunas de um banco de dados MySQL ou MariaDB. Desenvolvido para facilitar a vida de sysadmins, analistas de suporte e desenvolvedores na investigação de dados, migrações ou debugging de CMSs (como WordPress).

## Funcionalidades

* **Busca Global ou Específica:** Procure em todo o banco de dados ou restrinja a busca a uma tabela específica.
* **Layout de Resumo (`-l` ou `-c`):** Exibe os resultados em uma tabela formatada, mostrando a quantidade de ocorrências e um preview do dado encontrado.
* **Visualização de Linha Completa (`-v`):** Renderiza a linha inteira (todos os campos) no formato de tabela nativo do MySQL quando uma correspondência é encontrada (limitado a 5 resultados para não poluir a tela).
* **Controle de Preview (`--limit`):** Ajuste o tamanho do texto de preview na tabela de resumo.
* **Segurança de Credenciais:** Utiliza a variável de ambiente `MYSQL_PWD` por baixo dos panos para evitar que a senha fique exposta na CLI ou gere alertas de segurança no histórico do bash.
* **Auto-Detecção:** Capaz de detectar credenciais automaticamente via `~/.my.cnf` ou arquivos de shadow do Plesk (`/etc/psa/.psa.shadow`), dispensando o uso de `-u` e `-p` em servidores já autenticados.

## Instalação


Baixar e tornar executável

```bash
curl -O https://raw.githubusercontent.com/sr00t3d/dbsearch/refs/heads/main/dbsearch.sh
chmod +x dbsearch.sh

# Execute
./dbsearch [options] <search term>
```

## Opções e Parâmetros

```text
Usage: ./dbsearch.sh [options] <search term>

Options:
    -d, --database <db>  Banco de dados alvo (OBRIGATÓRIO)
    -t, --table <table>  Busca apenas na tabela especificada
    -h, --host <host>    Host do MySQL (padrão: localhost)
    -u, --user <user>    Usuário do MySQL (padrão: root, ou auto-detectado)
    -p, --password <pw>  Senha do MySQL
    -l, --list, -c       Exibe os resultados em uma tabela de resumo (com contagem)
    -v, --value          Exibe a LINHA COMPLETA no formato nativo do MySQL
    --limit <n>          Limita o tamanho do texto de preview no modo -l (padrão: 50)
    -f, --force          Força a busca ignorando avisos de tabelas muito grandes
```

## Exemplos Completos de Uso

### 1. Busca Global Simples (Sem Formatação)

Varre todo o banco de dados procurando pela string "siteurl". Útil para ver exatamente onde os dados estão espalhados durante uma migração.

```bash
./dbsearch.sh -d database -u username -p 'password' siteurl
```

### 2. Busca Global com Resumo Formatado (`-l`)

Mostra um resumo em tabela de todas as tabelas e colunas que contêm o termo pesquisado em todo o banco de dados.

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

### 3. Extraindo o valor exato de uma tabela (`-t` e `-v`)

Use a flag `-v` para visualizar todos os dados da linha correspondente, perfeito para verificar o `option_value` sem precisar abrir o prompt do MySQL:

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

### 4. Ajustando o tamanho da pré-visualização (`--limit`)

Se o texto que você está procurando contiver conteúdo muito grande e estiver quebrando a formatação da sua tela no modo de resumo, você pode reduzir a pré-visualização (por exemplo, 20 caracteres):

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

### 5. Conectando a um servidor remoto (`-h`)

Para pesquisar dados em um banco de dados que não está em `localhost`:

```bash
./dbsearch.sh -h 192.168.1.100 -d production_db -u admin -p 'password' -l "error500"
```

### 6. Ignorando limites em bancos de dados enormes (`-f`)

Se o banco de dados for muito grande e o script exibir um aviso de limite de tamanho, force uma varredura completa:

```bash
./dbsearch.sh -d huge_database -l -f "old_record"
```

### 7. Uso Rápido com Auto-Detecção (Root/Plesk)

Se você já estiver logado como root e tiver o arquivo `~/.my.cnf` configurado (ou estiver em um servidor Plesk), simplesmente omita as credenciais:

```bash
./dbsearch.sh -d database -l "admin@email.com"
```

### 8. Listando valores de uma tabela

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

### 9. Extraindo valores da tabela

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

## Detalhes Técnicos

* O script consulta a `information_schema.columns` para mapear a estrutura do banco antes de iniciar a varredura, garantindo que não tente buscar em colunas inexistentes.
* No modo de lista (`-l`), o script utiliza `SELECT COUNT(*)` para melhorar a performance de contagem em tabelas extensas, extraindo apenas uma amostra de texto via `LIMIT 1` para o preview.
* O termo de busca sofre escape automático de aspas simples (`'`) para evitar erros de sintaxe SQL ou quebras indesejadas durante a leitura do banco.

## Notas Importantes

1. **Requer root** - Precisa ler arquivos em `/etc/`
2. **Apenas Bash** - Não funciona em `sh` ou `zsh` sem modificação
3. **Específico para cPanel** - Projetado para servidores cPanel/Plesk

## Créditos

- **Autor Original**: Michael Karr (HostGator)
- **Data Original**: 2012
- **Versão Original**: 0.3.4
- **Reescrita em Bash**: 2026
- **Propósito**: Ferramenta de administração de busca de termos específicos em todas as tabelas e colunas de um banco de dados MySQL ou MariaDB.

## Links

- Wiki Original da HostGator: `https://gatorwiki.hostgator.com/Security/DBSearch`
- Repositório Original: `http://git.toolbox.hostgator.com/dbsearch`

## Aviso Legal

> [!WARNING]
> Este software é fornecido "como está". Sempre garanta que você tem permissão explícita antes de executá-lo. O autor não é responsável por qualquer uso indevido, consequências legais ou impacto em dados causado por esta ferramenta.

## Tutorial Detalhado

Para um guia completo passo a passo, confira meu artigo completo:

👉 [**Execute uma busca melhorada em bancos de dados**](https://perciocastelo.com.br/blog/perform-an-enhanced search-in-databases.html)

## Licença

Este projeto está licenciado sob a **GNU General Public License v3.0**. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.

---

**Nota**: Esta é uma reescrita não oficial e não suportada/patrocinada pela HostGator.