# Disclaimer

This a PoC of using a dataset on email for semantic search on PostgreSQL DB with the pgvector extension installed.

## Decompressing the Database Dump
If you need to decompress the PostgreSQL database dump file (`email_pgsql.tar.bz2`), you can use the following command:

```sh
tar -xvjf email_pgsql.tar.bz2
```

## Loading the Database Dump
After decompressing the database dump, you can load it into your PostgreSQL database using a command like the following:

```sh
psql -h localhost -U your_pg_username -d pgdb_name -f create_email_table_partition_copy_index.sql
```

Note: create_email_table_partition_copy_index.sql will load the email.csv file from the \COPY command


## Setup your .env from .env.example
```sh
PGDATABASE=pgdb_name
PGHOST=localhost
PGUSER=
PGPASSWORD=
PGPORT=5432
OPENAI_API_KEY=
```

## Init dev env & install module with Bundler

```sh
devbox shell # open a shell with ruby and bundler installed
bundler install
ruby query_db.rb # or bundler exec query.rb
```

## Optional : Embedding from OpenAI the DB
Actually, the email.csv file have already the vector for each email content. If you want, you cand reset the column embedding_ada2 and launch the script

```sh
chmod +x /run_parallel.sh
# .run_parallel.sh <nb instance of update_embedding_ada2.rb> 
./run_parallel.sh 8  

# Recommend 8. You'll get limit rate error from OpenAI. Relaunch the script if necessary 
```
