BEGIN;

DROP TABLE IF EXISTS infected_keys;
DROP TABLE IF EXISTS infected_key_submissions;
DROP TABLE IF EXISTS auth_keys;

CREATE TABLE auth_keys (
    auth_id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_created INTEGER,
    timestamp_expired INTEGER,
    auth_token TEXT
);

CREATE INDEX auth_keys_auth_token ON auth_keys (auth_token);

CREATE TABLE infected_key_submissions (
    submission_id INTEGER PRIMARY KEY AUTOINCREMENT,
    status TEXT,
    timestamp INTEGER,
    status_updated INTEGER,
    client_identifier TEXT
);

CREATE INDEX infected_key_submissions_status ON infected_key_submissions (status);
CREATE INDEX infected_key_submissions_status_updated ON infected_key_submissions (status_updated);
CREATE INDEX infected_key_submissions_timestamp ON infected_key_submissions (timestamp);


CREATE TABLE infected_keys (
    infected_key STRING,
    rolling_start_number INTEGER,
    risk_level INTEGER,
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
