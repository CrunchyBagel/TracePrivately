BEGIN;

DROP TABLE IF EXISTS infected_keys;
DROP TABLE IF EXISTS infected_key_submissions;

CREATE TABLE infected_key_submissions (
    submission_id INTEGER PRIMARY KEY AUTOINCREMENT,
    status TEXT,
    timestamp INTEGER,
    status_updated INTEGER
);

CREATE INDEX infected_key_submissions_status ON infected_key_submissions (status);
CREATE INDEX infected_key_submissions_status_updated ON infected_key_submissions (status_updated);
CREATE INDEX infected_key_submissions_timestamp ON infected_key_submissions (timestamp);


CREATE TABLE infected_keys (
    infected_key STRING,
    rolling_start_number INTEGER,
    status TEXT,
    timestamp INTEGER,
    status_updated INTEGER,
    submission_id INTEGER,

    FOREIGN KEY (submission_id) REFERENCES infected_key_submissions (submission_id)
);

CREATE INDEX infected_keys_status ON infected_keys (status);
CREATE INDEX infected_keys_status_updated ON infected_keys (status_updated);
CREATE INDEX infected_keys_timestamp ON infected_keys (timestamp);

COMMIT;
