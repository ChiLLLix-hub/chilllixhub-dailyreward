# Daily Login Reward Script

A secure daily login reward system for QBCore FiveM servers that gives players money or items when they log in each day.

## Features

- ✅ **Automatic rewards** on player login (no commands needed)
- ✅ **Daily reset** at UTC midnight for consistent global timing
- ✅ **Random rewards** - money or items based on configuration
- ✅ **Security hardened** - rate limiting, race condition protection, server-side validation
- ✅ **Audit logging** - tracks all reward claims and exploitation attempts
- ✅ **Login streak tracking** - counts total daily claims per player

## Installation

1. **Import the database table:**
   ```bash
   mysql -u username -p database_name < loginreward.sql
   ```

2. **Add to server.cfg:**
   ```
   ensure chilllixhub-dailyreward
   ```

3. **Configure rewards** in `config.lua`:
   ```lua
   -- Money rewards
   Config.MoneyReward = {
       minAmount = 100,
       maxAmount = 1000
   }
   
   -- Item rewards
   Config.ItemRewards = {
       { name = "anchovy", minQuantity = 2, maxQuantity = 5 },
       { name = "trout", minQuantity = 2, maxQuantity = 5 },
   }
   ```

## Configuration

### Security Settings

```lua
-- Rate limiting (prevents spam)
Config.RateLimitCooldown = 5  -- Seconds between reward check requests

-- Lock timeout (prevents stuck operations)
Config.LockTimeout = 60  -- Seconds before stuck locks are cleared

-- Timezone (for consistent daily reset)
Config.UseUTC = true  -- Use UTC timezone for all players
```

### Logging Settings

```lua
-- Server-side logging
Config.EnableLogging = true  -- Enable general logging
Config.LogExploitAttempts = true  -- Log rate limit violations
```

## Database Schema

The script uses a `player_reward` table with the following columns:

| Column | Type | Purpose |
|--------|------|---------|
| `id` | VARCHAR(255) | Player's citizen ID (primary key) |
| `name` | VARCHAR(255) | Player's character name |
| `date` | TIMESTAMP | Last reward claim timestamp |
| **`reward`** | **VARCHAR(255)** | **Audit log of what was given** |
| **`flag`** | **INT** | **Login streak counter (total claims)** |

### Understanding `reward` and `flag`

#### The `reward` Column
Stores a human-readable description of each reward for audit purposes:
- **Format:** `"money: 1500"` or `"anchovy: 3"`
- **Purpose:** Allows admins to review player reward history
- **Not used** for actual reward distribution (rewards are given in real-time)
- **Example values:**
  ```
  "money: 500"
  "money: 1500"  
  "anchovy: 3"
  "trout: 2"
  ```

#### The `flag` Column  
Tracks the total number of daily rewards claimed by each player:
- **Initial value:** `1` (first claim)
- **Increments:** `flag = flag + 1` on each subsequent claim
- **Purpose:** Login streak counter / engagement metric
- **Current usage:** Passively tracked (not used in game logic yet)
- **Future potential:**
  - Streak bonuses (e.g., bonus every 7 days)
  - Achievement system
  - Leaderboards
  - Player statistics dashboard

See [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) for detailed documentation and example queries.

## How It Works

1. **Player logs in** → `QBCore:Client:OnPlayerLoaded` event fires
2. **Client triggers** → `login_reward:checkReward` server event
3. **Server validates**:
   - Rate limit check (5-second cooldown)
   - Race condition protection (mutex lock)
   - Daily reset check (UTC midnight)
4. **Reward selection**:
   - Random choice: money or item
   - Random amount within configured range
5. **Database update**:
   - Records claim timestamp
   - Logs reward description in `reward` column
   - Increments `flag` counter
6. **Player receives reward** and notification

## Security Features

- ✅ **No client-side exploits** - all logic is server-controlled
- ✅ **Rate limiting** - 5-second cooldown prevents spam
- ✅ **Race condition protection** - mutex locks prevent duplicate rewards
- ✅ **Input validation** - all player data and rewards validated
- ✅ **Item validation** - checks QBCore.Shared.Items before giving
- ✅ **Error handling** - comprehensive error catching and logging

See [SECURITY_FIXES.md](SECURITY_FIXES.md) for detailed security documentation.

## Admin Tools

### Check Player's Reward History
```sql
SELECT name, date, reward, flag 
FROM player_reward 
WHERE id = 'ABC12345';
```

### View Today's Claims
```sql
SELECT name, reward, date 
FROM player_reward 
WHERE DATE(date) = CURDATE()
ORDER BY date DESC;
```

### Top Login Streaks
```sql
SELECT name, flag as total_claims, date as last_claim
FROM player_reward 
ORDER BY flag DESC 
LIMIT 10;
```

### Reward Distribution Stats
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

## Troubleshooting

### Player says they didn't receive reward
1. Check server logs for their claim attempt
2. Query database: `SELECT * FROM player_reward WHERE id = 'THEIR_ID'`
3. Check if `date` shows today's timestamp
4. Check `reward` column to see what was supposed to be given

### Rate limit is too strict
- Increase `Config.RateLimitCooldown` in config.lua
- Default is 5 seconds (recommended minimum)

### Want to reset a player's daily claim
```sql
UPDATE player_reward 
SET date = DATE_SUB(NOW(), INTERVAL 2 DAY) 
WHERE id = 'PLAYER_ID';
```

## Future Enhancements

Using the `flag` column, you could implement:

### Streak Bonuses
```lua
-- In server.lua, after line 219
if flag and flag % 7 == 0 then
    -- Give bonus reward for 7-day streak
    xPlayer.Functions.AddMoney('bank', 5000)
    TriggerClientEvent('QBCore:Notify', source, 'Streak bonus! 7 days in a row!', 'success')
end
```

### Loyalty Rewards
```lua
-- Check total claims
MySQL.Async.fetchScalar('SELECT flag FROM player_reward WHERE id = @id', {
    ['@id'] = playerId
}, function(totalClaims)
    if totalClaims >= 30 then
        -- Give special item for 30+ claims
        xPlayer.Functions.AddItem('special_trophy', 1)
    end
end)
```

## Credits

- **Original Author:** Chilllix
- **Version:** 2.0.0+security-fixes
- **Framework:** QBCore
- **License:** See LICENSE file

## Support

For issues or questions:
1. Check [SECURITY_FIXES.md](SECURITY_FIXES.md) for common problems
2. Review [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) for database questions
3. Check server console logs (if `Config.EnableLogging = true`)
4. Open an issue on GitHub

## Changelog

### v2.0.0 (Security Update)
- ✅ Fixed client-side exploit vulnerability
- ✅ Added rate limiting protection
- ✅ Fixed database schema (INT → VARCHAR for reward)
- ✅ Implemented race condition protection
- ✅ Added UTC timezone support
- ✅ Comprehensive error handling
- ✅ Configuration validation
- ✅ Added audit logging

### v1.0.0
- Initial release
