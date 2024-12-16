create extension if not exists pg_cron;

    DROP TABLE IF EXISTS staging;
    CREATE TABLE staging (
        event_data VARCHAR(10000),
        load_timestamp TIMESTAMP
    );

    DROP TABLE IF EXISTS track;
    CREATE TABLE track(
        last_row INT
    );
    INSERT INTO track values (0);

create or replace function loadnext100rows() returns void
    language plpgsql
as
$$
DECLARE
    LastLoadedRow INTEGER;
BEGIN

    DROP TABLE IF EXISTS TempImport;
    CREATE TABLE TempImport (
        event_data1 TEXT,
        event_data2 TEXT,
        event_data3 TEXT,
        event_data4 TEXT,
        event_data5 TEXT,
        event_data6 TEXT,
        event_data7 TEXT,
        event_data8 TEXT,
        event_data9 TEXT,
        event_data10 TEXT,
        event_data11 TEXT,
        event_data12 TEXT
    );

    BEGIN
        COPY TempImport(event_data1, event_data2, event_data3, event_data4, event_data5, event_data6, event_data7, event_data8, event_data9, event_data10, event_data11, event_data12)
        FROM '/home/Marvel_Comics.csv'
        WITH (
            FORMAT CSV,
            DELIMITER ',',
            HEADER,
            NULL '',
            QUOTE '"',
            ESCAPE '"'
        );

        WITH lastInsert AS(
            INSERT INTO staging (event_data, load_timestamp)
            SELECT
                event_data1 || ';' || event_data2 || ';' || event_data3 || ';' || event_data4 || ';' ||
                event_data5 || ';' || event_data6 || ';' || event_data7 || ';' || event_data8 || ';' ||
                event_data9 || ';' || event_data10 || ';' || event_data11 || ';' || event_data12,
                CURRENT_TIMESTAMP
            FROM TempImport
            LIMIT 100 OFFSET (SELECT last_row from track)
            RETURNING 1
        )
        SELECT COUNT(*) into LastLoadedRow from lastInsert;

        UPDATE track SET last_row = last_row + LastLoadedRow;

        EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred during LoadNext100Rows: %', SQLERRM;
    END;
END
$$;

ALTER FUNCTION loadnext100rows() OWNER TO postgres;

SELECT cron.schedule('* * * * *', $$
    SET SCHEMA 'public';
    SELECT loadnext100rows();
    $$)

SELECT jobid, schedule, command
FROM CRON.job;

select jobid, status from cron.job_run_details;

-- select cron.unschedule(1);

