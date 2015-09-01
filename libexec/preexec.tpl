#!/bin/bash

# Script preexec.in
# -----------------
# To be used as a ExecStartPre= in service file (when systemd is used),
# or on sysvinit to be called before exec.in.

. {{ m.pkgdatadir }}/cont-postgresql.sh

{{ m.cont_script_header }}

pgcont_check_external_storage || exit 1

# Initialize the data directory when needed
{{ m.libexecdir }}/cont-postgresql-initdb || exit 1

# Note that PostgreSQL itself does not count with container scenario;  it uses
# the postmaster.pid file to check whether some other PG server does not run
# against the same data directory and fails if yes.
# In docker case, the server always gets the same PID.  If PG server detects pid
# file having its own PID stored inside, the server thinks that the pid file is
# staled probably from previous system boot (but the pid file existence most
# probably means that yet another container runs the same data).  As there is
# hard to guess the real situation, rather be fatal _right here_, before the
# server starts and some catastrophic scenario happens.

pidfile="$(pgcont_opt pidfile)"
if pgcont_opt_check clear_pgdata_pidfile true; then
    rm -f "$pidfile" || {
        cont_error "can't remove pidfile $pidfile"
        exit 1
    }
fi

test -f "$pidfile" \
    && cont_error \
        "seems like another PostgreSQL server uses DB data because" \
        "the file '$pidfile' already exists.  If you are" \
        "sure that the pidfile is leftover, use 'clear_pgdata_pidfile'" \
        "option (see 'container-usage' for more info)" \
    && exit 1

# Run the checking script here manually, usually placed in ExecStartPre=.
{% if config.os.id == "fedora" and config.os.version >= 22 or
      config.os.id == "rhel" and config.os.version >= 8 -%}
PGDATA="$(pgcont_opt pgdata)" {{ m.libexecdir}}/postgresql-check-db-dir \
    postgresql-container || exit 1
{%- else -%}
{{ m.bindir }}/postgresql-check-db-dir "$(pgcont_opt pgdata)" || exit 1
{%- endif %}

# Pre-exec hooks.  Don't call from 'rh-cont-pg-exec' because that would not
# be called from service file.
cont_source_hooks preexec postgresql

# Remove the environment file as late as possible.  We rather remove that file
# because it may contain POSTGRESQL_ADMIN_PASSWORD.
rm -f "{{ m.pghome }}/.cont-postgresql-environment" || {
    cont_error "can't remove env file"
    exit 1
}

