# Database Schema Documentation

## Table: `player_reward`

This table tracks daily login rewards for players in the QBCore FiveM framework.

### Schema

```sql
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
```

### Column Descriptions

#### `id` (VARCHAR(255), PRIMARY KEY)
- **Purpose:** Unique player identifier
- **Value:** Player's citizen ID from QBCore (`xPlayer.PlayerData.citizenid`)
- **Usage:** Links reward records to specific players
- **Example:** `"ABC12345"`, `"CIT99999"`

#### `name` (VARCHAR(255))
- **Purpose:** Player's character name for easy identification
- **Value:** Player's full name from QBCore (`xPlayer.PlayerData.name`)
- **Usage:** Makes database records human-readable without requiring game data lookup
- **Example:** `"John Doe"`, `"Jane Smith"`

#### `date` (TIMESTAMP)
- **Purpose:** Tracks when the player last claimed their daily reward
- **Value:** Automatically updated to current timestamp on INSERT or UPDATE
- **Usage:** Used to determine if 24 hours have passed since last claim
- **Default:** `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`
- **Important:** Compared in UTC to ensure consistent daily reset for all players

#### `reward` (VARCHAR(255))
- **Purpose:** Audit log of what reward was given
- **Value:** Human-readable description of the reward
- **Format:**
  - Money rewards: `"money: 1500"` (where 1500 is the amount)
  - Item rewards: `"anchovy: 3"` (where anchovy is item name, 3 is quantity)
- **Usage:** 
  - Allows administrators to review reward history
  - Helps with troubleshooting player issues
  - Can be used for statistics/analytics
  - NOT used for actual reward distribution (rewards are given in real-time)
- **Examples:**
  ```
  "money: 500"
  "money: 1500"
  "anchovy: 3"
  "trout: 2"
  ```

#### `flag` (INT, DEFAULT 1)
- **Purpose:** Login streak counter / total claims tracker
- **Value:** Number of times the player has claimed daily rewards
- **Behavior:**
  - First claim: Set to `1`
  - Subsequent claims: Incremented by 1 (`flag = flag + 1`)
- **SQL Logic:** 
  ```sql
  INSERT ... VALUES (@flag = 1) 
  ON DUPLICATE KEY UPDATE flag = flag + 1
  ```
- **Current Usage:** 
  - Passively tracked but not used in game logic
  - Available for future features like:
    - Streak bonuses (claim 7 days in a row for bonus reward)
    - Achievement systems
    - Leaderboards
    - Player statistics dashboard
- **Example Values:**
  - `1` = First time claiming
  - `7` = Claimed 7 times (could be 7-day streak)
  - `365` = Claimed 365 times (year-long player)

### Indexes

#### Primary Key: `id`
- Ensures unique record per player
- Fast lookups by citizen ID

#### Index: `idx_date`
- Optimizes queries filtering/sorting by date
- Useful for admin queries like "rewards claimed today"

#### Index: `idx_id_date`
- Composite index for combined id and date queries
- Optimizes the main reward check query

### Example Queries

#### Check player's claim history
```sql
SELECT name, date, reward, flag 
FROM player_reward 
WHERE id = 'ABC12345';
```

#### See today's claims
```sql
SELECT name, reward, date 
FROM player_reward 
WHERE DATE(date) = CURDATE()
ORDER BY date DESC;
```

#### Find players with longest streaks
```sql
SELECT name, flag as total_claims, date as last_claim
FROM player_reward 
ORDER BY flag DESC 
LIMIT 10;
```

#### Get reward distribution statistics
```sql
SELECT 
    CASE 
        WHEN reward LIKE 'money:%' THEN 'Money'
        ELSE 'Item'
    END as reward_type,
    COUNT(*) as count
FROM player_reward 
GROUP BY reward_type;
```

### Migration from Previous Version

If upgrading from version with `reward INT`:

```sql
ALTER TABLE player_reward 
    MODIFY COLUMN reward VARCHAR(255);
```

### Data Retention

- Records are kept indefinitely
- The `flag` counter continues to increment for the lifetime of the player
- Consider implementing cleanup for inactive players if database size becomes a concern

### Future Enhancements

Potential uses for the `flag` column:

1. **Streak Bonuses:**
   ```lua
   if flag % 7 == 0 then
       -- Give bonus reward for 7-day streak
   end
   ```

2. **Loyalty Rewards:**
   ```lua
   if flag >= 30 then
       -- Give special item for 30 total claims
   end
   ```

3. **Statistics Dashboard:**
   - Show player's total login days
   - Display community-wide engagement metrics
   - Create leaderboards for most dedicated players
