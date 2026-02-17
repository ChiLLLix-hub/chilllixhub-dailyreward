CREATE TABLE player_reward (
    id VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    reward VARCHAR(255),
    flag INT DEFAULT 1,
    PRIMARY KEY (id),
    INDEX idx_date (date),
    INDEX idx_id_date (id, date)
);
