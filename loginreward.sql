-- Daily login reward tracking table
CREATE TABLE player_reward (
    id VARCHAR(255) NOT NULL,              -- Player's citizen ID (from QBCore)
    name VARCHAR(255) NOT NULL,            -- Player's character name (for easy identification)
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, -- Last claim timestamp (UTC)
    reward VARCHAR(255),                   -- Audit log: what was given (e.g., "money: 1500" or "anchovy: 3")
    flag INT DEFAULT 1,                    -- Login streak counter: total number of daily claims (1, 2, 3...)
    PRIMARY KEY (id),
    INDEX idx_date (date),                 -- Optimize date-based queries
    INDEX idx_id_date (id, date)           -- Optimize player reward check queries
);
