CREATE TABLE infected_key_submissions (
    submission_id INTEGER PRIMARY KEY AUTOINCREMENT,
    status TEXT,
    timestamp INTEGER
);

CREATE INDEX infected_key_submissions_status ON infected_key_submissions (status);
CREATE INDEX infected_key_submissions_timestamp ON infected_key_submissions (timestamp);


CREATE TABLE infected_keys (
    infected_key STRING,
    status TEXT,
    timestamp INTEGER,
    submission_id INTEGER,

    FOREIGN KEY (submission_id) REFERENCES infected_key_submissions (submission_id)
);

CREATE INDEX infected_keys_status ON infected_keys (status);
CREATE INDEX infected_keys_timestamp ON infected_keys (timestamp);

