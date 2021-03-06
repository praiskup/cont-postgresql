=====================================
Help page for PostgreSQL in container
=====================================

General documentation for PostgreSQL container usage.  Most of this file
describes only proof-of-concept implemented ideas.  Be careful not to rely
described API too much though we'll try to avoid any "API" changes unless
necessary.


Basic concepts
--------------
We try to push you to mount PostgreSQL datadir from host machine (see
'assert_external_data' option below).

While starting PostgreSQL in container, your database datadir will be
initialized automatically (unless you provided already initialized volume).
That way we allowed you to do 'initdb && start' of the container PostgreSQL
server by one command.

We also try to avoid starting concurrent servers running against the same
datadir volume, see the 'clear_pgdata_pidfile' option.


Access your PostgreSQL admin account via /var/run socket
--------------------------------------------------------

To avoid unnecessary random generation of admin's password (or passing the
password down to container via environment variable), we rely on UNIX domain
socket authentication _by default_ in PostgreSQL container.  It means that
you'll need to have access to server's socket file either from host machine, or
from other container (depends on where you need to have the admin access from).

To get the socket file out from your server container, specify
'-v YOUR_DIR:/var/run/postgresql' option while you run 'docker run' command.
Then, PostgreSQL container will create the socket file under YOUR_DIR which will
allow you to access admin's account under host's 'postgres' UID:

    # # on your docker-host machine
    # su - postgres
    $ psql -h YOUR_DIR
    psql (9.2.10)
    Type "help" for help
    postgres=#

Additionally, with /var/run/postgresql volume, you may start other container
with command like 'docker run --volumes-from YOUR_POSTGRESQL_CONTAINER_ID',
and then, from inside the new container you'll have admin access without
password:

    $ id
    uid=26(postgres) gid=26(postgres) groups=26(postgres)
    $ psql
    psql (9.2.10)
    Type "help" for help
    postgres=#

Accessing admin account _with_ password
---------------------------------------
We provide also support POSTGRESQL_ADMIN_PASSWORD environment variable for
convenience if you don't care too much about its existence.  If you start your
PostgreSQL server container with '-e POSTGRESQL_ADMIN_PASSWORD=your_pass' -
during database initialization time - the auth method [1] for admin will be set
to 'md5' with default password set to 'your_pass'.  With this, you'll be able to
access DB admin account from everywhere, if you have host (IP) access to the
server.


Shell (bash) hooks
------------------

All hooks are sourced/run by 'postgres' user ATM.  Note that only `*.sh'
files (from directories described below) will be automatically sourced.  We
follow the 'cont-lib' [2] directory hierarchy.

{{ m.conthookdir }}/cont-layer/postgresql/preinitdb
{{ m.conthookdir }}/cont-volume/postgresql/preinitdb
    Shell hooks from those directories will be sourced right before the
    automatic DB initialization.  This will happen _only_ if you run container
    with not yet initialized data volume.

{{ m.conthookdir }}/cont-layer/postgresql/postinitdb
{{ m.conthookdir }}/cont-volume/postgresql/postinitdb
    Shell hooks from those directories will be sourced immediately after the
    automatic DB initialization.  Similar to 'preinitdb', this will happen only
    if you run container against not yet initialized data volume.

{{ m.conthookdir }}/cont-layer/postgresql/preexec
{{ m.conthookdir }}/cont-volume/postgresql/preexec
    Those hooks will be called right before the PostgreSQL server start.  This
    will happen always, regardless of the data volume initialization step.

Environment variables
---------------------

Those are expected to be specified by the docker run -e option, for example
'docker run -e CONT_DEBUG=2'.

POSTGRESQL_ADMIN_PASSWORD=STRING                        (initdb-time only)
    String value will be set as admin's ('postgres' user) password.  This also
    disables the 'ident' [1] authentication method for administrator triggers
    the 'md5' method.  Users are encouraged to avoid this variable because the
    admin password exists in container forever.  If you really need to use this
    variable, consider immediate container shut-down and start of new container
    (with already initialized DB) without this variable.

POSTGRESQL_CONFIG="key = value [; key = value [...]]"   (initdb-time only)
    Content of this variable is parsed and added into
    'data/postgresql-container.conf' configuration file 1:1, this file will be
    automatically included by the 'data/postgresql.conf'.

POSTGRESQL_CONTAINER_OPTS="key = value [; key = value [...]]"
    Via this variable you may adjust container behavior.

    assert_external_data = true|false (default=true)
        For testing purposes, this will allow you to run this container without
        specifying external data volume ({{ m.pgdata }} directory).

    clear_pgdata_pidfile = true|false (default is false)
        We refuse to start if the {{ m.pgdata }}/postmaster.pid file
        already exists.  This may either happen because you try to run two
        concurrent containers against the same data volume, or the file may be
        just a leftover from container/docker/postgresql failure.  If you are
        100% sure the file is leftover, this option will clear the pidfile for
        you.  You may consider setting this to 'true' everytime if you can
        guarantee that the data will not be used concurrently.

POSTGRESQL_DATABASE=STRING
POSTGRESQL_USER=STRING
POSTGRESQL_PASSWORD=STRING
    Only when *all* these three variables are set during initdb-time, the
    initialization logic will create one additional database of given name, owned
    by given user.

[1] http://www.postgresql.org/docs/9.2/static/auth-pg-hba-conf.html
