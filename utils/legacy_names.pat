# legacy_names.pat — the pre-kyr names check_legacy_names.sh refuses: one PCRE per line, '#' starts a comment line.
# A literal that would match its own line has one character in brackets, so this file passes its own check.
# Left out on purpose: bare DB and Utils (database, yyjson, fail2ban); those go by review.
\b(?:DB|db)_(?:app|server|http|jose|lmdb|cli)(?![A-Za-z0-9])
\bDB_(?:APP|SERVER|CLI|LMDB|HTTP|JOSE|FILES|BENCH)_
\bDB_(?:CODE_ROOT|BACKEND)\b
\blib(?:db|DB)[-_](?:app|http|jose|lmdb)
\bdb-(?:app|server|http|cli|sysmon)\b
\bHS_[A-Z]
\bhs_[a-z]
\bhs-(?:frontend|web-shell|managed|e2e)\b
HSFront[E]nd
\bhome_?server\b|\bhomeserver\b
\bRMS_app\b|\bio[-_]rms(?![A-Za-z0-9])|\bio_rms_|\biorms_|\bIORMS_
RomanHorshkov/(?:DB|DB_[a-z]+|Utils|HSFront[E]nd|RMS[_]app|io[_]rms)\b
Upstream-Name: Util[s]|\bUtils/
(?:^|[^A-Za-z0-9_$])DB/[A-Za-z]|\.\./DB\b|\bDB platform\b
\bNGINX_(?:API_RATE|LOGIN_RATE|CONN_LIMIT)\b
\bSYSMON_PERIOD_S\b
\bRH_DEPS_CACHE\b|\brh-utils?\b|\brh-util-|<util[s]/
/srv/(?:db|home_[s]erver)\b|/opt/d[b]\b|/(?:run|etc)/home_[s]erver\b|\bdbctl\b
d[b]_lmdb_manifest|\.d[b]_app\.lock
\b(?:ENGINE_[0-9n*]+_)?LEGACY_(?:TREES|USER|UNITS|APPARMOR|NGINX|SECRETS|LEDGER|ROOT|STORE|STAGE)\b
E2E_D[B]_|(?:FROM|NEXT|N|K|V)_DBS?(?![A-Za-z0-9])
\bDB (?:integration|stress|share-link)\b|\bplatform DB\b
