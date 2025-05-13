# Add these functions to your .bashrc or .zshrc

# Shell code written by Claude with some guidance from mst

# Path to the vim session recorder script - change this to the actual path
VIM_SESSION_RECORDER="$HOME/bin/vim_session_recorder.pl"

# Record current shell session including vim jobs
function record_vim_session() {
  local session_name="$1"

  if [ -z "$session_name" ]; then
    echo "Usage: record_vim_session SESSION_NAME"
    return 1
  fi

  if [ ! -x "$VIM_SESSION_RECORDER" ]; then
    echo "Error: Vim session recorder script not found or not executable at $VIM_SESSION_RECORDER"
    return 1
  fi

  # Set the session name and run the recorder with jobs output
  export RESUME_SESSION_NAME="$session_name"
  jobs -l | "$VIM_SESSION_RECORDER"
}

# PS1 hook to automatically record session periodically
function record_vim_session_hook() {
  # Only run if we have an active session name and the recorder exists
  if [ -n "$RESUME_SESSION_NAME" ] && [ -x "$VIM_SESSION_RECORDER" ]; then
    # Run the recorder (silently)
    jobs -l | "$VIM_SESSION_RECORDER" >/dev/null 2>&1
  fi
}

# Add to your PS1 if you want automatic recording
# PS1='...\$ $(record_vim_session_hook)'

# Function to output the session file path for a given session name
function resume_vim_session_file() {
  local session_name="$1"

  if [ -z "$session_name" ]; then
    echo "Available sessions:" >&2
    ls -1 ~/.resume/ >&2
    return 1
  fi

  local session_file="$HOME/.resume/$session_name"

  if [ ! -f "$session_file" ]; then
    echo "Session '$session_name' does not exist" >&2
    return 1
  fi

  # Just output the session file path
  echo "$session_file"
}

# Start a new shell with restored session
function resume_vim_session_shell() {
  local session_name="$1"

  # Get the session file path
  local session_file=$(resume_vim_session_file "$session_name")
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    # Error message already displayed by resume_vim_session_file
    return $exit_code
  fi

  # Set session name for potential recording
  export RESUME_SESSION_NAME="$session_name"

  # Replace current shell with new shell running the session
  echo "Resuming session: $session_name"
  exec bash --init-file <(echo "source ~/.bashrc; source '$session_file'")
}

# Function to list available sessions
function list_vim_sessions() {
  if [ ! -d "$HOME/.resume" ]; then
    echo "No sessions found (directory does not exist)"
    return 1
  fi

  local count=$(ls -1 ~/.resume/ 2>/dev/null | wc -l)

  if [ $count -eq 0 ]; then
    echo "No sessions found"
    return 1
  fi

  echo "Available sessions ($count):"
  for session in $(ls -1 ~/.resume/); do
    local jobs_count=$(grep -c "vim -r!" "$HOME/.resume/$session")
    echo "  $session ($jobs_count vim jobs)"
  done
}

# Remove a session
function remove_vim_session() {
  local session_name="$1"

  if [ -z "$session_name" ]; then
    echo "Usage: remove_vim_session SESSION_NAME"
    return 1
  fi

  local session_file="$HOME/.resume/$session_name"

  if [ ! -f "$session_file" ]; then
    echo "Session '$session_name' does not exist"
    return 1
  fi

  rm "$session_file"
  echo "Session '$session_name' removed"
}
