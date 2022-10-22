FROM alpine AS builder1

RUN set -ex && \
    apk add rsync wget ca-certificates jq git openssh-client bash coreutils file && \
    DBDL=$(mktemp -d) && \
    DBDLZ=$(mktemp -d) && \
    mkdir -p /out && \
    wget -qO $DBDLZ/sponsorTimes.csv.gz https://github.com/sim1/sponsorblockdb/releases/latest/download/sponsorTimes.csv.gz && \
    wget -qO $DBDLZ/videoInfo.csv.gz https://github.com/sim1/sponsorblockdb/releases/latest/download/videoInfo.csv.gz && \
    for file in $(find $DBDLZ -name "*.gz"); do gzip -d -c $file > $DBDL/$(basename $file .gz); rm $file; done && \
    rm -rf $DBDLZ && \
    REPO=$(mktemp -d) && \
    git clone https://github.com/ajayyy/SponsorBlockServer $REPO --depth 1 && \
    DB=$REPO/databases && \
    echo "ALTER TABLE \"sponsorTimes\" ALTER COLUMN \"timeSubmitted\" TYPE BIGINT USING \"timeSubmitted\"::BIGINT" > $DB/hack1.sql && \
    cat \
    $DB/_sponsorTimes.db.sql $DB/_upgrade_sponsorTimes_1.sql $DB/_upgrade_sponsorTimes_2.sql \
    $DB/_upgrade_sponsorTimes_3.sql $DB/_upgrade_sponsorTimes_4.sql $DB/_upgrade_sponsorTimes_5.sql \
    $DB/_upgrade_sponsorTimes_6.sql $DB/_upgrade_sponsorTimes_7.sql $DB/_upgrade_sponsorTimes_8.sql \
    $DB/_upgrade_sponsorTimes_9.sql $DB/_upgrade_sponsorTimes_10.sql $DB/_upgrade_sponsorTimes_11.sql \
    $DB/_upgrade_sponsorTimes_12.sql $DB/_upgrade_sponsorTimes_13.sql $DB/_upgrade_sponsorTimes_14.sql \
    $DB/_upgrade_sponsorTimes_15.sql $DB/_upgrade_sponsorTimes_16.sql $DB/_upgrade_sponsorTimes_17.sql \
    $DB/_upgrade_sponsorTimes_18.sql $DB/_upgrade_sponsorTimes_19.sql $DB/_upgrade_sponsorTimes_20.sql \
    $DB/_upgrade_sponsorTimes_21.sql $DB/_upgrade_sponsorTimes_22.sql $DB/_upgrade_sponsorTimes_23.sql \
    $DB/_upgrade_sponsorTimes_24.sql $DB/_upgrade_sponsorTimes_25.sql $DB/_upgrade_sponsorTimes_26.sql \
    $DB/_upgrade_sponsorTimes_27.sql $DB/_upgrade_sponsorTimes_28.sql $DB/_upgrade_sponsorTimes_29.sql \
    $DB/_upgrade_sponsorTimes_30.sql $DB/_upgrade_sponsorTimes_31.sql $DB/_upgrade_sponsorTimes_32.sql \
    $DB/_upgrade_sponsorTimes_33.sql $DB/_upgrade_sponsorTimes_34.sql \
    $DB/_sponsorTimes_indexes.sql $DB/hack1.sql \
    > /out/0_init.sql && \
    cp $DBDL/*csv /out/ && \
    sed -i'' 's/sha256("videoID")/sha256("videoID"::bytea)/g' /out/0_init.sql && \
    for i in $(find $DBDL -name "*.csv"); do \
    file $i && \
    echo "COPY \"$(basename $i .csv)\" FROM '/docker-entrypoint-initdb.d/$(basename $i)' WITH (FORMAT csv, HEADER true, DELIMITER ',');" >> /out/9_$(basename $i .csv).sql; \
    done

FROM postgres:15-alpine AS prebuild

COPY --from=builder1 /out /docker-entrypoint-initdb.d/
RUN grep -v 'exec "$@"' /usr/local/bin/docker-entrypoint.sh > /docker-entrypoint.sh && chmod 755 /docker-entrypoint.sh

ENV POSTGRES_HOST_AUTH_METHOD trust
ENV POSTGRES_DB sponsorTimes
RUN /docker-entrypoint.sh postgres \
    -c fsync=off \
    -c full_page_writes=off \
    -c wal_level=minimal \
    -c wal_keep_size=0 \
    -c archive_mode=off \
    -c max_wal_senders=0 \
    -c autovacuum=off \
    -c synchronous_commit=off \
    -c checkpoint_timeout=1h \
    -c max_wal_size=1GB \
    -c shared_buffers=4GB && \
    sync

FROM postgres:15-alpine
COPY --from=prebuild /var/lib/postgresql/data /var/lib/postgresql/data
