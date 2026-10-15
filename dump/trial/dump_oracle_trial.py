"""dump_oracle_trial.py - TRIAL: dump Oracle tables as they are with python-oracledb, without R or a JVM.

Input:  Oracle tables, named schema.table on the command line
Output: <out>/<schema>/<table>.parquet, written batch by batch, with the same fd.* key/value stamps as
        R/dump_oracle.R (fd.source, fd.dumped, fd.rows, fd.driver, fd.script, fd.commit, fd.dirty)

A trial (2026-10-15, maintainer's request), on the tables the R dumper (RJDBC) failed on or crawled through:
LOBs fetched one row at a time, a 28 M-row fetch that lost its connection, a NUMBER the JDBC driver could not parse.
Here LOBs come inline with the rows (fetch_lobs = False), rows come in Arrow batches written as they arrive, and
there is no JVM. If it wins, it replaces the R dumper; until then it writes outside raw/.

Run from the repo root, in the maintainer's terminal (the password is in the macOS keychain):
  ~/.venvs/fishydump/bin/python dump/trial/dump_oracle_trial.py --out <dir> afli.afli afli.sjalfvirkir_maelar ...
Credentials as mar::connect_mar() takes them: MAR_USER/MAR_PASS, else the keychain's service "mar".
"""

import argparse, datetime, os, subprocess, sys, time

import duckdb
import keyring
import oracledb
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.parquet as pq

DSN = "hafmey.hafro.is:1521/sjor.hafro"          # mar::connect_mar(): hafmey.hafro.is, 1521, sjor (.hafro)
BATCH = 100_000

# Columns the driver should not fetch as they are: read as text in Oracle's own form (as R/dump_oracle.R does)
TEXT = {"SDO_GEOMETRY": "TO_CHAR(SDO_UTIL.TO_WKTGEOMETRY({c}))", "XMLTYPE": "XMLSERIALIZE(DOCUMENT {c} AS CLOB)"}


def credentials():
    user, pw = os.environ.get("MAR_USER"), os.environ.get("MAR_PASS")
    if user:
        return user, pw
    # the keychain cannot list a service's accounts from Python; R's keyring can, without the secret
    user = subprocess.run(["Rscript", "-e", 'cat(keyring::key_list("mar")$username[1])'],
                          capture_output=True, text=True).stdout.strip()
    pw = keyring.get_password("mar", user)
    if not user or pw is None:
        sys.exit("no credentials: set MAR_USER/MAR_PASS, or keyring::key_set('mar', username = 'ops$user') in R")
    return user, pw


def git_stamp():
    g = lambda *a: subprocess.run(["git", *a], capture_output=True, text=True).stdout.strip()
    return g("rev-parse", "HEAD") or "NA", "true" if g("status", "--porcelain") else "false"


def columns(con, owner, table):
    cur = con.cursor()
    cur.execute("""SELECT column_name, data_type, data_precision, data_scale FROM all_tab_columns
                   WHERE owner = :o AND table_name = :t ORDER BY column_id""", o=owner, t=table)
    return [dict(name=r[0], type=r[1], precision=r[2], scale=r[3]) for r in cur]


def arrow_type(c):
    """The Arrow type a column is written as: by Oracle's declaration, as R/dump_oracle.R types it."""
    t = c["type"]
    if t == "NUMBER":
        return pa.int32() if c["scale"] == 0 and c["precision"] is not None and c["precision"] <= 9 else pa.float64()
    if t in ("FLOAT", "BINARY_DOUBLE", "BINARY_FLOAT"):
        return pa.float64()
    if t == "DATE" or t.startswith("TIMESTAMP"):
        return pa.timestamp("us")                 # no time zone: plain TIMESTAMP in parquet, as AGENTS.md wants
    if t in ("BLOB", "RAW", "LONG RAW"):
        return pa.binary()
    return pa.string()


def cast_column(arr, typ):
    if arr.type == typ:
        return arr
    # NUMBER(p <= 9, 0) to int32 safely (an overflow raises); every other number to float64, as R/dump_oracle.R does
    return pc.cast(arr, typ, safe=pa.types.is_integer(typ) or not pa.types.is_floating(typ))


def write_batches(batches, schema, meta, path, label):
    """Arrow tables to one parquet file as they arrive; then a streaming rewrite through DuckDB that adds the fd.*
    stamps with the row count (known only at the end) and writes plain TIMESTAMP. Returns the rows written."""
    tmp = path + ".partial"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    n, t0 = 0, time.time()
    writer = pq.ParquetWriter(tmp, schema)
    try:
        for tbl in batches:
            tbl = pa.table([cast_column(tbl.column(i).combine_chunks(), schema.field(i).type)
                            for i in range(len(schema))], schema=schema)
            writer.write_table(tbl)
            n += tbl.num_rows
            print(f"  {label}: {n:,} rows, {time.time() - t0:.0f} s", flush=True)
    finally:
        writer.close()
    kv = dict(meta, **{"fd.rows": str(n)})
    q = lambda x: "'" + str(x).replace("'", "''") + "'"
    con = duckdb.connect()
    con.execute(f"COPY (SELECT * FROM read_parquet({q(tmp)})) TO {q(path)} "
                f"(FORMAT parquet, KV_METADATA {{{', '.join(f'{q(k)}: {q(v)}' for k, v in kv.items())}}})")
    con.close()
    os.remove(tmp)
    return n


def dump_table(con, owner, table, path, run, numbers_as_text=False):
    cols = columns(con, owner, table)
    if not cols:
        raise RuntimeError(f"{owner}.{table}: no columns visible")
    conv = dict(TEXT, **({"NUMBER": "TO_CHAR({c})"} if numbers_as_text else {}))
    sel = ", ".join(conv[c["type"]].format(c=f'"{c["name"]}"') + f' AS "{c["name"]}"' if c["type"] in conv
                    else f'"{c["name"]}"' for c in cols)
    sql = f'SELECT {sel} FROM "{owner}"."{table}"'
    # with numbers as text, a NUMBER is written as the text Oracle gave: a value the driver could not parse stays visible
    schema = pa.schema([(c["name"].lower(), pa.string() if numbers_as_text and c["type"] == "NUMBER" else arrow_type(c))
                        for c in cols])
    meta = {"fd.source": f"{owner.lower()}.{table.lower()}", "fd.dumped": run["dumped"],
            "fd.driver": f"python-oracledb {oracledb.__version__} thin", "fd.script": "dump/trial/dump_oracle_trial.py",
            "fd.commit": run["commit"], "fd.dirty": run["dirty"]}
    if numbers_as_text:
        meta["fd.numbers"] = "text"
    t0 = time.time()
    n = write_batches((pa.table(odf) for odf in con.fetch_df_batches(statement=sql, size=BATCH)),
                      schema, meta, path, f"{owner.lower()}.{table.lower()}")
    return n, time.time() - t0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", required=True, help="trial output folder (not raw/)")
    ap.add_argument("tables", nargs="+", help="schema.table ...")
    a = ap.parse_args()
    oracledb.defaults.fetch_lobs = False         # LOBs as str/bytes, inline with the rows
    user, pw = credentials()
    commit, dirty = git_stamp()
    run = {"dumped": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+0000"),
           "commit": commit, "dirty": dirty}
    print(f"python-oracledb {oracledb.__version__} (thin), {DSN}, as {user}", flush=True)
    rows = []
    for spec in a.tables:
        owner, table = (x.upper() for x in spec.split("."))
        path = os.path.join(a.out, owner.lower(), table.lower() + ".parquet")
        with oracledb.connect(user=user, password=pw, dsn=DSN) as con:   # one connection per table: a temporary
            try:                                                          # LOB never outlives its table
                n, s = dump_table(con, owner, table, path, run)
                how = "as is"
            except Exception as e:
                print(f"  {spec}: {e} - fetching again with its numbers as text", flush=True)
                try:
                    n, s = dump_table(con, owner, table, path, run, numbers_as_text=True)
                    how = "numbers as text"
                except Exception as e2:
                    print(f"  {spec}: FAILED - {e2}", flush=True)
                    rows.append((spec, None, None, "failed")); continue
        mb = os.path.getsize(path) / 1e6
        print(f"{spec}: {n:,} rows in {s:.0f} s ({n / max(s, 1e-9):,.0f} rows/s, {mb:,.1f} MB, {how})", flush=True)
        rows.append((spec, n, s, how))
    print("\nsummary")
    for spec, n, s, how in rows:
        print(f"  {spec:40s} {'' if n is None else f'{n:>12,}'} rows  {'' if s is None else f'{s:>7.0f}'} s  {how}")


if __name__ == "__main__":
    main()
