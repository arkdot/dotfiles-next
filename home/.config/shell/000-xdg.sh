# Configures XDG specification environment variables.
# https://specifications.freedesktop.org/basedir/latest/

# A single base directory relative to which user-specific data files should be written
export XDG_DATA_HOME="${HOME}/.local/share"

# A single base directory relative to which user-specific configuration files should be written
export XDG_CONFIG_HOME="${HOME}/.config"

# A single base directory relative to which user-specific state data should be written
export XDG_STATE_HOME="${HOME}/.local/state"

# A single base directory relative to which user-specific non-essential (cached) data should be written
export XDG_CACHE_HOME="${HOME}/.cache"
